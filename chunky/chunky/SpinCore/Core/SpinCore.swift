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
        guard !ballFrames.isEmpty else { return nil }
        var angles: [Timestamped<Double>] = []
        var strengths: [Double] = []
        for tp in track {
            guard let frame = Self.nearestFrame(ballFrames, time: tp.timeSeconds) else { continue }
            let half = Int((tp.radiusPx * cropPadding).rounded())
            guard half > 2 else { continue }
            let ox = Int(tp.pixel.x.rounded()) - half
            let oy = Int(tp.pixel.y.rounded()) - half
            guard let crop = frame.cropped(x: ox, y: oy, width: half * 2, height: half * 2) else { continue }
            let center = Vec2(tp.pixel.x - Double(ox), tp.pixel.y - Double(oy))
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
