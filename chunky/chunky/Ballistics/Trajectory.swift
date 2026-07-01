// chunky/chunky/Ballistics/Trajectory.swift
import Foundation

/// Output of the ballistics integrator.
nonisolated struct Trajectory {
    let carryMeters: Double
    let flightTimeS: Double
    let apexMeters: Double
    let points: [Vec3]   // sampled positions from launch to landing (debug/plot)
}
