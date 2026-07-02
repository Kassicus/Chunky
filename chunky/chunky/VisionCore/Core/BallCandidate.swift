// chunky/chunky/VisionCore/Core/BallCandidate.swift
import Foundation

/// A ball candidate returned by a `BallDetector`. All values are in image-pixel coordinates.
nonisolated struct BallCandidate: Equatable {
    /// Sub-pixel centroid (blob centroid).
    let center: Vec2
    /// Radius estimated from blob area: sqrt(pixelCount / π).
    let radiusPx: Double
    /// Circularity confidence in [0, 1]. Higher = more circular.
    let confidence: Double
}
