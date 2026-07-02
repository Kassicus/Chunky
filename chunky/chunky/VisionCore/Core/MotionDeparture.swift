// chunky/chunky/VisionCore/Core/MotionDeparture.swift
import Foundation

/// Detects the departure of the ball from the tee-box ROI using per-frame activity scalars.
///
/// Given a time-ordered sequence of ROI activity samples (e.g. mean absolute frame-difference
/// within the tee-box region), `departureTime` returns the timestamp of the first sample
/// whose activity exceeds `activityThreshold` — the moment the ball leaves the ROI.
nonisolated struct MotionDeparture {
    let activityThreshold: Double

    func departureTime(activity: [Timestamped<Double>]) -> Double? {
        activity.first { $0.value > activityThreshold }?.timeSeconds
    }
}
