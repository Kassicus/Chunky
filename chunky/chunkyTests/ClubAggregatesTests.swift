// chunky/chunkyTests/ClubAggregatesTests.swift
import XCTest
@testable import chunky

final class ClubAggregatesTests: XCTestCase {
    private func rec(carry: Double, excluded: Bool = false, club: Double? = nil, smash: Double? = nil) -> ShotRecord {
        ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil, clubName: "7-Iron",
                   carryMeters: carry, ballSpeedMS: 50, launchAngleDeg: 16, spinRPM: 6500,
                   spinSource: .modeled, clubSpeedMS: club, smashFactor: smash,
                   confidence: .medium, isExcludedFromAverages: excluded)
    }

    func testAggregatesOverNonExcluded() {
        let agg = ClubAggregates.compute(from: [rec(carry: 150), rec(carry: 160), rec(carry: 170)])!
        XCTAssertEqual(agg.shotCount, 3)
        XCTAssertEqual(agg.meanCarryMeters, 160, accuracy: 1e-9)
        XCTAssertEqual(agg.medianCarryMeters, 160, accuracy: 1e-9)
        XCTAssertEqual(agg.minCarryMeters, 150, accuracy: 1e-9)
        XCTAssertEqual(agg.maxCarryMeters, 170, accuracy: 1e-9)
        XCTAssertEqual(agg.carryStdDevMeters, 10, accuracy: 1e-9)
    }

    func testExcludedShotsIgnored() {
        let agg = ClubAggregates.compute(from: [rec(carry: 150), rec(carry: 999, excluded: true)])!
        XCTAssertEqual(agg.shotCount, 1)
        XCTAssertEqual(agg.meanCarryMeters, 150, accuracy: 1e-9)
        XCTAssertEqual(agg.carryStdDevMeters, 0, accuracy: 1e-9) // single shot -> 0
    }

    func testAllExcludedOrEmptyReturnsNil() {
        XCTAssertNil(ClubAggregates.compute(from: []))
        XCTAssertNil(ClubAggregates.compute(from: [rec(carry: 150, excluded: true)]))
    }

    func testClubSpeedAndSmashOnlyWhenPresent() {
        let noneAgg = ClubAggregates.compute(from: [rec(carry: 150)])!
        XCTAssertNil(noneAgg.meanClubSpeedMS)
        XCTAssertNil(noneAgg.meanSmashFactor)
        let someAgg = ClubAggregates.compute(from: [rec(carry: 150, club: 40, smash: 1.33),
                                                    rec(carry: 160, club: 42, smash: 1.34)])!
        XCTAssertEqual(someAgg.meanClubSpeedMS!, 41, accuracy: 1e-9)
        XCTAssertEqual(someAgg.meanSmashFactor!, 1.335, accuracy: 1e-9)
    }
}
