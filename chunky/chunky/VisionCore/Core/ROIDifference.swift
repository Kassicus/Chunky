// chunky/chunky/VisionCore/Core/ROIDifference.swift
import Foundation

/// Computes mean absolute luma difference within a region of interest.
///
/// Pure over `GrayImage` — Foundation-only, no device frameworks.
nonisolated enum ROIDifference {

    /// Mean absolute luma difference within `roi`, normalized to 0…1 (divided by 255).
    ///
    /// The ROI is clamped to the intersection of both images' bounds.  If the
    /// clamped region is empty (zero-area, negative-size, or entirely outside either
    /// image), returns 0.
    ///
    /// - Parameters:
    ///   - previous: The earlier frame.
    ///   - current:  The later frame.
    ///   - roi:      Region of interest in image-plane coordinates (x→right, y→DOWN).
    ///               Negative origins and out-of-bounds extents are handled by clamping.
    static func activity(previous: GrayImage, current: GrayImage,
                         roi: (x: Int, y: Int, w: Int, h: Int)) -> Double {
        // Intersection of both images' bounds in image-plane coordinates.
        let maxX = min(previous.width, current.width)
        let maxY = min(previous.height, current.height)

        // Clamp the ROI origin and extent to the intersection.
        let startX = max(0, roi.x)
        let startY = max(0, roi.y)
        let endX   = min(maxX, roi.x + roi.w)
        let endY   = min(maxY, roi.y + roi.h)

        // Guard: empty or inverted region.
        guard startX < endX, startY < endY else { return 0 }

        let count = (endX - startX) * (endY - startY)
        var sum = 0
        for y in startY..<endY {
            for x in startX..<endX {
                let diff = Int(previous.pixel(x: x, y: y)) - Int(current.pixel(x: x, y: y))
                sum += abs(diff)
            }
        }

        return Double(sum) / Double(count * 255)
    }
}
