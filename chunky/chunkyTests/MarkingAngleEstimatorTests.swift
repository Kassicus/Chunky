// chunky/chunkyTests/MarkingAngleEstimatorTests.swift
import XCTest
@testable import chunky

final class MarkingAngleEstimatorTests: XCTestCase {
    // Build a white (255) square with a dark (0) filled disk marking centered at
    // (mx,my); the ball center is the image center.
    private func ballWithMark(size: Int, markCenter: (Int, Int), markRadius: Int) -> GrayImage {
        var px = [UInt8](repeating: 255, count: size*size)
        for y in 0..<size { for x in 0..<size {
            let dx = x - markCenter.0, dy = y - markCenter.1
            if dx*dx + dy*dy <= markRadius*markRadius { px[y*size + x] = 0 }
        }}
        return GrayImage(width: size, height: size, pixels: px)
    }

    func testRecoversMarkingAngleToTheRight() {
        // size 40, center (20,20), mark to the right at (32,20) → angle ≈ 0
        let img = ballWithMark(size: 40, markCenter: (32, 20), markRadius: 4)
        let obs = ClassicalMarkingEstimator().markingAngle(in: img, center: Vec2(20, 20), radiusPx: 18)
        XCTAssertNotNil(obs)
        XCTAssertEqual(obs!.angleRadians, 0, accuracy: 0.2)
        XCTAssertGreaterThan(obs!.strength, 0.3)
    }

    func testRecoversMarkingAngleDown() {
        // mark below center (20,32) → dy>0 → angle ≈ +π/2 (y-DOWN)
        let img = ballWithMark(size: 40, markCenter: (20, 32), markRadius: 4)
        let obs = ClassicalMarkingEstimator().markingAngle(in: img, center: Vec2(20, 20), radiusPx: 18)
        XCTAssertEqual(obs!.angleRadians, Double.pi/2, accuracy: 0.2)
    }

    func testBlankBallReturnsNil() {
        let white = GrayImage.filled(width: 40, height: 40, value: 255)
        XCTAssertNil(ClassicalMarkingEstimator().markingAngle(in: white, center: Vec2(20,20), radiusPx: 18))
    }
}
