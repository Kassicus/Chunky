// chunky/chunkyTests/CaptureConfigurationTests.swift
import XCTest
@testable import chunky

final class CaptureConfigurationTests: XCTestCase {
    func testDefaults() {
        let c = CaptureConfiguration.default
        XCTAssertEqual(c.lens, .telephoto)
        XCTAssertEqual(c.targetFPS, 240, accuracy: 1e-9)
        XCTAssertEqual(c.resolutionHeight, 1080)
        XCTAssertEqual(c.shutterSeconds, 1.0/2000, accuracy: 1e-12)
    }

    func testRingBufferCapacity() {
        // 0.5 s * 240 fps = 120 frames
        XCTAssertEqual(CaptureConfiguration.default.ringBufferCapacity, 120)
    }
}
