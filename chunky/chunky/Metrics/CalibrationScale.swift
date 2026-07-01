// chunky/chunky/Metrics/CalibrationScale.swift
import Foundation

/// Metric scale and orientation of the flight plane, as produced by the
/// (future) Calibration module. `imageUpUnit` is the unit vector in image-pixel
/// space pointing to true (gravity) up — this is how device-attitude correction
/// enters Metrics. The horizontal image axis is its perpendicular.
nonisolated struct CalibrationScale {
    let pixelsPerMeter: Double
    let imageUpUnit: Vec2

    init(pixelsPerMeter: Double, imageUpUnit: Vec2) {
        self.pixelsPerMeter = pixelsPerMeter
        self.imageUpUnit = imageUpUnit.normalized
    }

    var imageHorizontalUnit: Vec2 { imageUpUnit.perpendicular }
}
