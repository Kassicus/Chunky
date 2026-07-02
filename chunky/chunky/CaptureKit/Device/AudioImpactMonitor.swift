// chunky/chunky/CaptureKit/Device/AudioImpactMonitor.swift
import AVFoundation
import Accelerate

/// Monitors microphone input via AVAudioEngine, computes short-time energy per
/// buffer, and fires onImpact when AudioImpactDetector detects a club-ball
/// transient onset.
///
/// Usage (after requesting authorization):
///   let monitor = AudioImpactMonitor { t in print("impact at \(t)s") }
///   try monitor.start()
///   // ... capture ...
///   monitor.stop()
final class AudioImpactMonitor: @unchecked Sendable {

    // MARK: - Public interface

    /// Called on the main queue with the timestamp (seconds) of each detected
    /// impact. May be replaced before calling start().
    nonisolated(unsafe) var onImpact: (Double) -> Void

    // MARK: - Private state

    // nonisolated(unsafe): class is @unchecked Sendable; concurrency managed
    // manually via audioQueue (tap thread) and main-queue dispatch for callbacks.
    nonisolated(unsafe) private let engine = AVAudioEngine()
    nonisolated(unsafe) private var detector = AudioImpactDetector()

    /// Serialises all mutations of `detector` (tap thread → audioQueue).
    private let audioQueue = DispatchQueue(
        label: "capturekit.audio",
        qos: .userInteractive
    )

    nonisolated(unsafe) private var isRunning = false

    // MARK: - Init

    init(onImpact: @escaping (Double) -> Void = { _ in }) {
        self.onImpact = onImpact
    }

    // MARK: - Authorization

    /// Requests microphone permission using AVAudioApplication (iOS 17+).
    /// Returns true if access is granted (or was previously granted).
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Lifecycle

    /// Configures AVAudioSession for recording, installs a tap on inputNode,
    /// and starts the audio engine.
    ///
    /// - Throws: Any error from AVAudioSession or AVAudioEngine setup.
    func start() throws {
        guard !isRunning else { return }

        // Configure and activate the audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        // Install a ~1024-frame tap using the hardware input format
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self else { return }
            self.processTap(buffer: buffer, time: time)
        }

        do {
            try engine.start()
        } catch {
            // Remove the tap so a subsequent start() attempt does not hit
            // AVAudioEngine's "already tapped bus 0" assertion.
            inputNode.removeTap(onBus: 0)
            throw error
        }
        isRunning = true
    }

    /// Removes the tap, stops the engine, and deactivates the audio session.
    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    // MARK: - Private

    /// Called on the internal AVAudioEngine render thread.
    private func processTap(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Derive a timestamp in seconds in the mach host-time clock domain so
        // it matches video frame PTS from CMSampleBufferGetPresentationTimeStamp.
        // AVCaptureSession's default synchronization clock is the host-time clock,
        // so audio impact time and video frame PTS are now both in mach
        // host-time-clock seconds domain and the impact window aligns correctly.
        let t: Double
        if time.isHostTimeValid {
            t = AVAudioTime.seconds(forHostTime: time.hostTime)
        } else if time.isSampleTimeValid, time.sampleRate > 0 {
            // sampleTime/sampleRate fallback (~0 origin, not aligned to the mach
            // host-time clock) — may introduce a time-domain discontinuity
            // relative to sampleTime-derived timestamps.
            t = Double(time.sampleTime) / time.sampleRate
        } else {
            // CACurrentMediaTime() is host-clock based and not aligned to the
            // engine's sample clock, so this fallback may introduce a
            // time-domain discontinuity relative to sampleTime-derived timestamps.
            t = CACurrentMediaTime()
        }

        // Short-time energy: mean of sample² over channel 0
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0, let channelData = buffer.floatChannelData?[0] else { return }

        var sumOfSquares: Float = 0
        vDSP_svesq(channelData, 1, &sumOfSquares, vDSP_Length(frameCount))
        let energy = Double(sumOfSquares / Float(frameCount))

        // Feed the detector on a serial queue so its mutable state is protected,
        // then dispatch the impact callback to the main queue.
        audioQueue.async { [weak self] in
            guard let self else { return }
            if self.detector.process(energy: energy, time: t) {
                let callback = self.onImpact
                DispatchQueue.main.async { callback(t) }
            }
        }
    }
}
