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
        XCTAssertTrue(lines[0].contains("club_speed_mph"), "header missing club_speed_mph")
        XCTAssertTrue(lines[0].contains("smash"), "header missing smash")
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

    func testShotsCSVClubSpeedAndSmashPresent() {
        // Record WITH club speed and smash
        let rec = ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil,
                             clubName: "Driver", carryMeters: 250, ballSpeedMS: 76.0,
                             launchAngleDeg: 10.5, spinRPM: 2700, spinSource: .modeled,
                             clubSpeedMS: 50.0, smashFactor: 1.52, confidence: .high,
                             isExcludedFromAverages: false)
        let csv = CSVExport.shots([rec], units: .meters)
        let row = csv.split(separator: "\n")[1]
        // 50 m/s * 2.2369... ≈ 112 mph
        XCTAssertTrue(row.contains("112"), "expected club speed ~112 mph in row")
        XCTAssertTrue(row.contains("1.52"), "expected smash factor 1.52 in row")
    }

    func testShotsCSVClubSpeedAndSmashEmptyWhenNil() {
        // Record WITHOUT club speed or smash — trailing fields should be empty
        let rec = ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil,
                             clubName: "7-Iron", carryMeters: 150, ballSpeedMS: 60.0,
                             launchAngleDeg: 16.0, spinRPM: 6500, spinSource: .modeled,
                             clubSpeedMS: nil, smashFactor: nil, confidence: .medium,
                             isExcludedFromAverages: false)
        let csv = CSVExport.shots([rec], units: .meters)
        let row = String(csv.split(separator: "\n")[1])
        // Row ends with ",no,," — two empty trailing fields
        XCTAssertTrue(row.hasSuffix(",no,,"), "expected empty club_speed_mph and smash fields, got: \(row)")
    }

    func testShotsCSVLaunchAngleDecimalPreserved() {
        // launch angle of 16.3° must appear as "16.3", not "16"
        let rec = ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil,
                             clubName: "7-Iron", carryMeters: 150, ballSpeedMS: 60.0,
                             launchAngleDeg: 16.3, spinRPM: 6500, spinSource: .modeled,
                             clubSpeedMS: nil, smashFactor: nil, confidence: .medium,
                             isExcludedFromAverages: false)
        let csv = CSVExport.shots([rec], units: .meters)
        XCTAssertTrue(csv.contains("16.3"), "launch angle fractional part dropped; got: \(csv)")
        XCTAssertFalse(csv.contains(",16,"), "launch angle incorrectly truncated to integer")
    }

    func testAveragesCSV() {
        let agg = ClubAggregates.compute(from: [
            ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil, clubName: "7-Iron",
                       carryMeters: 91.44, ballSpeedMS: 50, launchAngleDeg: 16, spinRPM: 6500,
                       spinSource: .modeled, clubSpeedMS: nil, smashFactor: nil, confidence: .high,
                       isExcludedFromAverages: false)])!
        let csv = CSVExport.clubAverages([(clubName: "7-Iron", aggregates: agg)], units: .yards)
        XCTAssertTrue(csv.contains("mean_carry_yd"))
        XCTAssertTrue(csv.contains("mean_club_speed_mph"), "averages header missing mean_club_speed_mph")
        XCTAssertTrue(csv.contains("mean_smash"), "averages header missing mean_smash")
        XCTAssertTrue(csv.contains("7-Iron"))
        XCTAssertTrue(csv.contains("100"))
    }

    func testAveragesCSVClubSpeedAndSmashPresent() {
        let rec = ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil,
                             clubName: "Driver", carryMeters: 250, ballSpeedMS: 76.0,
                             launchAngleDeg: 10.5, spinRPM: 2700, spinSource: .modeled,
                             clubSpeedMS: 50.0, smashFactor: 1.52, confidence: .high,
                             isExcludedFromAverages: false)
        let agg = ClubAggregates.compute(from: [rec])!
        let csv = CSVExport.clubAverages([(clubName: "Driver", aggregates: agg)], units: .meters)
        let row = String(csv.split(separator: "\n")[1])
        XCTAssertTrue(row.contains("112"), "expected mean club speed ~112 mph")
        XCTAssertTrue(row.contains("1.52"), "expected mean smash 1.52")
    }

    func testAveragesCSVClubSpeedAndSmashEmptyWhenNil() {
        // No club speed or smash data → trailing fields empty
        let rec = ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil,
                             clubName: "7-Iron", carryMeters: 150, ballSpeedMS: 60.0,
                             launchAngleDeg: 16.0, spinRPM: 6500, spinSource: .modeled,
                             clubSpeedMS: nil, smashFactor: nil, confidence: .high,
                             isExcludedFromAverages: false)
        let agg = ClubAggregates.compute(from: [rec])!
        let csv = CSVExport.clubAverages([(clubName: "7-Iron", aggregates: agg)], units: .meters)
        let row = String(csv.split(separator: "\n")[1])
        XCTAssertTrue(row.hasSuffix(",,"), "expected empty mean_club_speed_mph and mean_smash fields, got: \(row)")
    }
}
