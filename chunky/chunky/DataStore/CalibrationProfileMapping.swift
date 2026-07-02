// chunky/chunky/DataStore/CalibrationProfileMapping.swift
import Foundation

/// Bridges the pure `CalibrationScale` (Metrics) and the persisted
/// `CalibrationProfile` (SwiftData). `CalibrationProfile` stores the up-vector
/// as two Doubles rather than a `Vec2`.
@MainActor
enum CalibrationProfileMapping {
    static func profile(from scale: CalibrationScale, lens: CameraLens,
                        cameraDistanceM: Double = 0, createdAt: Date) -> CalibrationProfile {
        CalibrationProfile(lens: lens,
                           pxPerMeter: scale.pixelsPerMeter,
                           imageUpX: scale.imageUpUnit.x,
                           imageUpY: scale.imageUpUnit.y,
                           cameraDistanceM: cameraDistanceM,
                           createdAt: createdAt)
    }

    static func scale(from profile: CalibrationProfile) -> CalibrationScale {
        CalibrationScale(pixelsPerMeter: profile.pxPerMeter,
                         imageUpUnit: Vec2(profile.imageUpX, profile.imageUpY))
    }
}
