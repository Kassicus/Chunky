// chunky/chunkyTests/AeroTableTests.swift
import XCTest
@testable import chunky

final class AeroTableTests: XCTestCase {
    private let table = AeroTable(entries: [
        .init(spinRatio: 0.0, cd: 0.20, cl: 0.00),
        .init(spinRatio: 0.2, cd: 0.30, cl: 0.20),
    ])

    func testInterpolatesMidpoint() {
        let c = table.coefficients(spinRatio: 0.1)
        XCTAssertEqual(c.cd, 0.25, accuracy: 1e-12)
        XCTAssertEqual(c.cl, 0.10, accuracy: 1e-12)
    }

    func testClampsBelowRange() {
        let c = table.coefficients(spinRatio: -1)
        XCTAssertEqual(c.cd, 0.20, accuracy: 1e-12)
        XCTAssertEqual(c.cl, 0.00, accuracy: 1e-12)
    }

    func testClampsAboveRange() {
        let c = table.coefficients(spinRatio: 5)
        XCTAssertEqual(c.cd, 0.30, accuracy: 1e-12)
        XCTAssertEqual(c.cl, 0.20, accuracy: 1e-12)
    }

    func testUnsortedInputIsSorted() {
        let t = AeroTable(entries: [
            .init(spinRatio: 0.2, cd: 0.30, cl: 0.20),
            .init(spinRatio: 0.0, cd: 0.20, cl: 0.00),
        ])
        XCTAssertEqual(t.coefficients(spinRatio: 0.1).cd, 0.25, accuracy: 1e-12)
    }

    func testDecodeFromData() throws {
        let json = """
        [
          {"spinRatio": 0.0, "cd": 0.20, "cl": 0.00},
          {"spinRatio": 0.2, "cd": 0.30, "cl": 0.20}
        ]
        """.data(using: .utf8)!
        let decoded = try AeroTable(data: json)
        XCTAssertEqual(decoded.coefficients(spinRatio: 0.1).cl, 0.10, accuracy: 1e-12)
    }

    func testStandardTableIsMonotonicNonDecreasing() {
        let e = AeroTable.standard.entries
        XCTAssertGreaterThan(e.count, 1)
        for i in 1..<e.count {
            XCTAssertGreaterThan(e[i].spinRatio, e[i - 1].spinRatio)
            XCTAssertGreaterThanOrEqual(e[i].cd, e[i - 1].cd)
            XCTAssertGreaterThanOrEqual(e[i].cl, e[i - 1].cl)
        }
    }
}
