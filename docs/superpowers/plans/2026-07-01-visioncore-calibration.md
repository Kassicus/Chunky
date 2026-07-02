# VisionCore & Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn CaptureKit's impact-window frames into the tracked ball centroids Metrics consumes, and produce the metric scale/orientation Metrics needs — i.e. classical-CV ball detection + tracking (→ `[TrackPoint]`), a scale sanity check, and marker-based calibration (pixels-per-meter + gravity-corrected up-vector → `CalibrationScale` / `CalibrationProfile`) — plus fill CaptureKit's `departureProvider` motion seam.

**Architecture:** Two layers in the `chunky` app target, mirroring CaptureKit. **`VisionCore/Core/`** and **`Calibration/Core/`** are pure Swift (Foundation only, `nonisolated`): a `GrayImage` value type, a classical `BlobBallDetector` (threshold → connected components → circularity → sub-pixel centroid), a `BallTracker` (nearest-neighbor + constant-velocity → `[TrackPoint]`), a `ScaleSanity` check, and `CalibrationMath` (corner points + known size → px/m; gravity → image-up). All deterministic and unit-tested on synthetic images/geometry. **Device adapters** (`VisionCore/Device/`, `Calibration/Device/`) bridge `CVPixelBuffer`→`GrayImage`, Vision marker detection, and `CMMotion` attitude; the pixel conversion and Vision detection are smoke-testable in the Simulator (in-memory buffers/rendered images), while live attitude and the live camera flow are on-device.

**Tech Stack:** Swift 6, Xcode 26.5, iOS 26.5, Vision, CoreVideo, CoreMotion, Accelerate (optional), XCTest. No third-party dependencies (true ArUco/AprilTag would need OpenCV — out of scope; Vision rectangle/QR detection is the Apple-native marker path).

## Roadmap (Plan 5 of the per-phase sequence)
1. Foundation & Ballistics ✅ · 2. Metrics ✅ · 3. DataStore & Data UI ✅ · 4. CaptureKit ✅ · **5. VisionCore + Calibration ← this plan** (spec §6–7) · 6. Live UI end-to-end · 7. SpinCore (§8) · 8. Clubhead & smash (§3.4) · 9. Dual-camera & Core ML.

---

**Goal / Architecture / Tech Stack:** (see above)

## Global Constraints

- **Platform:** iOS 26.5, Swift 6, iPhone-only. Build/test simulator: **iPhone 17 Pro Max**.
- **Layering / dependency rule:** `VisionCore/Core/` and `Calibration/Core/` are pure — `import Foundation` only (no Vision/CoreVideo/CoreMotion/AVFoundation/SwiftUI/SwiftData); all `nonisolated`. Device folders (`VisionCore/Device/`, `Calibration/Device/`) may import Vision/CoreVideo/CoreMotion. `Ballistics`/`Metrics`/`DataStore`/`CaptureKit/Core` stay unchanged and framework-clean.
- **Reuse (same module):** use `Vec2` (Metrics), `Vec3` (Ballistics), `TrackPoint`/`CalibrationScale` (Metrics), `CalibrationProfile` (DataStore), and CaptureKit's `Timestamped`/`ImpactCapture` directly — no imports needed.
- **Coordinate convention (must be consistent):** `GrayImage` and all pixel coordinates are image space with **origin top-left, x→right, y→DOWN** (row index = y). Therefore physical "up" is the −y direction; `CalibrationScale.imageUpUnit` is produced in this same space (≈ `(0,−1)` with no camera roll). The `BallTracker` emits `TrackPoint.pixel` in this space, so calibration and tracks agree. Document this at the top of `GrayImage`.
- **Verification model:** `Core/` tasks are TDD (deterministic on synthetic images/geometry). Device adapters that run in the Simulator (CVPixelBuffer→GrayImage; Vision on a rendered image) get a Simulator smoke test where practical; live `CMMotion` attitude and the end-to-end camera flow are build-verified + on-device (Task 12 checklist). Never claim on-device behavior from a build.
- **Detector scope (spec §7):** ship the classical-CV `BlobBallDetector` behind a `BallDetector` protocol; leave a documented slot for a Core ML detector (Plan 9). Works on any bright, roughly-round ball.
- **Git hygiene:** each task stages ONLY its own files (explicit `git add <paths>`); never `git add -A`/`.`/`-a`.
- **Process:** TDD for Core; build/smoke-verify for Device; frequent commits; DRY; YAGNI.

## File Structure

```
chunky/chunky/VisionCore/
├─ Core/                         (pure, Foundation-only, TDD)
│  ├─ GrayImage.swift            // luma value type (origin TL, y-down)
│  ├─ BallCandidate.swift        // center(Vec2)/radiusPx/confidence
│  ├─ BallDetector.swift         // protocol + BlobBallDetector (classical CV)
│  ├─ ConnectedComponents.swift  // threshold → blobs (union-find/flood fill)
│  ├─ BallTracker.swift          // candidates → [TrackPoint] (NN + const-velocity)
│  ├─ ScaleSanity.swift          // ball-radius px → px/m cross-check
│  └─ MotionDeparture.swift      // ROI-activity series → departure time (pure)
└─ Device/                       (Vision/CoreVideo, build/smoke-verified)
   ├─ PixelBufferGray.swift      // CVPixelBuffer(420f luma) → GrayImage
   ├─ ROIDifference.swift        // per-frame ROI activity scalar from buffers
   └─ VisionPipeline.swift       // ImpactCapture → detect+track → [TrackPoint]; departureProvider

chunky/chunky/Calibration/
├─ Core/                         (pure, Foundation-only, TDD)
│  ├─ MarkerGeometry.swift       // corner ordering + side lengths
│  ├─ CalibrationMath.swift      // corners+knownSize → px/m; gravity → imageUpUnit; build CalibrationScale/Profile fields
└─ Device/                       (Vision/CoreMotion, build/smoke-verified)
   ├─ MarkerDetector.swift       // Vision rectangle/QR → 4 corner points
   └─ DeviceAttitude.swift       // CMMotionManager → gravity Vec3 (image frame)

chunky/chunkyTests/             // *Tests.swift per Core unit (+ in-sim device smoke)
```

---

### Task 1: GrayImage

**Files:**
- Create: `chunky/chunky/VisionCore/Core/GrayImage.swift`
- Test: `chunky/chunkyTests/GrayImageTests.swift`

**Interfaces:**
- Produces: `nonisolated struct GrayImage: Equatable, Sendable` — `let width: Int`, `let height: Int`, `let pixels: [UInt8]` (row-major, `count == width*height`); `init(width:height:pixels:)` (precondition on count); `func pixel(x: Int, y: Int) -> UInt8` (bounds-checked, 0 outside); `static func filled(width:height:value:) -> GrayImage`. Origin top-left, x→right, y→down.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/GrayImageTests.swift
import XCTest
@testable import chunky

final class GrayImageTests: XCTestCase {
    func testStorageAndAccess() {
        let img = GrayImage(width: 2, height: 2, pixels: [0, 10, 20, 30])
        XCTAssertEqual(img.pixel(x: 0, y: 0), 0)
        XCTAssertEqual(img.pixel(x: 1, y: 0), 10)
        XCTAssertEqual(img.pixel(x: 0, y: 1), 20)   // y=1 is the second row (y down)
        XCTAssertEqual(img.pixel(x: 1, y: 1), 30)
    }
    func testOutOfBoundsReturnsZero() {
        let img = GrayImage.filled(width: 2, height: 2, value: 99)
        XCTAssertEqual(img.pixel(x: -1, y: 0), 0)
        XCTAssertEqual(img.pixel(x: 0, y: 5), 0)
    }
    func testFilled() {
        XCTAssertEqual(GrayImage.filled(width: 3, height: 2, value: 7).pixels, Array(repeating: 7, count: 6))
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd /Users/kason/Documents/github/Chunky/chunky && xcodebuild -project chunky.xcodeproj -scheme chunky -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:chunkyTests/GrayImageTests 2>&1 | tail -15` — Expected: `cannot find 'GrayImage'`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/VisionCore/Core/GrayImage.swift
import Foundation

/// 8-bit luma image. Origin top-left, x→right, y→DOWN (row index = y), so
/// physical "up" is the −y direction (calibration produces imageUpUnit in this
/// same space). Pure value type — no capture/vision frameworks.
nonisolated struct GrayImage: Equatable, Sendable {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(width > 0 && height > 0, "GrayImage dimensions must be positive")
        precondition(pixels.count == width * height, "pixel count must equal width*height")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    func pixel(x: Int, y: Int) -> UInt8 {
        guard x >= 0, x < width, y >= 0, y < height else { return 0 }
        return pixels[y * width + x]
    }

    static func filled(width: Int, height: Int, value: UInt8) -> GrayImage {
        GrayImage(width: width, height: height, pixels: Array(repeating: value, count: width * height))
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/VisionCore/Core/GrayImage.swift chunky/chunkyTests/GrayImageTests.swift && \
git commit -m "feat(visioncore): add GrayImage luma value type

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Connected components

**Files:**
- Create: `chunky/chunky/VisionCore/Core/ConnectedComponents.swift`
- Test: `chunky/chunkyTests/ConnectedComponentsTests.swift`

**Interfaces:**
- Consumes: `GrayImage`.
- Produces: `nonisolated struct Blob: Equatable { let pixelCount: Int; let minX, minY, maxX, maxY: Int; let sumX, sumY: Double }` with computed `var boundingWidth`, `boundingHeight`, `centroid: Vec2` (intensity-agnostic geometric centroid = `sumX/pixelCount, sumY/pixelCount`); and `nonisolated enum ConnectedComponents { static func blobs(in: GrayImage, threshold: UInt8) -> [Blob] }` — 4-connected components of pixels with value `> threshold`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ConnectedComponentsTests.swift
import XCTest
@testable import chunky

final class ConnectedComponentsTests: XCTestCase {
    // Build an image with two separated bright squares on a dark field.
    private func twoSquares() -> GrayImage {
        var p = [UInt8](repeating: 0, count: 10 * 10)
        func set(_ x: Int, _ y: Int) { p[y*10+x] = 255 }
        for y in 1...2 { for x in 1...2 { set(x,y) } }   // 2x2 at (1..2,1..2)
        for y in 6...8 { for x in 6...8 { set(x,y) } }   // 3x3 at (6..8,6..8)
        return GrayImage(width: 10, height: 10, pixels: p)
    }

    func testFindsTwoBlobsWithCorrectSizes() {
        let blobs = ConnectedComponents.blobs(in: twoSquares(), threshold: 127)
            .sorted { $0.pixelCount < $1.pixelCount }
        XCTAssertEqual(blobs.count, 2)
        XCTAssertEqual(blobs[0].pixelCount, 4)   // 2x2
        XCTAssertEqual(blobs[1].pixelCount, 9)   // 3x3
    }
    func testCentroidOfSquare() {
        let blobs = ConnectedComponents.blobs(in: twoSquares(), threshold: 127)
        let big = blobs.max { $0.pixelCount < $1.pixelCount }!
        XCTAssertEqual(big.centroid.x, 7, accuracy: 1e-9)  // center of 6..8
        XCTAssertEqual(big.centroid.y, 7, accuracy: 1e-9)
    }
    func testEmptyWhenAllBelowThreshold() {
        XCTAssertTrue(ConnectedComponents.blobs(in: GrayImage.filled(width: 5, height: 5, value: 10), threshold: 127).isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/ConnectedComponentsTests ...` — Expected: `cannot find 'ConnectedComponents'`.

- [ ] **Step 3: Write implementation** — implement 4-connected labeling via an explicit stack flood-fill over thresholded pixels, accumulating `pixelCount`, bbox, and `sumX`/`sumY` per blob; `centroid = Vec2(sumX/count, sumY/count)`. Complete code:

```swift
// chunky/chunky/VisionCore/Core/ConnectedComponents.swift
import Foundation

nonisolated struct Blob: Equatable {
    let pixelCount: Int
    let minX: Int, minY: Int, maxX: Int, maxY: Int
    let sumX: Double, sumY: Double
    var boundingWidth: Int { maxX - minX + 1 }
    var boundingHeight: Int { maxY - minY + 1 }
    var centroid: Vec2 { Vec2(sumX / Double(pixelCount), sumY / Double(pixelCount)) }
}

nonisolated enum ConnectedComponents {
    static func blobs(in image: GrayImage, threshold: UInt8) -> [Blob] {
        let w = image.width, h = image.height
        var visited = [Bool](repeating: false, count: w * h)
        var result: [Blob] = []
        var stack: [(Int, Int)] = []
        for startY in 0..<h {
            for startX in 0..<w {
                let idx0 = startY * w + startX
                if visited[idx0] || image.pixels[idx0] <= threshold { continue }
                stack.removeAll(keepingCapacity: true)
                stack.append((startX, startY))
                visited[idx0] = true
                var count = 0, sumX = 0.0, sumY = 0.0
                var minX = startX, minY = startY, maxX = startX, maxY = startY
                while let (x, y) = stack.popLast() {
                    count += 1; sumX += Double(x); sumY += Double(y)
                    minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
                    for (dx, dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                        let nIdx = ny * w + nx
                        if !visited[nIdx] && image.pixels[nIdx] > threshold {
                            visited[nIdx] = true
                            stack.append((nx, ny))
                        }
                    }
                }
                result.append(Blob(pixelCount: count, minX: minX, minY: minY, maxX: maxX, maxY: maxY, sumX: sumX, sumY: sumY))
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/VisionCore/Core/ConnectedComponents.swift chunky/chunkyTests/ConnectedComponentsTests.swift && \
git commit -m "feat(visioncore): add connected-components blob labeling

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Ball candidate + classical detector

**Files:**
- Create: `chunky/chunky/VisionCore/Core/BallCandidate.swift`, `chunky/chunky/VisionCore/Core/BallDetector.swift`
- Test: `chunky/chunkyTests/BlobBallDetectorTests.swift`

**Interfaces:**
- Consumes: `GrayImage`, `Blob`/`ConnectedComponents`, `Vec2`.
- Produces:
  - `nonisolated struct BallCandidate: Equatable { let center: Vec2; let radiusPx: Double; let confidence: Double }`.
  - `nonisolated protocol BallDetector { func detect(in image: GrayImage) -> [BallCandidate] }`.
  - `nonisolated struct BlobBallDetector: BallDetector` with tunables `threshold: UInt8 = 180`, `minArea: Int = 6`, `minCircularity: Double = 0.6`; `detect` thresholds → blobs → filters by `minArea` and circularity (`circularity = pixelCount / (π · r²)` with `r = sqrt(pixelCount/π)`… use fill-ratio vs bounding box instead: `fill = pixelCount / (boundingWidth·boundingHeight)`, and aspect ≈ 1) — a round blob fills ~π/4≈0.785 of its bbox and is ~square; returns `BallCandidate(center: blob.centroid, radiusPx: sqrt(pixelCount/π), confidence: circularityScore)`, sorted by confidence descending.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/BlobBallDetectorTests.swift
import XCTest
@testable import chunky

final class BlobBallDetectorTests: XCTestCase {
    // Rasterize a filled bright disk of radius r at (cx,cy) on a dark field.
    private func disk(w: Int, h: Int, cx: Double, cy: Double, r: Double) -> GrayImage {
        var p = [UInt8](repeating: 0, count: w*h)
        for y in 0..<h { for x in 0..<w {
            let dx = Double(x)-cx, dy = Double(y)-cy
            if dx*dx+dy*dy <= r*r { p[y*w+x] = 255 }
        } }
        return GrayImage(width: w, height: h, pixels: p)
    }

    func testDetectsDiskCenterAndRadius() {
        let det = BlobBallDetector()
        let cands = det.detect(in: disk(w: 60, h: 60, cx: 30, cy: 25, r: 8))
        XCTAssertGreaterThanOrEqual(cands.count, 1)
        let best = cands.first!
        XCTAssertEqual(best.center.x, 30, accuracy: 1.0)
        XCTAssertEqual(best.center.y, 25, accuracy: 1.0)
        XCTAssertEqual(best.radiusPx, 8, accuracy: 1.5)   // area-based radius ≈ r
        XCTAssertGreaterThan(best.confidence, 0.6)
    }

    func testRejectsThinLine() {
        // A 1px-tall bright bar is not round → filtered out or very low confidence.
        var p = [UInt8](repeating: 0, count: 60*60)
        for x in 5..<55 { p[30*60 + x] = 255 }
        let cands = BlobBallDetector().detect(in: GrayImage(width: 60, height: 60, pixels: p))
        XCTAssertTrue(cands.allSatisfy { $0.confidence < 0.6 } || cands.isEmpty)
    }

    func testTwoBallsGiveTwoCandidates() {
        var img = disk(w: 80, h: 40, cx: 20, cy: 20, r: 6).pixels
        let img2 = disk(w: 80, h: 40, cx: 60, cy: 20, r: 6).pixels
        for i in 0..<img.count { img[i] = max(img[i], img2[i]) }
        let cands = BlobBallDetector().detect(in: GrayImage(width: 80, height: 40, pixels: img))
        XCTAssertEqual(cands.filter { $0.confidence >= 0.6 }.count, 2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/BlobBallDetectorTests ...` — Expected: `cannot find 'BallCandidate'`/`'BlobBallDetector'`.

- [ ] **Step 3: Write implementations** — `BallCandidate.swift` (the struct) and `BallDetector.swift` (protocol + `BlobBallDetector`). Circularity score: for a blob, `expectedFill = .pi/4` (a disk fills π/4 of its bbox); `fill = pixelCount / (boundingWidth*boundingHeight)`; `aspect = min(bw,bh)/max(bw,bh)`; `confidence = aspect * (1 - min(1, abs(fill - expectedFill)/expectedFill))`. Filter `pixelCount >= minArea && confidence >= minCircularity` for the returned high-confidence set, but return all passing `minArea` sorted by confidence (tests check `.first` and the `>= 0.6` subset). `radiusPx = sqrt(Double(pixelCount)/Double.pi)`.

- [ ] **Step 4: Run test to verify it passes** — Expected: `** TEST SUCCEEDED **`. (If the circularity formula needs tuning so a disk scores > 0.6 and a line < 0.6, adjust the score expression — the disk/line/two-ball tests are the gate; keep tunables within sane ranges.)
- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/VisionCore/Core/BallCandidate.swift chunky/chunky/VisionCore/Core/BallDetector.swift chunky/chunkyTests/BlobBallDetectorTests.swift && \
git commit -m "feat(visioncore): add BallDetector protocol and classical BlobBallDetector

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Ball tracker

**Files:**
- Create: `chunky/chunky/VisionCore/Core/BallTracker.swift`
- Test: `chunky/chunkyTests/BallTrackerTests.swift`

**Interfaces:**
- Consumes: `BallCandidate`, `Vec2`, `Timestamped` (CaptureKit), `TrackPoint` (Metrics).
- Produces: `nonisolated struct BallTracker` with tunables `gatePx: Double = 40`, `radiusToleranceRatio: Double = 0.6`; `func track(_ frames: [Timestamped<[BallCandidate]>]) -> [TrackPoint]` — seed with the highest-confidence candidate in the first non-empty frame; for each subsequent frame predict the next position with a constant-velocity model (from the last two accepted points; for the second point use nearest-to-last) and accept the candidate nearest the prediction within `gatePx` whose radius is within `radiusToleranceRatio` of the running median radius; skip frames with no gated candidate (occlusion / off-frame); output the accepted points as `[TrackPoint]` in time order (`TrackPoint(timeSeconds:pixel:radiusPx:confidence:)`).

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/BallTrackerTests.swift
import XCTest
@testable import chunky

final class BallTrackerTests: XCTestCase {
    private func frame(_ t: Double, _ cands: (Double, Double, Double)...) -> Timestamped<[BallCandidate]> {
        Timestamped(timeSeconds: t, value: cands.map { BallCandidate(center: Vec2($0.0, $0.1), radiusPx: 5, confidence: $0.2) })
    }

    func testFollowsConstantVelocityBall() {
        // Ball moves +10px/frame in x; each frame also has a spurious far candidate.
        let frames = (0..<6).map { i -> Timestamped<[BallCandidate]> in
            let x = 10.0 + Double(i) * 10
            return frame(Double(i) / 240.0, (x, 20, 0.9), (300, 300, 0.8))
        }
        let track = BallTracker().track(frames)
        XCTAssertEqual(track.count, 6)
        XCTAssertEqual(track.first!.pixel.x, 10, accuracy: 1e-6)
        XCTAssertEqual(track.last!.pixel.x, 60, accuracy: 1e-6)   // ignored the far spurious ones
        XCTAssertEqual(track.map(\.timeSeconds), (0..<6).map { Double($0)/240.0 })
    }

    func testSkipsOcclusionFrame() {
        var frames = [frame(0, (10,20,0.9)), frame(1.0/240, (20,20,0.9))]
        frames.append(Timestamped(timeSeconds: 2.0/240, value: []))       // occluded
        frames.append(frame(3.0/240, (40,20,0.9)))
        let track = BallTracker().track(frames)
        XCTAssertEqual(track.count, 3)   // the empty frame is skipped
        XCTAssertEqual(track.last!.pixel.x, 40, accuracy: 1e-6)
    }

    func testEmptyInputYieldsEmptyTrack() {
        XCTAssertTrue(BallTracker().track([]).isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/BallTrackerTests ...` — Expected: `cannot find 'BallTracker'`.

- [ ] **Step 3: Write implementation** — seed/predict/gate as specified; maintain last two accepted `(time, Vec2)` for velocity, a running median radius (or simple running radius), and emit `TrackPoint`s. Prediction: if ≥2 accepted points, `predicted = last + (last - prev)` (one-step constant velocity, frame-cadence-agnostic since candidates are per-frame); else `predicted = last`. Accept nearest candidate with `(center - predicted).magnitude <= gatePx` and radius within tolerance; else skip the frame.

- [ ] **Step 4: Run test to verify it passes** — Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/VisionCore/Core/BallTracker.swift chunky/chunkyTests/BallTrackerTests.swift && \
git commit -m "feat(visioncore): add nearest-neighbor constant-velocity ball tracker

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Scale sanity check

**Files:**
- Create: `chunky/chunky/VisionCore/Core/ScaleSanity.swift`
- Test: `chunky/chunkyTests/ScaleSanityTests.swift`

**Interfaces:**
- Produces: `nonisolated enum ScaleSanity` with `static func pixelsPerMeter(ballRadiusPx: Double, ballDiameterMeters: Double = 0.04267) -> Double` (= `2*radiusPx / diameter`) and `static func agrees(estimatedPxPerMeter: Double, calibratedPxPerMeter: Double, tolerance: Double = 0.25) -> Bool` (relative difference within tolerance).

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ScaleSanityTests.swift
import XCTest
@testable import chunky

final class ScaleSanityTests: XCTestCase {
    func testPixelsPerMeterFromRadius() {
        // radius 20px, diameter 0.04267m → 40px / 0.04267 ≈ 937.4 px/m
        XCTAssertEqual(ScaleSanity.pixelsPerMeter(ballRadiusPx: 20), 40.0 / 0.04267, accuracy: 1e-6)
    }
    func testAgreementWithinTolerance() {
        XCTAssertTrue(ScaleSanity.agrees(estimatedPxPerMeter: 1000, calibratedPxPerMeter: 1100, tolerance: 0.25))
        XCTAssertFalse(ScaleSanity.agrees(estimatedPxPerMeter: 1000, calibratedPxPerMeter: 2000, tolerance: 0.25))
    }
}
```

- [ ] **Step 2: Run to verify RED**; **Step 3: implement**:

```swift
// chunky/chunky/VisionCore/Core/ScaleSanity.swift
import Foundation

nonisolated enum ScaleSanity {
    static func pixelsPerMeter(ballRadiusPx: Double, ballDiameterMeters: Double = 0.04267) -> Double {
        (2 * ballRadiusPx) / ballDiameterMeters
    }
    static func agrees(estimatedPxPerMeter: Double, calibratedPxPerMeter: Double, tolerance: Double = 0.25) -> Bool {
        guard calibratedPxPerMeter > 0 else { return false }
        return abs(estimatedPxPerMeter - calibratedPxPerMeter) / calibratedPxPerMeter <= tolerance
    }
}
```

- [ ] **Step 4: GREEN**; **Step 5: commit** (`feat(visioncore): add ball-radius scale sanity check`, files `ScaleSanity.swift` + test, with the Co-Authored-By trailer).

---

### Task 6: Calibration math

**Files:**
- Create: `chunky/chunky/Calibration/Core/MarkerGeometry.swift`, `chunky/chunky/Calibration/Core/CalibrationMath.swift`
- Test: `chunky/chunkyTests/CalibrationMathTests.swift`

**Interfaces:**
- Consumes: `Vec2`, `Vec3` (Ballistics), `CalibrationScale` (Metrics).
- Produces:
  - `nonisolated enum MarkerGeometry { static func orderedCorners(_ corners: [Vec2]) -> [Vec2]? }` (returns 4 corners ordered TL,TR,BR,BL; nil unless exactly 4) and `static func averageSideLengthPx(_ orderedCorners: [Vec2]) -> Double`.
  - `nonisolated enum CalibrationMath`:
    - `static func pixelsPerMeter(markerCornersPx: [Vec2], markerSideMeters: Double) -> Double?` (order corners, avg side px / side m; nil if not 4 corners or side ≤ 0).
    - `static func imageUpUnit(imagePlaneGravity: Vec2) -> Vec2` — physical up is opposite gravity's in-image direction: `(-gravity).normalized`.
    - `static func calibrationScale(markerCornersPx: [Vec2], markerSideMeters: Double, imagePlaneGravity: Vec2) -> CalibrationScale?` — combine the two into a `CalibrationScale(pixelsPerMeter:imageUpUnit:)`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/CalibrationMathTests.swift
import XCTest
@testable import chunky

final class CalibrationMathTests: XCTestCase {
    // A 100px axis-aligned square (corners), representing a 0.3 m marker → 100/0.3 px/m.
    private let square = [Vec2(0,0), Vec2(100,0), Vec2(100,100), Vec2(0,100)]

    func testPixelsPerMeterFromMarker() {
        XCTAssertEqual(CalibrationMath.pixelsPerMeter(markerCornersPx: square, markerSideMeters: 0.3)!,
                       100.0 / 0.3, accuracy: 1e-6)
    }
    func testCornerOrderingIsRobustToInputOrder() {
        let shuffled = [Vec2(100,100), Vec2(0,0), Vec2(0,100), Vec2(100,0)]
        XCTAssertEqual(CalibrationMath.pixelsPerMeter(markerCornersPx: shuffled, markerSideMeters: 0.3)!,
                       100.0 / 0.3, accuracy: 1e-6)
    }
    func testImageUpFromGravity() {
        // Gravity points down in image (+y). Up = (0,-1).
        let up = CalibrationMath.imageUpUnit(imagePlaneGravity: Vec2(0, 1))
        XCTAssertEqual(up.x, 0, accuracy: 1e-9); XCTAssertEqual(up.y, -1, accuracy: 1e-9)
    }
    func testImageUpWithRoll() {
        let g = Vec2(0.6, 0.8)   // rolled gravity (unit)
        let up = CalibrationMath.imageUpUnit(imagePlaneGravity: g)
        XCTAssertEqual(up.x, -0.6, accuracy: 1e-9); XCTAssertEqual(up.y, -0.8, accuracy: 1e-9)
    }
    func testBuildsCalibrationScale() {
        let cal = CalibrationMath.calibrationScale(markerCornersPx: square, markerSideMeters: 0.3, imagePlaneGravity: Vec2(0,1))!
        XCTAssertEqual(cal.pixelsPerMeter, 100.0/0.3, accuracy: 1e-6)
        XCTAssertEqual(cal.imageUpUnit, Vec2(0,-1))
    }
    func testNilForWrongCornerCount() {
        XCTAssertNil(CalibrationMath.pixelsPerMeter(markerCornersPx: [Vec2(0,0), Vec2(1,1)], markerSideMeters: 0.3))
    }
}
```

- [ ] **Step 2: RED**; **Step 3: implement** `MarkerGeometry` (order 4 corners by angle around centroid → TL/TR/BR/BL; average of the 4 edge lengths) and `CalibrationMath` per the interfaces. `CalibrationScale.init` already normalizes `imageUpUnit` (Metrics), so passing `(-g).normalized` is consistent.

- [ ] **Step 4: GREEN**; **Step 5: commit** (`feat(calibration): add marker geometry and calibration math`, files `MarkerGeometry.swift`, `CalibrationMath.swift`, test, with trailer).

---

### Task 7: Motion departure detector (pure)

**Files:**
- Create: `chunky/chunky/VisionCore/Core/MotionDeparture.swift`
- Test: `chunky/chunkyTests/MotionDepartureTests.swift`

**Interfaces:**
- Produces: `nonisolated struct MotionDeparture` with `activityThreshold: Double` and `func departureTime(activity: [Timestamped<Double>]) -> Double?` — given per-frame ROI activity scalars (e.g. mean abs frame-difference in the tee-box ROI), return the timestamp of the first sample whose activity exceeds `activityThreshold` (the ball leaving the ROI); nil if none. This is what fills CaptureKit's `departureProvider` (device computes the activity scalars; this decides the departure time).

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/MotionDepartureTests.swift
import XCTest
@testable import chunky

final class MotionDepartureTests: XCTestCase {
    func testFirstAboveThreshold() {
        let a = [Timestamped(timeSeconds: 0.0, value: 0.01),
                 Timestamped(timeSeconds: 0.1, value: 0.02),
                 Timestamped(timeSeconds: 0.2, value: 0.9),   // ball departs
                 Timestamped(timeSeconds: 0.3, value: 0.8)]
        XCTAssertEqual(MotionDeparture(activityThreshold: 0.5).departureTime(activity: a)!, 0.2, accuracy: 1e-9)
    }
    func testNilWhenNoDeparture() {
        let a = [Timestamped(timeSeconds: 0.0, value: 0.01), Timestamped(timeSeconds: 0.1, value: 0.02)]
        XCTAssertNil(MotionDeparture(activityThreshold: 0.5).departureTime(activity: a))
    }
}
```

- [ ] **Step 2: RED**; **Step 3: implement** (`first { $0.value > activityThreshold }?.timeSeconds`, memberwise init); **Step 4: GREEN**; **Step 5: commit** (`feat(visioncore): add pure motion-departure detector`, 2 files, trailer).

---

### Task 8: Pixel buffer → GrayImage (device, Simulator-testable)

**Files:**
- Create: `chunky/chunky/VisionCore/Device/PixelBufferGray.swift`
- Test: `chunky/chunkyTests/PixelBufferGrayTests.swift`

**Interfaces:**
- Consumes: `GrayImage`, `CVPixelBuffer`.
- Produces: `enum PixelBufferGray { static func grayImage(from pixelBuffer: CVPixelBuffer) -> GrayImage? }` — reads the luma (plane 0) of a `420YpCbCr8BiPlanar*` buffer (or the R channel of BGRA as a fallback) into a `GrayImage`, handling row `bytesPerRow` padding; nil for unsupported formats.

- [ ] **Step 1: Write the failing test** — this RUNS in the Simulator (in-memory `CVPixelBuffer`, no camera):

```swift
// chunky/chunkyTests/PixelBufferGrayTests.swift
import XCTest
import CoreVideo
@testable import chunky

final class PixelBufferGrayTests: XCTestCase {
    func testConvertsLumaPlane() throws {
        // Create a 4x2 420f buffer and write a known luma pattern into plane 0.
        var pb: CVPixelBuffer?
        let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, 4, 2, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attrs, &pb)
        let buffer = try XCTUnwrap(pb)
        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)!.assumingMemoryBound(to: UInt8.self)
        let bpr = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        for y in 0..<2 { for x in 0..<4 { base[y*bpr + x] = UInt8(y*4 + x) } }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        let img = try XCTUnwrap(PixelBufferGray.grayImage(from: buffer))
        XCTAssertEqual(img.width, 4); XCTAssertEqual(img.height, 2)
        XCTAssertEqual(img.pixel(x: 3, y: 1), 7)   // y*4+x = 1*4+3
        XCTAssertEqual(img.pixel(x: 0, y: 0), 0)
    }
}
```

- [ ] **Step 2: RED** (`... -only-testing:chunkyTests/PixelBufferGrayTests ...` → `cannot find 'PixelBufferGray'`).
- [ ] **Step 3: Implement** — lock base address (read-only), detect pixel format; for 420 biplanar read plane 0 luma copying `width` bytes per row from a `bytesPerRow`-strided source into a contiguous `[UInt8]`; unlock; build `GrayImage`. Handle BGRA fallback (use one channel). Return nil for other formats.
- [ ] **Step 4: GREEN** (this test executes in the Simulator).
- [ ] **Step 5: Commit** (`feat(visioncore): add CVPixelBuffer→GrayImage luma conversion`, 2 files, trailer).

---

### Task 9: Marker detector (device Vision)

**Files:**
- Create: `chunky/chunky/Calibration/Device/MarkerDetector.swift`
- Test: none required (device Vision — build-verified; an optional Simulator smoke test on a rendered marker image may be added, but is not required to pass here).

**Interfaces:**
- Consumes: `Vec2`.
- Produces: `final class MarkerDetector` with `func detectCorners(in pixelBuffer: CVPixelBuffer) async -> [Vec2]?` — runs a Vision request to find the calibration target and returns its 4 corner points in PIXEL coordinates (top-left origin, y-down), or nil. Use `VNDetectBarcodesRequest` (a printed QR code of known size — its `payloadStringValue` can carry the side length, and its corner points give the quad) as the primary; a `VNDetectRectanglesRequest` fallback for a plain rectangular target. Convert Vision's normalized, bottom-left-origin points to top-left-origin pixels (`x*width`, `(1-y)*height`).

- [ ] **Step 1: Implement `MarkerDetector`** — complete, idiomatic Vision code: build the request, run it via `VNImageRequestHandler(cvPixelBuffer:orientation:options:)`, take the highest-confidence result, map its four corners (`topLeft`/`topRight`/`bottomRight`/`bottomLeft`, which are normalized bottom-left-origin) to top-left-origin pixel `Vec2`s using the buffer's width/height. Return nil on no detection. Document that true ArUco/AprilTag would require OpenCV (out of scope) and that this uses Vision's built-in QR/rectangle detection as the marker path.
- [ ] **Step 2: Build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Commit** (`feat(calibration): add Vision marker corner detector (device, build-verified)`, 1 file, trailer).

---

### Task 10: Device attitude (device CoreMotion)

**Files:**
- Create: `chunky/chunky/Calibration/Device/DeviceAttitude.swift`
- Test: none (live CoreMotion — build-verified; the projection math is tested in Task 6).

**Interfaces:**
- Consumes: `Vec2`, `Vec3` (Ballistics).
- Produces: `final class DeviceAttitude` with `func start()`, `func stop()`, and `var imagePlaneGravity: Vec2?` (and/or `var gravity: Vec3?`) — starts a `CMMotionManager` device-motion stream and exposes the current gravity vector projected into the image plane (x→right, y→down) for the active camera orientation, ready to feed `CalibrationMath.imageUpUnit`. Document the orientation mapping used.

- [ ] **Step 1: Implement `DeviceAttitude`** — `CMMotionManager` with `deviceMotionUpdateInterval` set, `startDeviceMotionUpdates`, read `deviceMotion.gravity` (x,y,z), map to the image-plane 2D gravity for the camera's landscape orientation (document the axis mapping), expose it. Provide `stop()`.
- [ ] **Step 2: Build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Commit** (`feat(calibration): add CoreMotion device-attitude provider (device, build-verified)`, 1 file, trailer).

---

### Task 11: Vision pipeline + ROI difference + departure wiring

**Files:**
- Create: `chunky/chunky/VisionCore/Device/ROIDifference.swift`, `chunky/chunky/VisionCore/Device/VisionPipeline.swift`
- Test: none required (device glue — build-verified; the detector/tracker/departure logic it drives is unit-tested).

**Interfaces:**
- Consumes: `GrayImage`, `PixelBufferGray`, `BlobBallDetector`, `BallTracker`, `MotionDeparture`, `Timestamped`, `ImpactCapture` (CaptureKit), `TrackPoint`.
- Produces:
  - `enum ROIDifference { static func activity(previous: GrayImage, current: GrayImage, roi: (x:Int,y:Int,w:Int,h:Int)) -> Double }` — mean absolute luma difference within the ROI (normalized 0…1). (Pure over GrayImages — could even live in Core; keep here with the device glue, or move to Core if you prefer testing it — implementer's call, but if in Core, add a test.)
  - `struct VisionPipeline` with `func track(_ capture: ImpactCapture, detector: BallDetector = BlobBallDetector()) -> [TrackPoint]` — converts each `ImpactCapture` frame's `CVPixelBuffer` to a `GrayImage` via `PixelBufferGray`, runs the detector per frame into `Timestamped<[BallCandidate]>`, and returns `BallTracker().track(...)`. And a helper to build a `departureProvider` closure (for `CaptureCoordinator`) from a rolling `ROIDifference` + `MotionDeparture`.
- [ ] **Step 1: Implement both**, wiring the tested Core pieces. Keep heavy per-frame work off the main actor where relevant. If `ROIDifference` is placed in `Core/`, add a small unit test for it (mean-abs-diff over two synthetic GrayImages).
- [ ] **Step 2: Build** → `** BUILD SUCCEEDED **` (and run the full unit suite to confirm nothing regressed).
- [ ] **Step 3: Commit** (`feat(visioncore): add ROI-difference and impact→track vision pipeline (device)`, files, trailer).

---

### Task 12: Green gate, purity guards & on-device notes

- [ ] **Step 1: Full unit suite** — `... test -only-testing:chunkyTests 2>&1 | tail -30` → `** TEST SUCCEEDED **` (all Core tests incl. the new VisionCore/Calibration + the PixelBufferGray Simulator test, plus Plans 1–4).
- [ ] **Step 2: Full build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Purity guards** — Run:

```bash
cd /Users/kason/Documents/github/Chunky && \
! grep -rEl "import (Vision|CoreVideo|CoreMotion|AVFoundation|AVFAudio|SwiftUI|SwiftData)" chunky/chunky/VisionCore/Core/ chunky/chunky/Calibration/Core/ && echo "OK: Vision/Calibration Core are device-free" && \
! grep -rEl "import (Vision|AVFoundation)" chunky/chunky/Ballistics/ chunky/chunky/Metrics/ chunky/chunky/DataStore/ chunky/chunky/CaptureKit/Core/ && echo "OK: prior core layers unchanged/clean"
```
Expected both OK lines.

- [ ] **Step 4: Write `docs/visioncore-ondevice-acceptance.md`** — the on-device checklist for the human (spec §6–7): calibrate against a printed known-size QR/rectangular target and confirm the reported pixels-per-meter is sane; confirm the up-vector tracks device roll; hit shots and confirm the ball is detected + tracked across the impact window (≥ the frame count Metrics needs) with the debug overlay; confirm the ball-radius scale sanity agrees with calibration; note the ArUco-via-OpenCV upgrade path and the Core-ML detector slot.
- [ ] **Step 5: Commit the checklist** (`docs(visioncore): add on-device calibration/tracking checklist`, trailer).

---

## Self-Review

**1. Spec coverage:**
- §7 classical ball detection (threshold, contour/circularity, sub-pixel centroid) → Tasks 2–3. ✅
- §7 detector behind a protocol with a Core ML upgrade slot → Task 3 (`BallDetector`) + noted. ✅
- §7 tracking (nearest-neighbor + constant-velocity, reject overlap/off-frame) → `[TrackPoint]` for Metrics → Task 4. ✅
- §7 scale sanity (ball radius px → independent px/m cross-check) → Task 5. ✅
- §6 calibration: pixels-per-meter at the ball plane from a known-size target + gravity (device-attitude) vertical → `CalibrationScale`/`CalibrationProfile` → Tasks 6, 9, 10. ✅ (Marker auto-detection via Vision QR/rectangle; true ArUco = OpenCV, out of scope, noted.)
- CVPixelBuffer → image for the detector → Task 8 (Simulator-tested). ✅
- Motion fallback / ball-departure (fills CaptureKit `departureProvider`, spec §5.4) → Tasks 7, 11. ✅
- End-to-end `ImpactCapture` → `[TrackPoint]` glue → Task 11. ✅
- Out of scope here (later plans): the Calibrate/Live SwiftUI screens + wiring tracks into Metrics→DataStore (Plan 6); Core ML detector (Plan 9); camera-intrinsics undistortion (optional, later).

**2. Placeholder scan:** Core tasks (1–8) carry complete code + full test bodies (Task 8 runs in the Simulator). Device tasks (9–11) specify concrete Vision/CoreMotion/CoreVideo implementations with exact APIs + structure, build-verified; no "TODO" stubs. `ROIDifference` placement (Core vs Device) is an implementer choice with a test required if in Core.

**3. Type consistency:** `GrayImage`, `Blob`/`ConnectedComponents.blobs(in:threshold:)`, `BallCandidate`, `BallDetector`/`BlobBallDetector.detect(in:)`, `BallTracker.track(_:)→[TrackPoint]`, `ScaleSanity.*`, `MarkerGeometry`/`CalibrationMath.*`, `MotionDeparture.departureTime(activity:)`, `PixelBufferGray.grayImage(from:)`, and the Task-11 glue reference each other consistently, and reuse `Vec2`/`Vec3`/`TrackPoint`/`CalibrationScale`/`CalibrationProfile`/`Timestamped`/`ImpactCapture` from prior plans. Core types `nonisolated`; device adapters may be classes. Coordinate convention (y-down; up = −y) is fixed in `GrayImage` and honored by the tracker + `CalibrationMath.imageUpUnit`.
