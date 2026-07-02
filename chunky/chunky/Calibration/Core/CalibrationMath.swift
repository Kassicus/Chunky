// chunky/chunky/Calibration/Core/CalibrationMath.swift
// Pure calibration math: scale (px/m) and image-up direction. No Apple frameworks required.

import Foundation

nonisolated enum CalibrationMath {
    /// Pixels per meter derived from a detected ArUco/ChArUco marker.
    ///
    /// Returns nil if `markerCornersPx` does not contain exactly 4 corners
    /// or if `markerSideMeters` is ≤ 0.
    static func pixelsPerMeter(markerCornersPx: [Vec2], markerSideMeters: Double) -> Double? {
        guard let ordered = MarkerGeometry.orderedCorners(markerCornersPx),
              markerSideMeters > 0 else {
            return nil
        }
        return MarkerGeometry.averageSideLengthPx(ordered) / markerSideMeters
    }

    /// Unit vector in image-pixel space pointing to physical "up".
    ///
    /// Image y increases downward, so the in-image gravity direction points
    /// toward larger y. Physical up is exactly opposite: `(-gravity).normalized`.
    static func imageUpUnit(imagePlaneGravity: Vec2) -> Vec2 {
        Vec2(-imagePlaneGravity.x, -imagePlaneGravity.y).normalized
    }

    /// Combines pixel scale and image-up direction into a `CalibrationScale`.
    ///
    /// Returns nil when `pixelsPerMeter` would return nil (wrong corner count or non-positive side).
    static func calibrationScale(
        markerCornersPx: [Vec2],
        markerSideMeters: Double,
        imagePlaneGravity: Vec2
    ) -> CalibrationScale? {
        guard let ppm = pixelsPerMeter(
            markerCornersPx: markerCornersPx,
            markerSideMeters: markerSideMeters
        ) else { return nil }
        return CalibrationScale(
            pixelsPerMeter: ppm,
            imageUpUnit: imageUpUnit(imagePlaneGravity: imagePlaneGravity)
        )
    }

    /// Pixels-per-meter from two user-tapped points a known physical distance apart.
    static func pixelsPerMeter(pointA: Vec2, pointB: Vec2, knownLengthMeters: Double) -> Double? {
        guard knownLengthMeters > 0 else { return nil }
        let d = (pointB - pointA).magnitude
        guard d > 0 else { return nil }
        return d / knownLengthMeters
    }

    /// Builds a `CalibrationScale` from two known-distance points plus gravity.
    static func calibrationScale(pointA: Vec2, pointB: Vec2, knownLengthMeters: Double,
                                 imagePlaneGravity: Vec2) -> CalibrationScale? {
        guard let ppm = pixelsPerMeter(pointA: pointA, pointB: pointB, knownLengthMeters: knownLengthMeters)
        else { return nil }
        return CalibrationScale(pixelsPerMeter: ppm,
                                imageUpUnit: imageUpUnit(imagePlaneGravity: imagePlaneGravity))
    }
}
