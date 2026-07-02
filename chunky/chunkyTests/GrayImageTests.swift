// chunky/chunkyTests/GrayImageTests.swift
import XCTest
@testable import chunky

final class GrayImageTests: XCTestCase {
    func testStorageAndAccess() {
        let img = GrayImage(width: 2, height: 2, pixels: [0, 10, 20, 30])
        XCTAssertEqual(img.pixel(x: 0, y: 0), 0)
        XCTAssertEqual(img.pixel(x: 1, y: 0), 10)
        XCTAssertEqual(img.pixel(x: 0, y: 1), 20)   // y=1 is the second row (y down)
        XCTAssertEqual(img.pixel(x: 1, y: 1), 30)
    }
    func testOutOfBoundsReturnsZero() {
        let img = GrayImage.filled(width: 2, height: 2, value: 99)
        XCTAssertEqual(img.pixel(x: -1, y: 0), 0)
        XCTAssertEqual(img.pixel(x: 0, y: 5), 0)
    }
    func testFilled() {
        XCTAssertEqual(GrayImage.filled(width: 3, height: 2, value: 7).pixels, Array(repeating: 7, count: 6))
    }
}
