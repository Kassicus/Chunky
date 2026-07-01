// chunky/chunky/Ballistics/Trajectory.swift
import Foundation

/// Output of the ballistics integrator.
///
/// Only `carryMeters` is validated against published reference carries (±3%, see
/// BallisticsReferenceCarryTests). `apexMeters` and `flightTimeS` are physically
/// plausible byproducts of the same integration but are NOT calibrated — the aero
/// model is carry-tuned with constant spin, so apex and hang-time run high. Do not
/// surface them as "measured" values without further validation.
nonisolated struct Trajectory {
    let carryMeters: Double
    let flightTimeS: Double
    let apexMeters: Double
    let points: [Vec3]
    /// True if the ball returned to launch height within the integration time cap;
    /// false if integration hit `maxTime` and `carryMeters` is a clamped fallback.
    let landed: Bool
}
