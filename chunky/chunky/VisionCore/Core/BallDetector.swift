// chunky/chunky/VisionCore/Core/BallDetector.swift
import Foundation

/// Abstract ball detector operating on a `GrayImage`.
nonisolated protocol BallDetector {
    func detect(in image: GrayImage) -> [BallCandidate]
}

/// Classical blob-based detector.
///
/// Pipeline:
/// 1. Threshold `GrayImage` at `threshold` → connected-component blobs.
/// 2. Filter blobs by `minArea` (pixel count).
/// 3. Score each blob's circularity:
///    - `aspect  = min(bw, bh) / max(bw, bh)`       — 1 for a square bbox
///    - `fill    = pixelCount / (bw × bh)`           — a disk ≈ π/4 ≈ 0.785
///    - `confidence = aspect × (1 − min(1, |fill − π/4| / (π/4)))`
/// 4. Return all blobs passing `minArea`, sorted by confidence descending.
///    Callers filter on `confidence >= minCircularity` for high-quality candidates.
nonisolated struct BlobBallDetector: BallDetector {
    var threshold: UInt8 = 180
    var minArea: Int = 6
    var minCircularity: Double = 0.6

    func detect(in image: GrayImage) -> [BallCandidate] {
        let blobs = ConnectedComponents.blobs(in: image, threshold: threshold)
        var candidates: [BallCandidate] = []
        let expectedFill = Double.pi / 4   // ≈ 0.785 — fraction of bbox a disk occupies

        for blob in blobs {
            guard blob.pixelCount >= minArea else { continue }

            let bw = Double(blob.boundingWidth)
            let bh = Double(blob.boundingHeight)
            let aspect = min(bw, bh) / max(bw, bh)
            let fill   = Double(blob.pixelCount) / (bw * bh)
            let confidence = aspect * (1.0 - min(1.0, abs(fill - expectedFill) / expectedFill))

            let radiusPx = (Double(blob.pixelCount) / Double.pi).squareRoot()
            candidates.append(BallCandidate(center: blob.centroid,
                                            radiusPx: radiusPx,
                                            confidence: confidence))
        }

        return candidates.sorted { $0.confidence > $1.confidence }
    }
}
