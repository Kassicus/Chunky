// chunky/chunkyTests/Vec3Tests.swift
import XCTest
@testable import chunky

final class Vec3Tests: XCTestCase {
    func testMagnitude() {
        XCTAssertEqual(Vec3(3, 4, 0).magnitude, 5, accuracy: 1e-12)
    }

    func testAddSubtract() {
        XCTAssertEqual(Vec3(1, 2, 3) + Vec3(4, 5, 6), Vec3(5, 7, 9))
        XCTAssertEqual(Vec3(4, 5, 6) - Vec3(1, 2, 3), Vec3(3, 3, 3))
    }

    func testScalarMultiplyBothOrders() {
        XCTAssertEqual(2.0 * Vec3(1, 2, 3), Vec3(2, 4, 6))
        XCTAssertEqual(Vec3(1, 2, 3) * 2.0, Vec3(2, 4, 6))
    }

    func testDot() {
        XCTAssertEqual(Vec3(1, 2, 3).dot(Vec3(4, 5, 6)), 32, accuracy: 1e-12)
    }

    func testCrossRightHanded() {
        // x cross y = z
        XCTAssertEqual(Vec3(1, 0, 0).cross(Vec3(0, 1, 0)), Vec3(0, 0, 1))
        // z cross x = y   (backspin axis +z, velocity +x → lift +y)
        XCTAssertEqual(Vec3(0, 0, 1).cross(Vec3(1, 0, 0)), Vec3(0, 1, 0))
    }

    func testNormalized() {
        let n = Vec3(0, 3, 0).normalized
        XCTAssertEqual(n.x, 0, accuracy: 1e-12)
        XCTAssertEqual(n.y, 1, accuracy: 1e-12)
        XCTAssertEqual(n.z, 0, accuracy: 1e-12)
    }

    func testNormalizedZeroIsZero() {
        XCTAssertEqual(Vec3.zero.normalized, Vec3.zero)
    }
}
