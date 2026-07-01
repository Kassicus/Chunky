// chunky/chunky/Metrics/Metrics.swift
import Foundation

/// Pure metric extraction and carry orchestration (spec §9). Consumes tracked
/// centroids + calibration; produces launch conditions and a ShotResult. No
/// AVFoundation/Vision — deterministic and unit-testable against fixture tracks.
nonisolated enum Metrics {

    struct LaunchMeasurement: Equatable {
        let ballSpeedMS: Double
        let launchAngleDeg: Double
        let azimuthDeg: Double
        let fitRmsResidualMeters: Double
        let usedFrameCount: Int
    }

    /// Fit ball speed and vertical launch angle from the first clean frames of a
    /// track. Azimuth is the depth axis for a face-on camera and is not
    /// measurable here — reported as 0 (straight); overall confidence conveys the
    /// single-camera limitation.
    static func measureLaunch(track: [TrackPoint],
                              calibration: CalibrationScale,
                              maxFitFrames: Int = 8) -> LaunchMeasurement? {
        guard track.count >= 2 else { return nil }
        let sorted = track.sorted { $0.timeSeconds < $1.timeSeconds }
        let count = max(2, min(maxFitFrames, sorted.count))
        let window = Array(sorted.prefix(count))

        let up = calibration.imageUpUnit
        let horiz = calibration.imageHorizontalUnit
        let invScale = 1.0 / calibration.pixelsPerMeter
        let t0 = window[0].timeSeconds

        var times: [Double] = []
        var upMeters: [Double] = []
        var horizMeters: [Double] = []
        for p in window {
            times.append(p.timeSeconds - t0)
            upMeters.append(p.pixel.dot(up) * invScale)
            horizMeters.append(p.pixel.dot(horiz) * invScale)
        }

        guard let fitUp = LinearFit.fit(x: times, y: upMeters),
              let fitHoriz = LinearFit.fit(x: times, y: horizMeters) else { return nil }

        let vUp = fitUp.slope
        let vHoriz = fitHoriz.slope
        let v0 = (vUp * vUp + vHoriz * vHoriz).squareRoot()
        let launchAngleDeg = atan2(vUp, abs(vHoriz)) * 180 / .pi
        let rms = (fitUp.rmsResidual * fitUp.rmsResidual
                   + fitHoriz.rmsResidual * fitHoriz.rmsResidual).squareRoot()

        return LaunchMeasurement(
            ballSpeedMS: v0,
            launchAngleDeg: launchAngleDeg,
            azimuthDeg: 0,
            fitRmsResidualMeters: rms,
            usedFrameCount: window.count
        )
    }
}
