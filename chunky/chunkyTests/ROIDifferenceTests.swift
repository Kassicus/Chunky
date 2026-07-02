// chunky/chunkyTests/ROIDifferenceTests.swift
import XCTest
@testable import chunky

final class ROIDifferenceTests: XCTestCase {

    // Identical images → activity == 0 regardless of ROI.
    func testIdenticalImagesZeroActivity() {
        let img = GrayImage.filled(width: 4, height: 4, value: 128)
        let result = ROIDifference.activity(
            previous: img,
            current:  img,
            roi:      (x: 0, y: 0, w: 4, h: 4)
        )
        XCTAssertEqual(result, 0.0, accuracy: 1e-9)
    }

    // Uniform delta over full-image ROI → delta / 255.
    // prev = 10, curr = 40 → |diff| = 30 for every pixel → 30/255.
    func testUniformDeltaFullROI() {
        let prev = GrayImage.filled(width: 3, height: 3, value: 10)
        let curr = GrayImage.filled(width: 3, height: 3, value: 40)
        let result = ROIDifference.activity(
            previous: prev,
            current:  curr,
            roi:      (x: 0, y: 0, w: 3, h: 3)
        )
        XCTAssertEqual(result, 30.0 / 255.0, accuracy: 1e-9)
    }

    // ROI restricted to a sub-region; only that region's mean is returned.
    // 4×4 images: prev top-left 2×2 = 10, rest = 40; curr all 40.
    // ROI = top-left 2×2 → all prev pixels are 10 → diff = 30 → 30/255.
    func testSubRegionROI() {
        var pixels = [UInt8](repeating: 40, count: 16)
        for y in 0..<2 {
            for x in 0..<2 {
                pixels[y * 4 + x] = 10
            }
        }
        let prev = GrayImage(width: 4, height: 4, pixels: pixels)
        let curr = GrayImage.filled(width: 4, height: 4, value: 40)
        let result = ROIDifference.activity(
            previous: prev,
            current:  curr,
            roi:      (x: 0, y: 0, w: 2, h: 2)
        )
        XCTAssertEqual(result, 30.0 / 255.0, accuracy: 1e-9)
    }

    // ROI entirely outside the image → 0.
    func testOutOfBoundsROIReturnsZero() {
        let img = GrayImage.filled(width: 4, height: 4, value: 50)
        let result = ROIDifference.activity(
            previous: img,
            current:  img,
            roi:      (x: 10, y: 10, w: 5, h: 5)
        )
        XCTAssertEqual(result, 0.0)
    }

    // Negative origin: ROI (−1, −1, 3, 3) clamps to [0,2)×[0,2).
    // prev = 0, curr = 100 → diff = 100 → 100/255.
    func testNegativeOriginClamped() {
        let prev = GrayImage.filled(width: 4, height: 4, value: 0)
        let curr = GrayImage.filled(width: 4, height: 4, value: 100)
        let result = ROIDifference.activity(
            previous: prev,
            current:  curr,
            roi:      (x: -1, y: -1, w: 3, h: 3)
        )
        XCTAssertEqual(result, 100.0 / 255.0, accuracy: 1e-9)
    }

    // Zero-size ROI → 0.
    func testEmptyROIReturnsZero() {
        let img = GrayImage.filled(width: 4, height: 4, value: 128)
        let result = ROIDifference.activity(
            previous: img,
            current:  img,
            roi:      (x: 0, y: 0, w: 0, h: 0)
        )
        XCTAssertEqual(result, 0.0)
    }

    // Differing image sizes: intersection = [0, min(w1,w2)) × [0, min(h1,h2)).
    // prev 2×2, curr 4×4; ROI requests 4×4 → clamped to 2×2 overlap.
    // prev = 20, curr = 70 → diff = 50 → 50/255.
    func testDifferingImageSizesUsesOverlap() {
        let prev = GrayImage.filled(width: 2, height: 2, value: 20)
        let curr = GrayImage.filled(width: 4, height: 4, value: 70)
        let result = ROIDifference.activity(
            previous: prev,
            current:  curr,
            roi:      (x: 0, y: 0, w: 4, h: 4)
        )
        XCTAssertEqual(result, 50.0 / 255.0, accuracy: 1e-9)
    }
}
