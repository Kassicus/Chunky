// chunky/chunkyTests/ShotModelTests.swift
import XCTest
import SwiftData
@testable import chunky

@MainActor
final class ShotModelTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Club.self, Shot.self, Session.self, CalibrationProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    func testShotLinksToClubAndReadsBackEnums() throws {
        let ctx = try makeContext()
        let club = Club(name: "7-Iron", type: .iron, order: 0, modeledSpinRPM: 6500)
        ctx.insert(club)
        let shot = Shot(timestamp: Date(timeIntervalSince1970: 0), ballSpeedMS: 53.6,
                        launchAngleDeg: 16.3, azimuthDeg: 0, spinRPM: 6500,
                        spinSource: .modeled, spinAxisTiltDeg: 0, carryMeters: 150,
                        confidence: .medium)
        shot.club = club
        ctx.insert(shot)
        let shots = try ctx.fetch(FetchDescriptor<Shot>())
        XCTAssertEqual(shots.count, 1)
        XCTAssertEqual(shots.first?.spinSource, .modeled)
        XCTAssertEqual(shots.first?.confidence, .medium)
        XCTAssertEqual(shots.first?.club?.name, "7-Iron")
        XCTAssertEqual(club.shots.count, 1) // inverse populated
    }

    func testOpportunisticFieldsDefaultNil() {
        let shot = Shot(timestamp: Date(timeIntervalSince1970: 0), ballSpeedMS: 70,
                        launchAngleDeg: 11, azimuthDeg: 0, spinRPM: 2600,
                        spinSource: .modeled, spinAxisTiltDeg: 0, carryMeters: 240,
                        confidence: .high)
        XCTAssertNil(shot.clubSpeedMS)
        XCTAssertNil(shot.smashFactor)
        XCTAssertFalse(shot.isExcludedFromAverages)
    }
}
