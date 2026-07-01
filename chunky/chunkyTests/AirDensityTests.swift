// chunky/chunkyTests/AirDensityTests.swift
import XCTest
@testable import chunky

final class AirDensityTests: XCTestCase {
    func testSeaLevelStandardIs1225() {
        // Spec default: sea level / 15 °C = 1.225 kg/m³
        let rho = AirDensity.density(temperatureC: 15, altitudeM: 0)
        XCTAssertEqual(rho, 1.225, accuracy: 0.001)
    }

    func testWarmerAirIsThinner() {
        let cool = AirDensity.density(temperatureC: 5, altitudeM: 0)
        let warm = AirDensity.density(temperatureC: 35, altitudeM: 0)
        XCTAssertLessThan(warm, cool)
    }

    func testAltitudeThinsAir() {
        let sea = AirDensity.density(temperatureC: 15, altitudeM: 0)
        let mile = AirDensity.density(temperatureC: 15, altitudeM: 1609)
        XCTAssertLessThan(mile, sea)
        // Denver-ish: roughly ~0.84x sea-level density at constant temperature.
        XCTAssertEqual(mile / sea, 0.84, accuracy: 0.03)
    }

    func testHumidAirIsSlightlyThinner() {
        let dry = AirDensity.density(temperatureC: 30, altitudeM: 0, relativeHumidity: 0)
        let humid = AirDensity.density(temperatureC: 30, altitudeM: 0, relativeHumidity: 1)
        XCTAssertLessThan(humid, dry)
    }
}
