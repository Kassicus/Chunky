// chunky/chunkyTests/ConnectedComponentsTests.swift
import XCTest
@testable import chunky

final class ConnectedComponentsTests: XCTestCase {
    // Build an image with two separated bright squares on a dark field.
    private func twoSquares() -> GrayImage {
        var p = [UInt8](repeating: 0, count: 10 * 10)
        func set(_ x: Int, _ y: Int) { p[y*10+x] = 255 }
        for y in 1...2 { for x in 1...2 { set(x,y) } }   // 2x2 at (1..2,1..2)
        for y in 6...8 { for x in 6...8 { set(x,y) } }   // 3x3 at (6..8,6..8)
        return GrayImage(width: 10, height: 10, pixels: p)
    }

    func testFindsTwoBlobsWithCorrectSizes() {
        let blobs = ConnectedComponents.blobs(in: twoSquares(), threshold: 127)
            .sorted { $0.pixelCount < $1.pixelCount }
        XCTAssertEqual(blobs.count, 2)
        XCTAssertEqual(blobs[0].pixelCount, 4)   // 2x2
        XCTAssertEqual(blobs[1].pixelCount, 9)   // 3x3
    }
    func testCentroidOfSquare() {
        let blobs = ConnectedComponents.blobs(in: twoSquares(), threshold: 127)
        let big = blobs.max { $0.pixelCount < $1.pixelCount }!
        XCTAssertEqual(big.centroid.x, 7, accuracy: 1e-9)  // center of 6..8
        XCTAssertEqual(big.centroid.y, 7, accuracy: 1e-9)
    }
    func testEmptyWhenAllBelowThreshold() {
        XCTAssertTrue(ConnectedComponents.blobs(in: GrayImage.filled(width: 5, height: 5, value: 10), threshold: 127).isEmpty)
    }
}
