// chunky/chunky/CaptureKit/Device/CameraCaptureController.swift
import AVFoundation
import CoreMedia
import CoreVideo

/// Owns and drives an AVCaptureSession configured for high-frame-rate golf ball
/// capture. Consumes CaptureConfiguration, CaptureFormatSelector, and
/// ExposureCalculator from the Core layer; delivers pixel buffers to a
/// FrameReceiver on a dedicated serial queue.
final class CameraCaptureController: NSObject, @unchecked Sendable {

    // MARK: - Public interface

    /// The running session — attach an AVCaptureVideoPreviewLayer here from
    /// the Live screen after calling start().
    private(set) var session = AVCaptureSession()

    /// Called on the calling thread whenever the capture status changes.
    var onStatusChange: ((CaptureStatus) -> Void)?

    // MARK: - Private state

    private let config: CaptureConfiguration
    private weak var receiver: (any FrameReceiver)?
    private let frameQueue = DispatchQueue(label: "capturekit.frames")

    // MARK: - Init

    init(config: CaptureConfiguration = .default, receiver: any FrameReceiver) {
        self.config = config
        self.receiver = receiver
        super.init()
    }

    // MARK: - Authorization

    /// Wraps AVCaptureDevice.requestAccess; call before start().
    func requestAuthorization() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: - Lifecycle

    /// Configures and starts the capture session.
    /// Throws CaptureSetupError if the camera is unavailable, no suitable
    /// format exists, or session configuration fails.
    func start() throws {
        // 1. Discover camera device -----------------------------------------
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTelephotoCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )

        let device: AVCaptureDevice
        if config.lens == .telephoto,
           let telephoto = discoverySession.devices.first(where: { $0.deviceType == .builtInTelephotoCamera }) {
            device = telephoto
        } else if let wide = discoverySession.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            device = wide
        } else if let any = discoverySession.devices.first {
            // Unexpected but safe fallback: use whatever was found
            device = any
        } else {
            throw CaptureSetupError.noCamera
        }

        // 2. Map formats → CaptureFormatDescriptor and pick best --------------
        let descriptors: [CaptureFormatDescriptor] = device.formats.map { fmt in
            let dims = CMVideoFormatDescriptionGetDimensions(fmt.formatDescription)
            let maxFPS = fmt.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
            return CaptureFormatDescriptor(
                width: Int(dims.width),
                height: Int(dims.height),
                maxFrameRate: maxFPS
            )
        }

        guard let bestDescriptor = CaptureFormatSelector.best(
            from: descriptors,
            targetFPS: config.targetFPS,
            targetHeight: config.resolutionHeight
        ) else {
            throw CaptureSetupError.noSuitableFormat
        }

        // Find the matching AVCaptureDevice.Format for the winning descriptor
        guard let bestFormat = zip(device.formats, descriptors)
            .first(where: { $0.1 == bestDescriptor })?.0
        else {
            throw CaptureSetupError.noSuitableFormat
        }

        // 3. Lock device and apply configuration ------------------------------
        do {
            try device.lockForConfiguration()
        } catch {
            throw CaptureSetupError.configurationFailed(error.localizedDescription)
        }

        device.activeFormat = bestFormat

        // Frame-rate fencing
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(config.targetFPS))
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration

        // Custom short-shutter exposure: scale ISO from the current auto meter
        let autoISO = Double(device.iso)
        let autoDuration = device.exposureDuration.seconds
        let rec = ExposureCalculator.recommend(
            autoISO: autoISO,
            autoDuration: autoDuration,
            targetDuration: config.shutterSeconds,
            minISO: Double(bestFormat.minISO),
            maxISO: Double(bestFormat.maxISO)
        )
        device.setExposureModeCustom(
            duration: CMTime(seconds: config.shutterSeconds, preferredTimescale: 1_000_000),
            iso: Float(rec.iso),
            completionHandler: nil
        )

        // Lock white balance and focus to prevent hunting during capture
        if device.isWhiteBalanceModeSupported(.locked) {
            device.whiteBalanceMode = .locked
        }
        if device.isFocusModeSupported(.locked) {
            device.focusMode = .locked
        }

        device.unlockForConfiguration()

        // 4. Build AVCaptureSession -------------------------------------------
        let newSession = AVCaptureSession()
        newSession.beginConfiguration()

        // Input
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            newSession.commitConfiguration()
            throw CaptureSetupError.configurationFailed(error.localizedDescription)
        }

        guard newSession.canAddInput(input) else {
            newSession.commitConfiguration()
            throw CaptureSetupError.configurationFailed("Cannot add camera input to session")
        }
        newSession.addInput(input)

        // Output: 32BGRA frames, always discard late, serial dedicated queue
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: frameQueue)

        guard newSession.canAddOutput(output) else {
            newSession.commitConfiguration()
            throw CaptureSetupError.configurationFailed("Cannot add video output to session")
        }
        newSession.addOutput(output)

        newSession.commitConfiguration()

        // Publish session so the Live screen can attach a preview layer
        session = newSession

        // Notify the caller of the effective status before starting
        onStatusChange?(rec.needsMoreLight ? .needsMoreLight : .running)
        newSession.startRunning()
    }

    /// Stops the capture session and publishes .idle.
    func stop() {
        session.stopRunning()
        onStatusChange?(.idle)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraCaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // CVImageBuffer and CVPixelBuffer are both typealiases for CVBuffer —
        // they are the same Swift type and can be passed without casting.
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timeSeconds = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        receiver?.receiveFrame(pixelBuffer, at: timeSeconds)
    }
}
