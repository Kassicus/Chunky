// chunky/chunky/VisionCore/Device/VisionPipeline.swift
import CoreVideo
import Foundation

/// Wires the VisionCore pieces into a device-level pipeline.
///
/// `VisionPipeline` converts an `ImpactCapture` (raw CVPixelBuffer frames) into
/// a tracked ball path (`[TrackPoint]`).  It also provides a helper to build the
/// `departureProvider` closure that `CaptureCoordinator` uses for motion
/// confirmation.
///
/// ## Layer rules
/// This struct lives in `VisionCore/Device/` and may import CoreVideo.
/// The Core pieces it drives (`BallDetector`, `BallTracker`, `ROIDifference`,
/// `MotionDeparture`) are pure Foundation — no device frameworks.
///
/// ## Plan 6 seam
/// `makeDepartureProvider` accepts a `recentFrames` closure so that in Plan 6
/// the coordinator can supply its ring-buffer snapshot function, live-wiring
/// ROI-difference activity to the running session with no changes to
/// `VisionPipeline` itself.
nonisolated struct VisionPipeline {

    // MARK: - Impact → TrackPoint

    /// Convert each captured frame to a `GrayImage`, detect ball candidates per
    /// frame, and return the tracked path.
    ///
    /// Frames whose `CVPixelBuffer` cannot be converted (unsupported format or
    /// degenerate buffer) are skipped silently.
    func track(_ capture: ImpactCapture,
               detector: BallDetector = BlobBallDetector()) -> [TrackPoint] {
        var detections: [Timestamped<[BallCandidate]>] = []

        for frame in capture.frames {
            guard let gray = PixelBufferGray.grayImage(from: frame.value) else { continue }
            let candidates = detector.detect(in: gray)
            detections.append(Timestamped(timeSeconds: frame.timeSeconds, value: candidates))
        }

        return BallTracker().track(detections)
    }

    // MARK: - Departure provider seam

    /// Build a `departureProvider` closure for `CaptureCoordinator`.
    ///
    /// The returned closure, given the audio-transient time:
    /// 1. Pulls the current frame window via `recentFrames()`.
    /// 2. Keeps only frames at or after the transient (departure cannot precede
    ///    impact; pre-impact tee-box activity — club/hands entering the ROI —
    ///    must not register as a ball departure).
    /// 3. Converts each remaining buffer to a `GrayImage` (skips failures,
    ///    preserving timestamps).
    /// 4. Computes `ROIDifference.activity(previous:current:roi:)` between
    ///    consecutive converted frames, producing a `[Timestamped<Double>]`
    ///    activity series (timestamp = the *current* frame's time).
    /// 5. Returns `MotionDeparture(activityThreshold:).departureTime(activity:)`.
    ///
    /// Fewer than two convertible post-transient frames → nil (cannot compute a
    /// frame difference).
    ///
    /// - Parameters:
    ///   - recentFrames:      Supplies the frame window to analyze.  In Plan 6
    ///                        this will read the coordinator's ring buffer.
    ///   - roi:               The tee-box region of interest in image-plane
    ///                        coordinates (x→right, y→DOWN).
    ///   - activityThreshold: Activity level (0…1) above which ball departure is
    ///                        declared by `MotionDeparture`.
    ///
    /// - Returns: A closure `(Double) -> Double?`.  The `Double` input is the
    ///   audio-transient time (seconds, host-time clock — the same domain as the
    ///   frame PTS); frames before it are ignored so the returned departure time
    ///   always satisfies `departure >= transient`, matching what
    ///   `ImpactConfirmation` requires.  Live ring-buffer wiring lands in Plan 6.
    func makeDepartureProvider(
        recentFrames: @escaping () -> [Timestamped<CVPixelBuffer>],
        roi: (x: Int, y: Int, w: Int, h: Int),
        activityThreshold: Double
    ) -> (Double) -> Double? {
        return { transientTime in
            // Pull frames, drop any before the audio transient, and convert the
            // rest — preserving timestamps for convertible buffers.
            let frames = recentFrames()
            var converted: [Timestamped<GrayImage>] = []
            for frame in frames where frame.timeSeconds >= transientTime {
                guard let gray = PixelBufferGray.grayImage(from: frame.value) else { continue }
                converted.append(Timestamped(timeSeconds: frame.timeSeconds, value: gray))
            }

            // Need at least two frames to compute a frame difference.
            guard converted.count >= 2 else { return nil }

            // Compute per-consecutive-pair ROI activity; timestamp = current frame time.
            var activity: [Timestamped<Double>] = []
            for i in 1..<converted.count {
                let diff = ROIDifference.activity(
                    previous: converted[i - 1].value,
                    current:  converted[i].value,
                    roi:      roi
                )
                activity.append(Timestamped(timeSeconds: converted[i].timeSeconds, value: diff))
            }

            return MotionDeparture(activityThreshold: activityThreshold)
                .departureTime(activity: activity)
        }
    }
}
