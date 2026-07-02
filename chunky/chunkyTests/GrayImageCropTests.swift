// chunky/chunkyTests/GrayImageCropTests.swift
import XCTest
@testable import chunky

final class GrayImageCropTests: XCTestCase {
    // 3x2 image, row-major:  [0,1,2, 3,4,5]
    private let img = GrayImage(width: 3, height: 2, pixels: [0,1,2, 3,4,5])

    func testInteriorCrop() {
        let c = img.cropped(x: 1, y: 0, width: 2, height: 2)
        XCTAssertEqual(c?.width, 2); XCTAssertEqual(c?.height, 2)
        XCTAssertEqual(c?.pixels, [1,2, 4,5])
    }

    func testNegativeOriginClamps() {
        let c = img.cropped(x: -1, y: -1, width: 2, height: 2) // → x0=0,y0=0,x1=1,y1=1
        XCTAssertEqual(c?.width, 1); XCTAssertEqual(c?.height, 1)
        XCTAssertEqual(c?.pixels, [0])
    }

    func testOversizeClampsToImage() {
        let c = img.cropped(x: 0, y: 0, width: 99, height: 99)
        XCTAssertEqual(c?.width, 3); XCTAssertEqual(c?.height, 2)
        XCTAssertEqual(c?.pixels, img.pixels)
    }

    func testFullyOutOfBoundsReturnsNil() {
        XCTAssertNil(img.cropped(x: 10, y: 10, width: 4, height: 4))
        XCTAssertNil(img.cropped(x: 0, y: 0, width: 0, height: 5))
    }
}
