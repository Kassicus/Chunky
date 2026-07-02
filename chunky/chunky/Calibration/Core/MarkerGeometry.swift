// chunky/chunky/Calibration/Core/MarkerGeometry.swift
// Pure marker-corner geometry. No Apple frameworks required.

import Foundation

nonisolated enum MarkerGeometry {
    /// Returns the 4 corners ordered TL, TR, BR, BL, or nil unless exactly 4 corners are provided.
    ///
    /// Ordering strategy: compute the centroid, then sort by atan2(dy, dx) from the centroid.
    /// In image coordinates (y-down), ascending angle order produces TL → TR → BR → BL:
    ///   TL ≈ -135°, TR ≈ -45°, BR ≈ +45°, BL ≈ +135°.
    static func orderedCorners(_ corners: [Vec2]) -> [Vec2]? {
        guard corners.count == 4 else { return nil }
        let cx = corners.map(\.x).reduce(0, +) / 4.0
        let cy = corners.map(\.y).reduce(0, +) / 4.0
        return corners.sorted { a, b in
            atan2(a.y - cy, a.x - cx) < atan2(b.y - cy, b.x - cx)
        }
    }

    /// Mean of the 4 consecutive-edge lengths of the ordered quad.
    /// Requires exactly 4 corners (use the output of `orderedCorners`).
    static func averageSideLengthPx(_ orderedCorners: [Vec2]) -> Double {
        precondition(orderedCorners.count == 4, "averageSideLengthPx requires exactly 4 corners")
        var total = 0.0
        for i in 0..<4 {
            let a = orderedCorners[i]
            let b = orderedCorners[(i + 1) % 4]
            let dx = b.x - a.x
            let dy = b.y - a.y
            total += (dx * dx + dy * dy).squareRoot()
        }
        return total / 4.0
    }
}
