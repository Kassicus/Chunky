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
    func start() async throws {
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

        // Exposure is intentionally left in auto here so the AE meter can
        // converge while the session warms up.  Custom exposure is applied
        // below after a brief settling wait (see §5 "Meter ISO after AE settles").

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

        // Honor the device's activeFormat; prevents the session from re-selecting
        // a lower-fps default format when the input is added.
        newSession.sessionPreset = .inputPriority

        // Prevent the camera session from reconfiguring the app audio session
        // and undoing AudioImpactMonitor's .record/.measurement configuration.
        newSession.automaticallyConfiguresApplicationAudioSession = false

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

        // Output: 420f biplanar — spec §5.3; ~half the memory of 32BGRA at 1080p
        // 240 fps so the ring buffer no longer starves the capture pool.
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
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

        // Notify the caller that the session is starting (light check follows below)
        onStatusChange?(.running)
        newSession.startRunning()

        // 5. Meter ISO after AE convergence -----------------------------------
        // AE needs a brief window (~300 ms) to converge on the scene brightness
        // after the session starts streaming.  Read the settled ISO/duration then
        // apply the custom short-shutter exposure so device.iso is representative.
        try? await Task.sleep(for: .milliseconds(300))
        do {
            try device.lockForConfiguration()
            let meteredISO      = Double(device.iso)
            let meteredDuration = device.exposureDuration.seconds
            let rec = ExposureCalculator.recommend(
                autoISO:        meteredISO,
                autoDuration:   meteredDuration,
                targetDuration: config.shutterSeconds,
                minISO:         Double(bestFormat.minISO),
                maxISO:         Double(bestFormat.maxISO)
            )
            device.setExposureModeCustom(
                duration: CMTime(seconds: config.shutterSeconds, preferredTimescale: 1_000_000),
                iso: Float(rec.iso),
                completionHandler: nil
            )
            device.unlockForConfiguration()
            // Re-publish status with the post-convergence light assessment
            onStatusChange?(rec.needsMoreLight ? .needsMoreLight : .running)
        } catch {
            // Re-lock failed (rare); session is still running with auto exposure.
            // Caller stays in .running; ISO may be non-optimal for this scene.
        }
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
