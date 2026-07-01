// chunky/chunkyTests/ModeledSpinTests.swift
import XCTest
@testable import chunky

final class ModeledSpinTests: XCTestCase {
    func testStandardLookup() {
        XCTAssertEqual(ModeledSpinTable.standard.spinRPM(forClub: "Driver"), 2600)
        XCTAssertEqual(ModeledSpinTable.standard.spinRPM(forClub: "7-Iron"), 6500)
        XCTAssertEqual(ModeledSpinTable.standard.spinRPM(forClub: "PW"), 9000)
    }

    func testUnknownClubReturnsNil() {
        XCTAssertNil(ModeledSpinTable.standard.spinRPM(forClub: "Sand Wedge"))
    }

    func testStandardIsPhysicallyOrdered() {
        // Backspin rises from driver to wedges.
        let driver = ModeledSpinTable.standard.spinRPM(forClub: "Driver")!
        let sevenIron = ModeledSpinTable.standard.spinRPM(forClub: "7-Iron")!
        let pw = ModeledSpinTable.standard.spinRPM(forClub: "PW")!
        XCTAssertLessThan(driver, sevenIron)
        XCTAssertLessThan(sevenIron, pw)
    }

    func testDecodeFromData() throws {
        let json = """
        [
          {"club": "Driver", "baseRPM": 2600},
          {"club": "7-Iron", "baseRPM": 6500}
        ]
        """.data(using: .utf8)!
        let table = try ModeledSpinTable(data: json)
        XCTAssertEqual(table.spinRPM(forClub: "Driver"), 2600)
        XCTAssertEqual(table.spinRPM(forClub: "7-Iron"), 6500)
        XCTAssertNil(table.spinRPM(forClub: "Driver-X"))
    }
}
