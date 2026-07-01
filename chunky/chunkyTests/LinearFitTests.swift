// chunky/chunkyTests/LinearFitTests.swift
import XCTest
@testable import chunky

final class LinearFitTests: XCTestCase {
    func testExactLine() {
        // y = 3x + 2
        let x = [0.0, 1, 2, 3]
        let y = [2.0, 5, 8, 11]
        let r = LinearFit.fit(x: x, y: y)!
        XCTAssertEqual(r.slope, 3, accuracy: 1e-9)
        XCTAssertEqual(r.intercept, 2, accuracy: 1e-9)
        XCTAssertEqual(r.rmsResidual, 0, accuracy: 1e-9)
    }

    func testNoisyLineHasPositiveResidual() {
        let x = [0.0, 1, 2, 3]
        let y = [2.0, 5.2, 7.8, 11.1] // near y=3x+2 with noise
        let r = LinearFit.fit(x: x, y: y)!
        XCTAssertEqual(r.slope, 3, accuracy: 0.2)
        XCTAssertGreaterThan(r.rmsResidual, 0)
    }

    func testRejectsTooFewPoints() {
        XCTAssertNil(LinearFit.fit(x: [1], y: [1]))
    }

    func testRejectsMismatchedCounts() {
        XCTAssertNil(LinearFit.fit(x: [1, 2], y: [1]))
    }

    func testRejectsZeroXVariance() {
        XCTAssertNil(LinearFit.fit(x: [2, 2, 2], y: [1, 2, 3]))
    }
}
