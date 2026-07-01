// chunky/chunkyTests/Vec2Tests.swift
import XCTest
@testable import chunky

final class Vec2Tests: XCTestCase {
    func testMagnitude() {
        XCTAssertEqual(Vec2(3, 4).magnitude, 5, accuracy: 1e-12)
    }

    func testAddSubtractScale() {
        XCTAssertEqual(Vec2(1, 2) + Vec2(3, 4), Vec2(4, 6))
        XCTAssertEqual(Vec2(3, 4) - Vec2(1, 2), Vec2(2, 2))
        XCTAssertEqual(2.0 * Vec2(1, 2), Vec2(2, 4))
        XCTAssertEqual(Vec2(1, 2) * 2.0, Vec2(2, 4))
    }

    func testDot() {
        XCTAssertEqual(Vec2(1, 2).dot(Vec2(3, 4)), 11, accuracy: 1e-12)
    }

    func testPerpendicularIsOrthogonalUnit() {
        let up = Vec2(0, 1)
        let horiz = up.perpendicular
        XCTAssertEqual(horiz, Vec2(1, 0))
        XCTAssertEqual(up.dot(horiz), 0, accuracy: 1e-12)
    }

    func testPerpendicularOrthogonalWhenRolled() {
        let up = Vec2(0.6, 0.8) // already unit length
        XCTAssertEqual(up.dot(up.perpendicular), 0, accuracy: 1e-12)
    }

    func testNormalized() {
        let n = Vec2(0, 5).normalized
        XCTAssertEqual(n.x, 0, accuracy: 1e-12)
        XCTAssertEqual(n.y, 1, accuracy: 1e-12)
        XCTAssertEqual(Vec2.zero.normalized, Vec2.zero)
    }
}
