// chunky/chunky/SpinCore/Core/MarkingAngleEstimator.swift
import Foundation

/// The angular position of a ball's surface marking, plus a 0…1 strength that
/// reflects how marking-like the detected dark region is.
nonisolated struct MarkingObservation: Equatable {
    let angleRadians: Double
    let strength: Double
}

/// Estimates a marked ball's dominant marking angle within a ball crop.
/// A protocol so a Vision/Core ML estimator can drop in later (spec §8).
nonisolated protocol MarkingAngleEstimator {
    func markingAngle(in crop: GrayImage, center: Vec2, radiusPx: Double) -> MarkingObservation?
}

/// Classical estimator: the centroid of dark pixels inside the ball disk gives
/// the marking's angular position. Fast, pure, works when marking contrast is
/// good; degrades (nil / low strength) on blank or blurred balls.
nonisolated struct ClassicalMarkingEstimator: MarkingAngleEstimator {
    var darkThreshold: UInt8 = 90
    var innerRadiusRatio: Double = 0.85
    var minMarkingPixels: Int = 8

    func markingAngle(in crop: GrayImage, center: Vec2, radiusPx: Double) -> MarkingObservation? {
        guard radiusPx > 0 else { return nil }
        let rIn = radiusPx * innerRadiusRatio
        let rIn2 = rIn * rIn
        var sumX = 0.0, sumY = 0.0, dark = 0, inDisk = 0
        for y in 0..<crop.height {
            let dy = Double(y) - center.y
            for x in 0..<crop.width {
                let dx = Double(x) - center.x
                if dx*dx + dy*dy <= rIn2 {
                    inDisk += 1
                    if crop.pixel(x: x, y: y) < darkThreshold {
                        sumX += dx; sumY += dy; dark += 1
                    }
                }
            }
        }
        guard dark >= minMarkingPixels, inDisk > 0 else { return nil }
        let angle = atan2(sumY / Double(dark), sumX / Double(dark))
        let frac = Double(dark) / Double(inDisk)
        let strength = frac > 0.5 ? 0.1 : min(1.0, frac / 0.15)
        return MarkingObservation(angleRadians: angle, strength: strength)
    }
}
