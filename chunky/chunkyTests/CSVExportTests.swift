// chunky/chunkyTests/CSVExportTests.swift
import XCTest
@testable import chunky

final class CSVExportTests: XCTestCase {
    func testShotsCSVHeaderAndRow() {
        let rec = ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil,
                             clubName: "7-Iron", carryMeters: 91.44, ballSpeedMS: 44.704,
                             launchAngleDeg: 16, spinRPM: 6500, spinSource: .modeled,
                             clubSpeedMS: nil, smashFactor: nil, confidence: .medium,
                             isExcludedFromAverages: false)
        let csv = CSVExport.shots([rec], units: .yards)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertTrue(lines[0].contains("club"))
        XCTAssertTrue(lines[0].contains("carry_yd"))
        XCTAssertTrue(lines[1].contains("7-Iron"))
        XCTAssertTrue(lines[1].contains("100")) // 91.44 m -> 100 yd
    }

    func testClubWithCommaIsQuoted() {
        let rec = ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil,
                             clubName: "Driver, backup", carryMeters: 100, ballSpeedMS: 70,
                             launchAngleDeg: 11, spinRPM: 2600, spinSource: .modeled,
                             clubSpeedMS: nil, smashFactor: nil, confidence: .high,
                             isExcludedFromAverages: false)
        XCTAssertTrue(CSVExport.shots([rec], units: .meters).contains("\"Driver, backup\""))
    }

    func testAveragesCSV() {
        let agg = ClubAggregates.compute(from: [
            ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil, clubName: "7-Iron",
                       carryMeters: 91.44, ballSpeedMS: 50, launchAngleDeg: 16, spinRPM: 6500,
                       spinSource: .modeled, clubSpeedMS: nil, smashFactor: nil, confidence: .high,
                       isExcludedFromAverages: false)])!
        let csv = CSVExport.clubAverages([(clubName: "7-Iron", aggregates: agg)], units: .yards)
        XCTAssertTrue(csv.contains("mean_carry_yd"))
        XCTAssertTrue(csv.contains("7-Iron"))
        XCTAssertTrue(csv.contains("100"))
    }
}
