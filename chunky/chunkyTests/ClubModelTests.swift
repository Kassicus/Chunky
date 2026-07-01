// chunky/chunkyTests/ClubModelTests.swift
import XCTest
import SwiftData
@testable import chunky

@MainActor
final class ClubModelTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Club.self, Shot.self, Session.self, CalibrationProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    func testInsertAndFetchClub() throws {
        let ctx = try makeContext()
        ctx.insert(Club(name: "7-Iron", type: .iron, order: 3, modeledSpinRPM: 6500))
        let clubs = try ctx.fetch(FetchDescriptor<Club>())
        XCTAssertEqual(clubs.count, 1)
        XCTAssertEqual(clubs.first?.name, "7-Iron")
        XCTAssertEqual(clubs.first?.type, .iron)
        XCTAssertFalse(clubs.first!.isArchived)
    }

    func testTypeComputedRoundTrips() {
        let c = Club(name: "Driver", type: .driver, order: 0, modeledSpinRPM: 2600)
        XCTAssertEqual(c.typeRaw, "driver")
        c.type = .wood
        XCTAssertEqual(c.typeRaw, "wood")
    }
}
