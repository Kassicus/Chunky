// chunky/chunky/CaptureKit/Core/ExposureCalculator.swift
import Foundation

nonisolated struct ExposureRecommendation: Equatable, Sendable {
    let iso: Double
    let needsMoreLight: Bool
}

/// Computes the ISO needed to keep the auto-metered exposure while forcing a
/// short shutter to freeze the ball (spec §5.2). Exposure ∝ duration × ISO, so
/// shortening the duration requires raising ISO by the inverse ratio.
nonisolated enum ExposureCalculator {
    static func recommend(autoISO: Double, autoDuration: Double, targetDuration: Double,
                          minISO: Double, maxISO: Double) -> ExposureRecommendation {
        let ideal = autoISO * (autoDuration / targetDuration)
        let clamped = min(max(ideal, minISO), maxISO)
        return ExposureRecommendation(iso: clamped, needsMoreLight: ideal > maxISO)
    }
}
