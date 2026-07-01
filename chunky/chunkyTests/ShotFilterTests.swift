// chunky/chunkyTests/ShotFilterTests.swift
import XCTest
@testable import chunky

final class ShotFilterTests: XCTestCase {
    private func rec(_ carry: Double, _ t: TimeInterval, club: UUID, conf: ConfidenceLevel = .high, excluded: Bool = false) -> ShotRecord {
        ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: t), clubID: club, clubName: "C",
                   carryMeters: carry, ballSpeedMS: 50, launchAngleDeg: 16, spinRPM: 6000,
                   spinSource: .modeled, clubSpeedMS: nil, smashFactor: nil,
                   confidence: conf,
                   isExcludedFromAverages: excluded)
    }

    func testFilterByClubAndExcluded() {
        let a = UUID(), b = UUID()
        let recs = [rec(150, 1, club: a), rec(160, 2, club: b), rec(170, 3, club: a, excluded: true)]
        var f = ShotFilter(); f.clubID = a; f.includeExcluded = false
        let out = f.apply(to: recs)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out.first!.carryMeters, 150, accuracy: 1e-9)
    }

    func testFilterByConfidenceAndDate() {
        let a = UUID()
        let recs = [rec(150, 10, club: a, conf: .low), rec(160, 20, club: a, conf: .high)]
        var f = ShotFilter(); f.confidence = .high
        XCTAssertEqual(f.apply(to: recs).count, 1)
        var g = ShotFilter(); g.dateRange = Date(timeIntervalSince1970: 15)...Date(timeIntervalSince1970: 25)
        XCTAssertEqual(g.apply(to: recs).count, 1)
    }

    func testSort() {
        let a = UUID()
        let recs = [rec(150, 1, club: a), rec(170, 3, club: a), rec(160, 2, club: a)]
        XCTAssertEqual(ShotSort.longestCarry.sort(recs).map(\.carryMeters), [170, 160, 150])
        XCTAssertEqual(ShotSort.newest.sort(recs).first?.timestamp, Date(timeIntervalSince1970: 3))
    }
}
