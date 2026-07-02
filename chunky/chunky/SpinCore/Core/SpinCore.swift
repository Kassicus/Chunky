// chunky/chunky/SpinCore/Core/SpinCore.swift
import Foundation

/// Measures backspin from a marked ball's marking rotation across the near-impact
/// frames (spec §8). Pure: operates on `GrayImage` crops. Emits `axisTiltDeg = 0`
/// because a single face-on camera cannot resolve spin-axis tilt reliably; the
/// caller (Metrics) ignores the result below its confidence threshold and uses
/// modeled spin. Most reliable on irons/wedges, least on driver.
nonisolated struct SpinCore {
    var estimator: MarkingAngleEstimator = ClassicalMarkingEstimator()
    var rateEstimator = SpinRateEstimator()
    var cropPadding = 1.15
    var minMarkingStrength = 0.3
    var minFrames = 3

    func measure(ballFrames: [Timestamped<GrayImage>], track: [TrackPoint],
                 modeledSpinRPM: Double) -> MeasuredSpin? {
        var angles: [Timestamped<Double>] = []
        var strengths: [Double] = []
        for tp in track {
            guard let frame = Self.nearestFrame(ballFrames, time: tp.timeSeconds) else { continue }
            let half = Int((tp.radiusPx * cropPadding).rounded())
            guard half > 2 else { continue }
            let ox = Int(tp.pixel.x.rounded()) - half
            let oy = Int(tp.pixel.y.rounded()) - half
            guard let crop = frame.cropped(x: ox, y: oy, width: half * 2, height: half * 2) else { continue }
            // GrayImage.cropped clamps its origin to >= 0, so the crop's (0,0)
            // maps to the CLAMPED source origin. Place the ball center in crop
            // coordinates against that clamped origin, else the center is biased
            // when the ball is near the top/left image edge (climbing iron/wedge
            // shots) and every marking angle in those frames is corrupted.
            let x0 = max(0, ox), y0 = max(0, oy)
            let center = Vec2(tp.pixel.x - Double(x0), tp.pixel.y - Double(y0))
            guard let obs = estimator.markingAngle(in: crop, center: center, radiusPx: tp.radiusPx),
                  obs.strength >= minMarkingStrength else { continue }
            angles.append(Timestamped(timeSeconds: tp.timeSeconds, value: obs.angleRadians))
            strengths.append(obs.strength)
        }
        guard angles.count >= minFrames,
              let rate = rateEstimator.estimate(angles: angles, modeledPriorRPM: modeledSpinRPM)
        else { return nil }
        let meanStrength = strengths.reduce(0, +) / Double(strengths.count)
        let frameFactor = min(1.0, Double(angles.count) / 6.0)
        let confidence = rate.confidence * meanStrength * frameFactor
        return MeasuredSpin(rpm: rate.rpm, axisTiltDeg: 0, confidence: confidence)
    }

    /// The frame whose timestamp is closest to `time`.
    static func nearestFrame(_ frames: [Timestamped<GrayImage>], time: Double) -> GrayImage? {
        frames.min(by: { abs($0.timeSeconds - time) < abs($1.timeSeconds - time) })?.value
    }
}
