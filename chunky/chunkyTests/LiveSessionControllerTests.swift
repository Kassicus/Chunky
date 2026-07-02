// chunky/chunkyTests/LiveSessionControllerTests.swift
import XCTest
@testable import chunky

@MainActor
final class LiveSessionControllerTests: XCTestCase {
    func testCannotArmWithoutClubOrCalibration() {
        let c = LiveSessionController()
        XCTAssertFalse(c.canArm)   // no club, no calibration
    }
    // Full arm()/capture paths need a device and are validated on-device.
}
