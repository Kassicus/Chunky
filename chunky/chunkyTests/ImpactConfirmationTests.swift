// chunky/chunkyTests/ImpactConfirmationTests.swift
import XCTest
@testable import chunky

final class ImpactConfirmationTests: XCTestCase {
    func testConfirmedWhenBallDepartsWithinWindow() {
        XCTAssertTrue(ImpactConfirmation.isConfirmed(audioTransientTime: 1.00,
                                                     ballDepartureTime: 1.03, window: 0.08))
    }
    func testRejectedWhenDepartureTooLate() {
        XCTAssertFalse(ImpactConfirmation.isConfirmed(audioTransientTime: 1.00,
                                                      ballDepartureTime: 1.20, window: 0.08))
    }
    func testRejectedWhenNoDeparture() {
        XCTAssertFalse(ImpactConfirmation.isConfirmed(audioTransientTime: 1.00,
                                                      ballDepartureTime: nil))
    }
    func testRejectedWhenDepartureBeforeAudio() {
        XCTAssertFalse(ImpactConfirmation.isConfirmed(audioTransientTime: 1.00,
                                                      ballDepartureTime: 0.95, window: 0.08))
    }
}
