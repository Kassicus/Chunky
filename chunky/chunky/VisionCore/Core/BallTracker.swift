// chunky/chunky/VisionCore/Core/BallTracker.swift
import Foundation

/// Tracks a golf ball across frames using nearest-neighbor matching with a
/// constant-velocity prediction gate. Pure Foundation — no device frameworks.
nonisolated struct BallTracker {
    /// Maximum distance (pixels) from the predicted position to accept a candidate.
    var gatePx: Double = 40
    /// Maximum fractional deviation from the running-median radius to accept a candidate.
    var radiusToleranceRatio: Double = 0.6

    /// Associate `BallCandidate`s across a time-ordered frame sequence into one track.
    ///
    /// - Seeds with the highest-confidence candidate in the first non-empty frame.
    /// - For each subsequent frame, predicts the next position using a constant-velocity
    ///   model (last + (last − prev) when ≥2 points have been accepted; otherwise last).
    /// - Accepts the nearest candidate within `gatePx` whose radius is within
    ///   `radiusToleranceRatio` of the running-median accepted radius.
    /// - Skips frames with no gated candidate (occlusion / off-frame).
    /// - Returns accepted points as `[TrackPoint]` in time order.
    func track(_ frames: [Timestamped<[BallCandidate]>]) -> [TrackPoint] {
        guard !frames.isEmpty else { return [] }

        var result: [TrackPoint] = []

        // Last two accepted pixel positions for velocity prediction.
        var prevPos: Vec2? = nil
        var lastPos: Vec2? = nil

        // All accepted radii; used to compute the running median.
        var acceptedRadii: [Double] = []

        for frame in frames {
            let candidates = frame.value

            // --- Seeding phase: find the first non-empty frame ---
            if lastPos == nil {
                guard !candidates.isEmpty,
                      let best = candidates.max(by: { $0.confidence < $1.confidence })
                else { continue }

                lastPos = best.center
                acceptedRadii.append(best.radiusPx)
                result.append(TrackPoint(
                    timeSeconds: frame.timeSeconds,
                    pixel: best.center,
                    radiusPx: best.radiusPx,
                    confidence: best.confidence
                ))
                continue
            }

            // --- Skip genuinely empty frames (occlusion) ---
            guard !candidates.isEmpty else { continue }

            // --- Predict next position via constant-velocity model ---
            let predicted: Vec2
            if let prev = prevPos, let last = lastPos {
                predicted = last + (last - prev)   // one-step extrapolation
            } else {
                predicted = lastPos!               // only one accepted point so far
            }

            // Running median radius from all accepted points so far.
            let medianRadius = median(of: acceptedRadii)

            // --- Gate: find nearest candidate within distance and radius bounds ---
            var bestCandidate: BallCandidate? = nil
            var bestDist = Double.infinity

            for candidate in candidates {
                let dist = (candidate.center - predicted).magnitude
                guard dist <= gatePx else { continue }
                let radiusDiff = abs(candidate.radiusPx - medianRadius) / medianRadius
                guard radiusDiff <= radiusToleranceRatio else { continue }
                if dist < bestDist {
                    bestDist = dist
                    bestCandidate = candidate
                }
            }

            // If nothing passed the gate, skip this frame (occluded / off-frame).
            guard let accepted = bestCandidate else { continue }

            // Advance the sliding velocity window and record the accepted point.
            prevPos = lastPos
            lastPos = accepted.center
            acceptedRadii.append(accepted.radiusPx)
            result.append(TrackPoint(
                timeSeconds: frame.timeSeconds,
                pixel: accepted.center,
                radiusPx: accepted.radiusPx,
                confidence: accepted.confidence
            ))
        }

        return result
    }

    // MARK: - Helpers

    private func median(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
    }
}
