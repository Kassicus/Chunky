// chunky/chunky/CaptureKit/Core/AudioImpactDetector.swift
import Foundation

/// Detects club-ball impact onsets from a stream of short-time audio energies:
/// a sharp rise far above a running baseline, gated by a refractory period so a
/// single strike fires once. Pure/stateful value type — feed it mic-buffer
/// energies in order. (Wind/steady noise raises the baseline and is ignored.)
nonisolated struct AudioImpactDetector {
    var energyRatioThreshold: Double
    var absoluteFloor: Double
    var refractorySeconds: Double
    var baselineSmoothing: Double

    private var baseline: Double = 0
    private var initialized = false
    private var lastDetection: Double = -.infinity

    init(energyRatioThreshold: Double = 4.0,
         absoluteFloor: Double = 0.01,
         refractorySeconds: Double = 0.20,
         baselineSmoothing: Double = 0.1) {
        self.energyRatioThreshold = energyRatioThreshold
        self.absoluteFloor = absoluteFloor
        self.refractorySeconds = refractorySeconds
        self.baselineSmoothing = baselineSmoothing
    }

    mutating func process(energy: Double, time: Double) -> Bool {
        guard initialized else { baseline = energy; initialized = true; return false }
        let isSpike = energy > absoluteFloor && energy > baseline * energyRatioThreshold
        let outOfRefractory = time - lastDetection >= refractorySeconds
        var detected = false
        if isSpike && outOfRefractory {
            detected = true
            lastDetection = time
        }
        // Update the baseline only on non-spike frames so the transient doesn't
        // pull the baseline up and mask itself.
        if !isSpike {
            baseline = (1 - baselineSmoothing) * baseline + baselineSmoothing * energy
        }
        return detected
    }
}
