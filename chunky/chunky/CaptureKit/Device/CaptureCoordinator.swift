// chunky/chunky/CaptureKit/Device/CaptureCoordinator.swift
import AVFoundation
import Combine
import CoreVideo
import Foundation

// MARK: - ImpactCapture

/// An impact event: the audio transient timestamp and the frame window extracted
/// from the ring buffer around that time.
///
/// Marked `@unchecked Sendable` because `CVPixelBuffer` is not declared
/// `Sendable` in iOS 26's Swift overlay (it remains a CoreFoundation reference
/// type), so `[Timestamped<CVPixelBuffer>]` cannot satisfy a regular `Sendable`
/// conformance.  Properties use `nonisolated(unsafe)` to opt out of the
/// module-wide `-default-isolation=MainActor` setting following the same pattern
/// used by `AudioImpactMonitor` in this project.  Thread safety is preserved
/// because this struct is initialised once on the main actor and thereafter
/// treated as read-only.
struct ImpactCapture: @unchecked Sendable {
    /// Audio transient timestamp, seconds (audio engine sample clock).
    let impactTime: Double
    /// Frames spanning [impactTime − preRoll, impactTime + postRoll].
    nonisolated(unsafe) let frames: [Timestamped<CVPixelBuffer>]
}

// MARK: - LockedRingBuffer (private)

/// Thread-safe wrapper around the value-type `RingBuffer`.
///
/// `RingBuffer` has no built-in synchronisation.  This class guards it with
/// `NSLock` so that the AVFoundation capture queue can append frames
/// concurrently with the main actor snapshotting on impact.
private final class LockedRingBuffer<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: RingBuffer<Element>

    init(capacity: Int) {
        buffer = RingBuffer(capacity: capacity)
    }

    /// Append an element.  Safe to call from any thread.
    func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(element)
    }

    /// Returns a snapshot (oldest → newest) of all stored elements.
    /// Safe to call from any thread; returns a value copy under the lock.
    func snapshot() -> [Element] {
        lock.lock()
        defer { lock.unlock() }
        return buffer.elements
    }
}

// MARK: - FrameForwarder (private)

/// Bridges `CameraCaptureController` (which requires a `FrameReceiver` at
/// init time) to the `LockedRingBuffer` without needing `CaptureCoordinator`'s
/// `self` before its own init completes.
///
/// The stored closure captures `LockedRingBuffer` directly; frames are appended
/// on the capture queue with no main-actor hop, keeping the queue non-blocking.
private final class FrameForwarder: FrameReceiver, @unchecked Sendable {
    private let onFrame: (CVPixelBuffer, Double) -> Void

    init(onFrame: @escaping (CVPixelBuffer, Double) -> Void) {
        self.onFrame = onFrame
    }

    func receiveFrame(_ pixelBuffer: CVPixelBuffer, at timeSeconds: Double) {
        onFrame(pixelBuffer, timeSeconds)
    }
}

// MARK: - CaptureCoordinator

/// Orchestrates `CameraCaptureController`, `AudioImpactMonitor`, and
/// `ImpactClipWriter` to detect and publish golf-impact events.
///
/// ## Concurrency model
///
/// `CaptureCoordinator` is isolated to `@MainActor` for all public API and
/// `@Published` state mutations.  Frame delivery from `CameraCaptureController`
/// arrives on the AVFoundation capture queue (`capturekit.frames`); a
/// `FrameForwarder` closure routes those frames directly into `LockedRingBuffer`
/// (NSLock-protected) without any main-actor hop, keeping the capture queue
/// non-blocking.  Impact callbacks from `AudioImpactMonitor` are dispatched by
/// that class to `DispatchQueue.main`; the coordinator bridges back to
/// `@MainActor` via `MainActor.assumeIsolated`.  Clip writing is dispatched to
/// a `Task.detached` with `.utility` priority so it runs on the cooperative
/// thread pool — never on the capture queue.
///
/// ## Motion-confirmation seam (Phase 0 → Plan 5/6)
///
/// In Phase 0 (`departureProvider == nil`) every audio transient immediately
/// triggers a ring-buffer snapshot and an `ImpactCapture` publication.
/// `ImpactConfirmation.isConfirmed` is **not called** and **no departure time
/// is fabricated** — the seam is explicitly open.
///
/// To enable full motion confirmation (Plan 5/6), set `departureProvider` to a
/// closure that returns the ball-departure time (seconds, same clock as the
/// audio engine) for a given audio-transient timestamp.  When non-nil the
/// coordinator calls `ImpactConfirmation.isConfirmed` and only publishes when
/// the departure falls within the confirmation window.  The closure is invoked
/// synchronously on the main actor and must not block.
@MainActor
final class CaptureCoordinator: ObservableObject {

    // MARK: - Published state

    @Published private(set) var status: CaptureStatus = .idle

    // MARK: - Callbacks

    /// Invoked on the main actor after each confirmed capture.
    /// Replace before calling `arm()`.
    var onImpactCapture: (ImpactCapture) -> Void = { _ in }

    // MARK: - Motion-confirmation seam

    /// Set by Plan 5/6 to enable `ImpactConfirmation`-based filtering.
    ///
    /// - `nil`     → Phase 0: audio-only trigger, no departure-time check.
    ///               **No departure time is synthesised** — the seam is
    ///               deliberately left open to prevent silent false-positives
    ///               from fabricated data.
    /// - non-nil   → Phase 1: queries VisionCore for ball departure; only
    ///               events confirmed by `ImpactConfirmation` are published.
    ///
    /// The closure is invoked synchronously on the main actor and must not block.
    var departureProvider: ((Double) -> Double?)?

    // MARK: - Private state

    private let config: CaptureConfiguration
    private let camera: CameraCaptureController
    private let audio: AudioImpactMonitor
    private let clipWriter = ImpactClipWriter()

    /// Holds the last `config.ringBufferCapacity` frames; guarded by its
    /// internal `NSLock` so the capture queue and main actor can access it
    /// concurrently without data races.
    private let lockedBuffer: LockedRingBuffer<Timestamped<CVPixelBuffer>>

    /// Keeps the `FrameForwarder` alive for the duration of the camera session.
    private let frameForwarder: FrameForwarder

    private var isArmed = false

    // MARK: - Init

    /// Creates a coordinator with the given capture configuration.
    init(config: CaptureConfiguration = .default) {
        self.config = config

        // 1. Build the locked buffer first — the forwarder closure captures `lb`
        //    directly, so `self` is not needed at this point.
        let lb = LockedRingBuffer<Timestamped<CVPixelBuffer>>(
            capacity: config.ringBufferCapacity
        )
        lockedBuffer = lb

        // 2. Forwarder closure: runs on capturekit.frames (the AVFoundation
        //    capture queue).  Appends directly to the locked buffer without
        //    acquiring any Swift actor executor — non-blocking by design.
        let fwd = FrameForwarder { pixelBuffer, timeSeconds in
            lb.append(Timestamped(timeSeconds: timeSeconds, value: pixelBuffer))
        }
        frameForwarder = fwd

        // 3. Subsystems — no side effects at construction time.
        camera = CameraCaptureController(config: config, receiver: fwd)
        audio  = AudioImpactMonitor()
    }

    // MARK: - Public API

    /// Requests camera and microphone permissions, wires subsystems, and begins
    /// capture.  Publishes `.running` (or `.needsMoreLight`) on success.
    ///
    /// - Throws: `CaptureSetupError` if the camera cannot be configured.
    func arm() async throws {
        guard !isArmed else { return }

        // Camera authorization
        guard await camera.requestAuthorization() else {
            status = .unauthorized
            return
        }

        // Microphone authorization
        guard await audio.requestAuthorization() else {
            status = .unauthorized
            return
        }

        // Status forwarding from CameraCaptureController.
        // `camera.start()` calls this synchronously on the current thread
        // (main actor), so direct assignment is safe; DispatchQueue.main.async
        // is a belt-and-suspenders guard for any future code paths.
        camera.onStatusChange = { [weak self] newStatus in
            DispatchQueue.main.async { self?.status = newStatus }
        }

        // Impact callback — AudioImpactMonitor already dispatches to
        // DispatchQueue.main before invoking `onImpact`, so we use
        // `assumeIsolated` to tell Swift concurrency we are on the main actor.
        audio.onImpact = { [weak self] impactTime in
            MainActor.assumeIsolated {
                self?.handleImpact(at: impactTime)
            }
        }

        // Start audio first; if camera setup fails, stop audio for clean teardown.
        try audio.start()
        do {
            try camera.start()
        } catch {
            audio.stop()
            throw error
        }

        isArmed = true
    }

    /// Stops both subsystems and publishes `.idle`.
    func disarm() {
        guard isArmed else { return }
        camera.stop()
        audio.stop()
        isArmed = false
        status = .idle
    }

    // MARK: - Private — impact handling

    /// Called on the main actor when the audio monitor fires a transient.
    private func handleImpact(at impactTime: Double) {

        // ── Motion-confirmation gate ──────────────────────────────────────────
        // Phase 0: departureProvider == nil → confirm on audio alone.
        // Phase 1: departureProvider != nil → require ImpactConfirmation.
        //
        // IMPORTANT: No departure time is fabricated in Phase 0.  The seam is
        // left explicitly open; fabricating a value here would silently corrupt
        // Phase 1 behaviour once VisionCore (Plan 5) is integrated.
        if let provider = departureProvider {
            let departure = provider(impactTime)
            guard ImpactConfirmation.isConfirmed(
                audioTransientTime: impactTime,
                ballDepartureTime: departure
            ) else { return }
        }
        // Phase 0: fall through without any departure-time check.

        // ── Ring-buffer snapshot ──────────────────────────────────────────────
        // `snapshot()` acquires the NSLock briefly; the lock is not held across
        // the ImpactWindow.slice or any subsequent processing.
        let allFrames = lockedBuffer.snapshot()
        let window = ImpactWindow.slice(
            allFrames,
            impactTime: impactTime,
            preRoll: config.preRollSeconds,
            postRoll: config.postRollSeconds
        )

        let capture = ImpactCapture(impactTime: impactTime, frames: window)

        // ── Publish to caller ─────────────────────────────────────────────────
        onImpactCapture(capture)

        // ── Optional clip write ───────────────────────────────────────────────
        // CVPixelBuffer is not `Sendable` in iOS 26's Swift overlay, so
        // `[Timestamped<CVPixelBuffer>]` cannot safely cross into a
        // `Task.detached` region under Swift 6 strict concurrency.
        //
        // Phase 0 workaround: use `Task { }` (inherits @MainActor context).
        // The `write` call is `nonisolated async`, so it suspends cooperatively
        // via `await writer.finishWriting()` — the main thread is NOT blocked;
        // AVAssetWriter performs encoding on its own internal queues.
        //
        // TODO (Phase 1): once CVPixelBuffer gains a Sendable conformance (or
        // Timestamped is retrofitted), switch to `Task.detached(priority: .utility)`
        // to truly move clip encoding off the main actor's executor.
        guard !capture.frames.isEmpty else { return }
        let fps    = config.targetFPS
        let writer = clipWriter
        let url    = writer.makeClipURL()
        Task(priority: .utility) { @MainActor in
            try? await writer.write(frames: capture.frames, fps: fps, to: url)
        }
    }
}
