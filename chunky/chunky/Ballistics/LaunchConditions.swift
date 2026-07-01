// chunky/chunky/Ballistics/LaunchConditions.swift
import Foundation

/// Launch inputs to the ballistics integrator. Angles in degrees, speed in m/s,
/// spin in rpm. `azimuthDeg` is start direction (+ right); `spinAxisTiltDeg` is
/// 0 for pure backspin, positive tilts toward sidespin.
nonisolated struct LaunchConditions {
    var speedMS: Double
    var launchAngleDeg: Double
    var azimuthDeg: Double
    var spinRPM: Double
    var spinAxisTiltDeg: Double

    init(speedMS: Double,
         launchAngleDeg: Double,
         azimuthDeg: Double = 0,
         spinRPM: Double,
         spinAxisTiltDeg: Double = 0) {
        self.speedMS = speedMS
        self.launchAngleDeg = launchAngleDeg
        self.azimuthDeg = azimuthDeg
        self.spinRPM = spinRPM
        self.spinAxisTiltDeg = spinAxisTiltDeg
    }
}
