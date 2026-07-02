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

    struct Output: Equatable {
        let result: ShotResult
        let rawTrackJSON: String
        let trackPointCount: Int
    }

    /// Pure path: a tracked ball path → result. Unit-tested.
    func output(track: [TrackPoint], calibration: CalibrationScale,
                atmosphere: Atmosphere, modeledSpinRPM: Double) -> Output? {
        guard let result = Metrics.computeShot(track: track, calibration: calibration,
                                               atmosphere: atmosphere,
                                               modeledSpinRPM: modeledSpinRPM) else { return nil }
        return Output(result: result, rawTrackJSON: ShotTrackCodec.encode(track),
                      trackPointCount: track.count)
    }

    /// Full path: raw capture → track → result.
    func output(from capture: ImpactCapture, calibration: CalibrationScale,
                atmosphere: Atmosphere, modeledSpinRPM: Double,
                detector: BallDetector = BlobBallDetector()) -> Output? {
        let track = vision.track(capture, detector: detector)
        return output(track: track, calibration: calibration,
                      atmosphere: atmosphere, modeledSpinRPM: modeledSpinRPM)
    }
}
