// chunky/chunkyTests/BallisticsReferenceCarryTests.swift
import XCTest
@testable import chunky

final class BallisticsReferenceCarryTests: XCTestCase {
    private let seaLevel = AirDensity.density(temperatureC: 15, altitudeM: 0)  // 1.225

    private func carryYards(ballSpeedMPH: Double, launchDeg: Double, spinRPM: Double) -> Double {
        let launch = LaunchConditions(
            speedMS: Conversions.mphToMS(ballSpeedMPH),
            launchAngleDeg: launchDeg,
            spinRPM: spinRPM
        )
        let traj = Ballistics.integrate(launch: launch, airDensityKgM3: seaLevel)
        return Conversions.metersToYards(traj.carryMeters)
    }

    // Trackman tour-average driver: 167 mph ball, 10.9° launch, 2686 rpm ≈ 275 yd carry.
    func testDriverReferenceCarry() {
        let carry = carryYards(ballSpeedMPH: 167, launchDeg: 10.9, spinRPM: 2686)
        XCTAssertEqual(carry, 275, accuracy: 275 * 0.03)   // ±3% = ±8.25 yd
    }

    // Trackman tour-average 7-iron: 120 mph ball, 16.3° launch, 7000 rpm ≈ 172 yd carry.
    func testSevenIronReferenceCarry() {
        let carry = carryYards(ballSpeedMPH: 120, launchDeg: 16.3, spinRPM: 7000)
        XCTAssertEqual(carry, 172, accuracy: 172 * 0.03)   // ±3% = ±5.16 yd
    }

    // Altitude must increase carry (thinner air) — directional sanity, not a fixed target.
    func testAltitudeIncreasesCarry() {
        let launch = LaunchConditions(speedMS: Conversions.mphToMS(167),
                                      launchAngleDeg: 10.9, spinRPM: 2686)
        let sea = Ballistics.integrate(launch: launch, airDensityKgM3: seaLevel)
        let denver = Ballistics.integrate(
            launch: launch,
            airDensityKgM3: AirDensity.density(temperatureC: 15, altitudeM: 1609)
        )
        XCTAssertGreaterThan(denver.carryMeters, sea.carryMeters)
    }
}
