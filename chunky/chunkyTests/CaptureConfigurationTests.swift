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
        // 0.3 s * 240 fps = 72 frames (covers preRoll 40 ms + postRoll 120 ms + latency margin)
        XCTAssertEqual(CaptureConfiguration.default.ringBufferCapacity, 72)
    }
}
