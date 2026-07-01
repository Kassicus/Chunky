// chunky/chunkyTests/StatsTests.swift
import XCTest
@testable import chunky

final class StatsTests: XCTestCase {
    func testMean() { XCTAssertEqual(Stats.mean([2, 4, 6])!, 4, accuracy: 1e-12) }
    func testMedianOdd() { XCTAssertEqual(Stats.median([5, 1, 3])!, 3, accuracy: 1e-12) }
    func testMedianEven() { XCTAssertEqual(Stats.median([1, 2, 3, 4])!, 2.5, accuracy: 1e-12) }
    func testSampleStdDev() {
        // sample stddev of [2,4,4,4,5,5,7,9] = 2.138...
        XCTAssertEqual(Stats.standardDeviation([2,4,4,4,5,5,7,9])!, 2.13809, accuracy: 1e-4)
    }
    func testStdDevNeedsTwo() {
        XCTAssertNil(Stats.standardDeviation([5]))
        XCTAssertNil(Stats.standardDeviation([]))
    }
    func testMinMax() {
        let mm = Stats.minMax([3, -1, 7])!
        XCTAssertEqual(mm.min, -1, accuracy: 1e-12)
        XCTAssertEqual(mm.max, 7, accuracy: 1e-12)
    }
    func testEmptyReturnsNil() {
        XCTAssertNil(Stats.mean([]))
        XCTAssertNil(Stats.median([]))
        XCTAssertNil(Stats.minMax([]))
    }
}
