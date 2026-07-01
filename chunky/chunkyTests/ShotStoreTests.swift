// chunky/chunkyTests/ShotStoreTests.swift
import XCTest
import SwiftData
@testable import chunky

@MainActor
final class ShotStoreTests: XCTestCase {
    private func makeStore() throws -> ShotStore {
        let container = try ModelContainer(
            for: Club.self, Shot.self, Session.self, CalibrationProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ShotStore(context: ModelContext(container))
    }

    private func sampleResult(carry: Double = 150) -> ShotResult {
        ShotResult(ballSpeedMS: 53.6, launchAngleDeg: 16.3, azimuthDeg: 0, spinRPM: 6500,
                   spinSource: .modeled, spinAxisTiltDeg: 0, carryMeters: carry,
                   confidence: .medium, fitRmsResidualMeters: 0.001, usedFrameCount: 8)
    }

    func testSaveShotAutoLinksClub() throws {
        let store = try makeStore()
        let club = store.addClub(name: "7-Iron", type: .iron, modeledSpinRPM: 6500)
        let shot = store.saveShot(sampleResult(), to: club, session: nil, rawTrackJSON: "[]")
        XCTAssertEqual(shot.club?.name, "7-Iron")
        XCTAssertEqual(shot.rawTrackJSON, "[]")
        XCTAssertEqual(club.shots.count, 1)
    }

    func testExcludeAndDelete() throws {
        let store = try makeStore()
        let club = store.addClub(name: "7-Iron", type: .iron, modeledSpinRPM: 6500)
        let s1 = store.saveShot(sampleResult(carry: 150), to: club, session: nil, rawTrackJSON: nil)
        _ = store.saveShot(sampleResult(carry: 160), to: club, session: nil, rawTrackJSON: nil)
        store.setExcluded(s1, true)
        XCTAssertTrue(s1.isExcludedFromAverages)
        let recs = club.shots.map(store.record(from:))
        XCTAssertEqual(ClubAggregates.compute(from: recs)!.shotCount, 1) // excluded dropped
        store.deleteShots([s1])
        XCTAssertEqual(club.shots.count, 1)
    }

    func testRemoveClubSoftArchivesWhenItHasShots() throws {
        let store = try makeStore()
        let club = store.addClub(name: "7-Iron", type: .iron, modeledSpinRPM: 6500)
        _ = store.saveShot(sampleResult(), to: club, session: nil, rawTrackJSON: nil)
        store.removeClub(club)
        XCTAssertTrue(club.isArchived)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<Club>()).count, 1) // still present
    }

    func testRemoveClubHardDeletesWhenEmpty() throws {
        let store = try makeStore()
        let club = store.addClub(name: "Spare", type: .wedge, modeledSpinRPM: 9000)
        store.removeClub(club)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<Club>()).count, 0)
    }
}
