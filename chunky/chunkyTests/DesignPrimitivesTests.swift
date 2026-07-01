// chunky/chunkyTests/DesignPrimitivesTests.swift
import XCTest
@testable import chunky

final class DesignPrimitivesTests: XCTestCase {
    func testHexParsesSixDigits() {
        let c = HexColor.rgba("#DDF24A")!
        XCTAssertEqual(c.r, 0xDD / 255.0, accuracy: 1e-9)
        XCTAssertEqual(c.g, 0xF2 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(c.b, 0x4A / 255.0, accuracy: 1e-9)
        XCTAssertEqual(c.a, 1.0, accuracy: 1e-9)
    }

    func testHexAcceptsNoHashAndAlpha() {
        XCTAssertNotNil(HexColor.rgba("0C1E16"))
        XCTAssertEqual(HexColor.rgba("#000000FF")!.a, 1.0, accuracy: 1e-9)
    }

    func testHexRejectsMalformed() {
        XCTAssertNil(HexColor.rgba("#ZZZ"))
        XCTAssertNil(HexColor.rgba("12345"))
    }

    func testUnitsCarryConversionAndFormat() {
        XCTAssertEqual(Units.yards.carry(fromMeters: 91.44), 100, accuracy: 1e-9)
        XCTAssertEqual(Units.meters.carry(fromMeters: 150), 150, accuracy: 1e-9)
        XCTAssertEqual(Units.yards.formattedCarry(fromMeters: 91.44), "100 yd")
        XCTAssertEqual(Units.meters.formattedCarry(fromMeters: 149.6), "150 m")
    }

    func testConfidenceStyle() {
        XCTAssertEqual(ConfidenceStyle.label(.high), "High")
        XCTAssertEqual(ConfidenceStyle.label(.medium), "Med")
        XCTAssertEqual(ConfidenceStyle.label(.low), "Low")
        XCTAssertEqual(ConfidenceStyle.token(.high), "chalk")
        XCTAssertEqual(ConfidenceStyle.token(.medium), "amber")
        XCTAssertEqual(ConfidenceStyle.token(.low), "mist")
    }
}
