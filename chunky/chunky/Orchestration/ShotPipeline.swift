// chunky/chunky/Orchestration/ShotPipeline.swift
import CoreVideo
import Foundation

/// App-orchestration glue: turns a captured impact window (or an already-tracked
/// path) into a `ShotResult` plus the serialized raw track for persistence.
///
/// Imports CoreVideo (via `ImpactCapture`), so it lives in `Orchestration/`,
/// never in the pure `Metrics` package.
nonisolated struct ShotPipeline {
    var vision = VisionPipeline()
    var spin = SpinCore()

    struct Output: Equatable {
        let result: ShotResult
        let rawTrackJSON: String
        let trackPointCount: Int
    }

    /// Pure path: a tracked ball path (+ optional measured spin) → result.
    func output(track: [TrackPoint], calibration: CalibrationScale,
                atmosphere: Atmosphere, modeledSpinRPM: Double,
                measuredSpin: MeasuredSpin? = nil) -> Output? {
        guard let result = Metrics.computeShot(track: track, calibration: calibration,
                                               atmosphere: atmosphere,
                                               modeledSpinRPM: modeledSpinRPM,
                                               measuredSpin: measuredSpin) else { return nil }
        return Output(result: result, rawTrackJSON: ShotTrackCodec.encode(track),
                      trackPointCount: track.count)
    }

    /// Full path: raw capture → track → measured spin → result.
    func output(from capture: ImpactCapture, calibration: CalibrationScale,
                atmosphere: Atmosphere, modeledSpinRPM: Double,
                detector: BallDetector = BlobBallDetector()) -> Output? {
        let track = vision.track(capture, detector: detector)
        // Convert frames to GrayImages (skip unsupported), preserving timestamps,
        // and measure backspin from the marking rotation.
        var grayFrames: [Timestamped<GrayImage>] = []
        for f in capture.frames {
            if let g = PixelBufferGray.grayImage(from: f.value) {
                grayFrames.append(Timestamped(timeSeconds: f.timeSeconds, value: g))
            }
        }
        let measured = spin.measure(ballFrames: grayFrames, track: track, modeledSpinRPM: modeledSpinRPM)
        return output(track: track, calibration: calibration, atmosphere: atmosphere,
                      modeledSpinRPM: modeledSpinRPM, measuredSpin: measured)
    }
}
