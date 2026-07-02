// chunky/chunky/VisionCore/Core/ScaleSanity.swift
import Foundation

nonisolated enum ScaleSanity {
    static func pixelsPerMeter(ballRadiusPx: Double, ballDiameterMeters: Double = 0.04267) -> Double {
        (2 * ballRadiusPx) / ballDiameterMeters
    }
    static func agrees(estimatedPxPerMeter: Double, calibratedPxPerMeter: Double, tolerance: Double = 0.25) -> Bool {
        guard calibratedPxPerMeter > 0 else { return false }
        return abs(estimatedPxPerMeter - calibratedPxPerMeter) / calibratedPxPerMeter <= tolerance
    }
}
