// chunky/chunkyTests/MotionDepartureTests.swift
import XCTest
@testable import chunky

final class MotionDepartureTests: XCTestCase {
    func testFirstAboveThreshold() {
        let a = [Timestamped(timeSeconds: 0.0, value: 0.01),
                 Timestamped(timeSeconds: 0.1, value: 0.02),
                 Timestamped(timeSeconds: 0.2, value: 0.9),   // ball departs
                 Timestamped(timeSeconds: 0.3, value: 0.8)]
        XCTAssertEqual(MotionDeparture(activityThreshold: 0.5).departureTime(activity: a)!, 0.2, accuracy: 1e-9)
    }
    func testNilWhenNoDeparture() {
        let a = [Timestamped(timeSeconds: 0.0, value: 0.01), Timestamped(timeSeconds: 0.1, value: 0.02)]
        XCTAssertNil(MotionDeparture(activityThreshold: 0.5).departureTime(activity: a))
    }
}
