// chunky/chunky/Metrics/TrackPoint.swift
import Foundation

/// One tracked ball centroid in image-plane pixels at a given time.
nonisolated struct TrackPoint: Equatable {
    let timeSeconds: Double
    let pixel: Vec2
    let radiusPx: Double
    let confidence: Double

    init(timeSeconds: Double, pixel: Vec2, radiusPx: Double = 0, confidence: Double = 1) {
        self.timeSeconds = timeSeconds
        self.pixel = pixel
        self.radiusPx = radiusPx
        self.confidence = confidence
    }
}
