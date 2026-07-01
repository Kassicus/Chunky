// chunky/chunkyTests/BallisticsIntegratorTests.swift
import XCTest
@testable import chunky

final class BallisticsIntegratorTests: XCTestCase {
    // With no air (ρ=0) and no spin, the integrator must match the analytical
    // vacuum projectile range R = v0² sin(2θ) / g.
    func testVacuumRangeMatchesAnalytical() {
        let v0 = 20.0, thetaDeg = 45.0, g = 9.81
        let traj = Ballistics.integrate(
            launch: LaunchConditions(speedMS: v0, launchAngleDeg: thetaDeg, spinRPM: 0),
            airDensityKgM3: 0,
            dt: 0.001,
            gravity: g
        )
        let theta = thetaDeg * .pi / 180
        let expected = v0 * v0 * sin(2 * theta) / g   // 40.77 m
        XCTAssertEqual(traj.carryMeters, expected, accuracy: 0.05)
    }

    func testVacuumApexMatchesAnalytical() {
        let v0 = 20.0, thetaDeg = 45.0, g = 9.81
        let traj = Ballistics.integrate(
            launch: LaunchConditions(speedMS: v0, launchAngleDeg: thetaDeg, spinRPM: 0),
            airDensityKgM3: 0, dt: 0.001, gravity: g
        )
        let theta = thetaDeg * .pi / 180
        let vy = v0 * sin(theta)
        let expectedApex = vy * vy / (2 * g)          // 10.19 m
        XCTAssertEqual(traj.apexMeters, expectedApex, accuracy: 0.02)
    }

    func testDragShortensCarry() {
        let launch = LaunchConditions(speedMS: 60, launchAngleDeg: 15, spinRPM: 3000)
        let vacuum = Ballistics.integrate(launch: launch, airDensityKgM3: 0)
        let withAir = Ballistics.integrate(launch: launch, airDensityKgM3: 1.225)
        XCTAssertLessThan(withAir.carryMeters, vacuum.carryMeters)
    }

    func testBackspinAddsCarryVersusNoSpin() {
        // Backspin lift should extend carry relative to a spinless ball in air.
        let base = LaunchConditions(speedMS: 60, launchAngleDeg: 12, spinRPM: 0)
        let spun = LaunchConditions(speedMS: 60, launchAngleDeg: 12, spinRPM: 4000)
        let noSpin = Ballistics.integrate(launch: base, airDensityKgM3: 1.225)
        let withSpin = Ballistics.integrate(launch: spun, airDensityKgM3: 1.225)
        XCTAssertGreaterThan(withSpin.carryMeters, noSpin.carryMeters)
    }

    func testStepSizeConvergence() {
        // Halving dt should change carry by < 0.1 m (RK4 is 4th-order accurate).
        let launch = LaunchConditions(speedMS: 70, launchAngleDeg: 11, spinRPM: 2600)
        let coarse = Ballistics.integrate(launch: launch, airDensityKgM3: 1.225, dt: 0.001)
        let fine = Ballistics.integrate(launch: launch, airDensityKgM3: 1.225, dt: 0.0005)
        XCTAssertEqual(coarse.carryMeters, fine.carryMeters, accuracy: 0.1)
    }
}
