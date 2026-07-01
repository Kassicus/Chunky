import XCTest
@testable import chunky

final class ConversionsTests: XCTestCase {
    func testMphMs() {
        XCTAssertEqual(Conversions.mphToMS(100), 44.704, accuracy: 1e-9)
        XCTAssertEqual(Conversions.msToMPH(44.704), 100, accuracy: 1e-9)
    }

    func testYardsMeters() {
        XCTAssertEqual(Conversions.yardsToMeters(100), 91.44, accuracy: 1e-9)
        XCTAssertEqual(Conversions.metersToYards(91.44), 100, accuracy: 1e-9)
    }

    func testRpmToRadPerSec() {
        // 60 rpm = 1 rev/s = 2π rad/s
        XCTAssertEqual(Conversions.rpmToRadPerSec(60), 2 * .pi, accuracy: 1e-12)
    }

    func testDegToRad() {
        XCTAssertEqual(Conversions.degToRad(180), .pi, accuracy: 1e-12)
    }
}
