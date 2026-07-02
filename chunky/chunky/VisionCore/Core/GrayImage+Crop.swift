// chunky/chunky/VisionCore/Core/GrayImage+Crop.swift
import Foundation

nonisolated extension GrayImage {
    /// Sub-image of the given rect, clamped to image bounds. Returns nil if the
    /// clamped rect has zero area.
    func cropped(x: Int, y: Int, width w: Int, height h: Int) -> GrayImage? {
        let x0 = max(0, x), y0 = max(0, y)
        let x1 = min(width, x + w), y1 = min(height, y + h)
        guard x1 > x0, y1 > y0 else { return nil }
        let cw = x1 - x0, ch = y1 - y0
        var out = [UInt8](repeating: 0, count: cw * ch)
        for row in 0..<ch {
            let srcStart = (y0 + row) * width + x0
            let dstStart = row * cw
            for col in 0..<cw { out[dstStart + col] = pixels[srcStart + col] }
        }
        return GrayImage(width: cw, height: ch, pixels: out)
    }
}
