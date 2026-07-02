// chunky/chunky/VisionCore/Core/GrayImage.swift
import Foundation

/// 8-bit luma image. Origin top-left, x→right, y→DOWN (row index = y), so
/// physical "up" is the −y direction (calibration produces imageUpUnit in this
/// same space). Pure value type — no capture/vision frameworks.
nonisolated struct GrayImage: Equatable, Sendable {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(width > 0 && height > 0, "GrayImage dimensions must be positive")
        precondition(pixels.count == width * height, "pixel count must equal width*height")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    func pixel(x: Int, y: Int) -> UInt8 {
        guard x >= 0, x < width, y >= 0, y < height else { return 0 }
        return pixels[y * width + x]
    }

    static func filled(width: Int, height: Int, value: UInt8) -> GrayImage {
        GrayImage(width: width, height: height, pixels: Array(repeating: value, count: width * height))
    }
}
