// chunky/chunky/SpinCore/Core/SpinRateEstimator.swift
import Foundation

/// Turns a sequence of (time, marking-angle) samples into an aliasing-resolved
/// backspin rate. At high rpm the ball turns a large fraction of a revolution
/// between 240 fps frames, so the wrapped per-frame delta is ambiguous by whole
/// revolutions; the modeled-spin prior disambiguates which revolution count is
/// physically intended (spec §8). Most reliable on irons/wedges, least on driver.
nonisolated struct SpinRateEstimator {
    var minPlausibleRPM = 300.0
    var maxPlausibleRPM = 14000.0

    struct Estimate: Equatable { let rpm: Double; let confidence: Double }

    func estimate(angles: [Timestamped<Double>], modeledPriorRPM: Double) -> Estimate? {
        guard angles.count >= 3 else { return nil }
        var omegas: [Double] = []
        for i in 1..<angles.count {
            let dt = angles[i].timeSeconds - angles[i-1].timeSeconds
            guard dt > 0 else { continue }
            let raw = Self.wrapToPi(angles[i].value - angles[i-1].value)
            let priorTurn = (modeledPriorRPM * 2 * .pi / 60.0) * dt
            let k = ((priorTurn - raw) / (2 * .pi)).rounded()
            let signed = raw + k * 2 * .pi
            omegas.append(signed / dt)
        }
        guard !omegas.isEmpty else { return nil }
        let mean = omegas.reduce(0, +) / Double(omegas.count)
        let rpm = abs(mean) * 60.0 / (2 * .pi)
        guard rpm >= minPlausibleRPM, rpm <= maxPlausibleRPM else {
            return Estimate(rpm: rpm, confidence: 0)
        }
        let variance = omegas.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(omegas.count)
        let cv = mean != 0 ? variance.squareRoot() / abs(mean) : 1
        return Estimate(rpm: rpm, confidence: max(0, min(1, 1 - cv)))
    }

    /// Wraps an angle difference into (−π, π].
    static func wrapToPi(_ a: Double) -> Double {
        var x = a.truncatingRemainder(dividingBy: 2 * .pi)
        if x <= -.pi { x += 2 * .pi }
        if x > .pi { x -= 2 * .pi }
        return x
    }
}
