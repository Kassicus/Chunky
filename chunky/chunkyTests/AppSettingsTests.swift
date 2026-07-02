// chunky/chunkyTests/AppSettingsTests.swift
import XCTest
@testable import chunky

@MainActor
final class AppSettingsTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "AppSettingsTests-\(UUID().uuidString)")!
        return d
    }

    func testDefaults() {
        let s = AppSettings(defaults: makeDefaults())
        XCTAssertEqual(s.units, .yards)
        XCTAssertEqual(s.lens, .telephoto)
        XCTAssertFalse(s.debugOverlayEnabled)
        XCTAssertEqual(s.atmosphere.temperatureC, 15, accuracy: 1e-9)
    }

    func testPersistsAcrossInstances() {
        let d = makeDefaults()
        let a = AppSettings(defaults: d)
        a.units = .meters
        a.temperatureC = 25
        a.debugOverlayEnabled = true
        let b = AppSettings(defaults: d)
        XCTAssertEqual(b.units, .meters)
        XCTAssertEqual(b.temperatureC, 25, accuracy: 1e-9)
        XCTAssertTrue(b.debugOverlayEnabled)
        XCTAssertEqual(b.atmosphere.temperatureC, 25, accuracy: 1e-9)
    }

    func testCaptureLensMapping() {
        let s = AppSettings(defaults: makeDefaults())
        s.lens = .wide
        XCTAssertEqual(s.captureLens, .wide)
    }
}
