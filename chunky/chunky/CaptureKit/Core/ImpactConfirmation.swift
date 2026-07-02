// chunky/chunky/CaptureKit/Core/ImpactConfirmation.swift
import Foundation

/// Debounces the audio trigger against actual ball motion: a strike is real only
/// if the ball leaves the tee-box ROI within `window` seconds after the audio
/// transient (spec §5.4). Prevents phantom shots from practice swings / neighbors.
nonisolated enum ImpactConfirmation {
    static func isConfirmed(audioTransientTime: Double,
                            ballDepartureTime: Double?,
                            window: Double = 0.080) -> Bool {
        guard let departure = ballDepartureTime else { return false }
        return departure >= audioTransientTime && departure <= audioTransientTime + window
    }
}
