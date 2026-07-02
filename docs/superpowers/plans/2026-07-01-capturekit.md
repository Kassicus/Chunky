# CaptureKit Implementation Plan (Phase 0)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the CaptureKit capture pipeline (spec §5, Phase 0): configure the rear camera for a frozen, high-fps launch window, continuously ring-buffer frames, detect club-ball impact (audio primary + motion confirmation), and hand off / save the surrounding frame window — with all device-independent logic unit-tested and the AVFoundation layer isolated behind protocols for on-device verification.

**Architecture:** Two layers in the `chunky` app target. **`CaptureKit/Core/`** is pure Swift (Foundation only, `nonisolated`): a generic ring buffer, an audio impact-onset detector, capture-format selection, exposure math, impact-confirmation/debounce, and a `CaptureConfiguration` value type — all deterministic and unit-tested with no device. **`CaptureKit/Device/`** imports AVFoundation/AVFAudio and wires the pure core into an `AVCaptureSession` (telephoto @ 240fps, custom short-shutter exposure, `AVCaptureVideoDataOutput` → ring buffer), an `AVAudioEngine` mic tap (→ energy → detector), an `AVAssetWriter` clip writer, and a `CaptureCoordinator` that orchestrates them behind protocols. The device layer is **build-verified only**; its behavior is validated on a real iPhone (Phase-0 acceptance).

**Tech Stack:** Swift 6, Xcode 26.5, iOS 26.5, AVFoundation, AVFAudio, CoreMedia, CoreVideo, XCTest. No third-party dependencies.

## Roadmap (Plan 4 of the per-phase sequence)
1. Foundation & Ballistics ✅ · 2. Metrics ✅ · 3. DataStore & Data UI ✅ · **4. CaptureKit ← this plan** (spec §5, Phase 0) · 5. VisionCore + Calibration (§6–7) · 6. Live UI end-to-end · 7. SpinCore (§8) · 8. Clubhead & smash (§3.4) · 9. Dual-camera & Core ML.

---

**Goal / Architecture / Tech Stack:** (see above)

## Global Constraints

- **Platform:** iOS 26.5, Swift 6, iPhone-only. Build simulator: **iPhone 17 Pro Max**. Camera/mic `Info.plist` usage strings already exist (Plan 1).
- **Layering / dependency rule (spec §4):** `CaptureKit/Core/` must be pure — `import Foundation` only, NO AVFoundation/AVFAudio/CoreMedia/CoreVideo/Vision/SwiftUI/SwiftData. `CaptureKit/Device/` may import AVFoundation/AVFAudio/CoreMedia/CoreVideo. `Ballistics`, `Metrics`, `DataStore` remain unchanged and stay free of capture frameworks.
- **Verification model:** `Core/` tasks are TDD (red→green, real assertions), fully verifiable here. `Device/` tasks are **build-verified only** (`xcodebuild build`); their real behavior is validated on a physical iPhone via the Phase-0 acceptance checklist (Task 12) — this sandbox has no camera and the simulator cannot exercise capture. Never claim device behavior is verified from a build.
- **Concurrency:** `Core/` value types/functions are `nonisolated`; those crossing into capture callbacks (config, descriptors, detectors, `RingBuffer` of value payloads) are `Sendable` (their members are Sendable). The `AVCaptureVideoDataOutput` delegate runs on a dedicated serial `DispatchQueue`; the audio tap on the engine's queue. `CaptureCoordinator` is `@MainActor` for arm/disarm control and publishes impact events back to the main actor.
- **Units:** seconds for time, Hz/fps for rates, ISO/shutter for exposure. Frame timestamps are seconds (from `CMTime`) as `Double`.
- **Capture targets (spec §5):** rear `.builtInTelephotoCamera` preferred, `.builtInWideAngleCamera` fallback; format supporting **240 fps @ 1080p**; custom exposure **duration ≈ 1/2000 s** with ISO raised to compensate (clamp to `activeFormat.maxISO`, warn if insufficient); locked white balance + focus during a shot; `AVCaptureVideoDataOutput` with `alwaysDiscardsLateVideoFrames = true` on a serial queue; ring buffer ~0.5 s (~120 frames @ 240 fps); audio primary trigger with a motion fallback + debounce; snapshot window `[t_impact − 40 ms, t_impact + 120 ms]`.
- **Git hygiene:** each task stages ONLY its own files (explicit `git add <paths>`); never `git add -A`/`.`/`-a`.
- **Process:** TDD for `Core/`; build-verify for `Device/`; frequent commits; DRY; YAGNI.

## File Structure

```
chunky/chunky/CaptureKit/
├─ Core/                        (pure, Foundation-only, TDD)
│  ├─ RingBuffer.swift          // generic fixed-capacity ring buffer
│  ├─ Timestamped.swift         // Timestamped<Value> + impact-window extraction
│  ├─ AudioImpactDetector.swift // onset detection (energy flux + refractory)
│  ├─ CaptureFormat.swift       // CaptureFormatDescriptor + CaptureFormatSelector
│  ├─ ExposureCalculator.swift  // ISO-for-target-shutter + needsMoreLight
│  ├─ ImpactConfirmation.swift  // audio+motion debounce/arbitration
│  └─ CaptureConfiguration.swift// capture config value type + defaults
└─ Device/                      (AVFoundation, build-verified only)
   ├─ CaptureProtocols.swift    // seams: FrameReceiver, ImpactSignal, etc.
   ├─ CameraCaptureController.swift // AVCaptureSession/device/format/exposure/output
   ├─ AudioImpactMonitor.swift  // AVAudioEngine mic tap → energy → detector
   ├─ ImpactClipWriter.swift    // AVAssetWriter: frame window → .mov on disk
   └─ CaptureCoordinator.swift  // orchestration + impact events (@MainActor)

chunky/chunkyTests/            // *Tests.swift per Core unit
```

---

### Task 1: Generic ring buffer

**Files:**
- Create: `chunky/chunky/CaptureKit/Core/RingBuffer.swift`
- Test: `chunky/chunkyTests/RingBufferTests.swift`

**Interfaces:**
- Produces: `nonisolated struct RingBuffer<Element>` with `init(capacity: Int)` (capacity > 0), `mutating func append(_:)` (overwrites the oldest when full), `var elements: [Element]` (oldest→newest), `var count: Int`, `var isFull: Bool`, `mutating func removeAll()`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/RingBufferTests.swift
import XCTest
@testable import chunky

final class RingBufferTests: XCTestCase {
    func testAppendsUntilFull() {
        var b = RingBuffer<Int>(capacity: 3)
        b.append(1); b.append(2)
        XCTAssertEqual(b.elements, [1, 2])
        XCTAssertFalse(b.isFull)
        b.append(3)
        XCTAssertTrue(b.isFull)
        XCTAssertEqual(b.elements, [1, 2, 3])
    }

    func testOverwritesOldestWhenFull() {
        var b = RingBuffer<Int>(capacity: 3)
        [1, 2, 3, 4, 5].forEach { b.append($0) }
        XCTAssertEqual(b.elements, [3, 4, 5]) // oldest two evicted
        XCTAssertEqual(b.count, 3)
    }

    func testRemoveAll() {
        var b = RingBuffer<Int>(capacity: 2)
        b.append(1); b.removeAll()
        XCTAssertEqual(b.count, 0)
        XCTAssertEqual(b.elements, [])
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `cd /Users/kason/Documents/github/Chunky/chunky && xcodebuild -project chunky.xcodeproj -scheme chunky -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:chunkyTests/RingBufferTests 2>&1 | tail -15` — Expected: `cannot find 'RingBuffer' in scope`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/CaptureKit/Core/RingBuffer.swift
import Foundation

/// Fixed-capacity buffer that overwrites the oldest element when full.
/// Pure value type — no capture frameworks. Holds the last N frames/samples.
nonisolated struct RingBuffer<Element> {
    private var storage: [Element] = []
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    mutating func append(_ element: Element) {
        if storage.count == capacity { storage.removeFirst() }
        storage.append(element)
    }

    var elements: [Element] { storage }   // oldest → newest
    var count: Int { storage.count }
    var isFull: Bool { storage.count == capacity }

    mutating func removeAll() { storage.removeAll(keepingCapacity: true) }
}

extension RingBuffer: Sendable where Element: Sendable {}
```

- [ ] **Step 4: Run test to verify it passes** — same command — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Core/RingBuffer.swift chunky/chunkyTests/RingBufferTests.swift && \
git commit -m "feat(capturekit): add generic ring buffer

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Timestamped frames + impact-window extraction

**Files:**
- Create: `chunky/chunky/CaptureKit/Core/Timestamped.swift`
- Test: `chunky/chunkyTests/ImpactWindowTests.swift`

**Interfaces:**
- Produces:
  - `nonisolated struct Timestamped<Value> { let timeSeconds: Double; let value: Value }` (`Sendable where Value: Sendable`).
  - `nonisolated enum ImpactWindow` with `static func slice<T>(_ frames: [Timestamped<T>], impactTime: Double, preRoll: Double = 0.040, postRoll: Double = 0.120) -> [Timestamped<T>]` — the frames whose timestamps lie in `[impactTime − preRoll, impactTime + postRoll]`, order preserved.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ImpactWindowTests.swift
import XCTest
@testable import chunky

final class ImpactWindowTests: XCTestCase {
    private func frames(count: Int, fps: Double) -> [Timestamped<Int>] {
        (0..<count).map { Timestamped(timeSeconds: Double($0) / fps, value: $0) }
    }

    func testSliceAroundImpact() {
        let fs = frames(count: 240, fps: 240) // 1 second at 240 fps, t = 0…0.9958
        let win = ImpactWindow.slice(fs, impactTime: 0.5) // [0.46, 0.62]
        XCTAssertEqual(win.first!.timeSeconds, 0.46, accuracy: 1.0 / 240 + 1e-9)
        XCTAssertEqual(win.last!.timeSeconds, 0.62, accuracy: 1.0 / 240 + 1e-9)
        // ~0.160 s * 240 fps ≈ 38–39 frames
        XCTAssertGreaterThanOrEqual(win.count, 37)
        XCTAssertLessThanOrEqual(win.count, 40)
    }

    func testCustomRollBounds() {
        let fs = frames(count: 100, fps: 100)
        let win = ImpactWindow.slice(fs, impactTime: 0.50, preRoll: 0.10, postRoll: 0.10)
        for f in win { XCTAssertTrue(f.timeSeconds >= 0.40 - 1e-9 && f.timeSeconds <= 0.60 + 1e-9) }
        XCTAssertTrue(win.contains { $0.value == 50 })
    }

    func testEmptyWhenNoFramesInRange() {
        let fs = frames(count: 10, fps: 10) // 0…0.9
        XCTAssertTrue(ImpactWindow.slice(fs, impactTime: 5.0).isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/ImpactWindowTests ...` — Expected: `cannot find 'Timestamped'`/`'ImpactWindow'`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/CaptureKit/Core/Timestamped.swift
import Foundation

/// A value stamped with a capture time in seconds.
nonisolated struct Timestamped<Value> {
    let timeSeconds: Double
    let value: Value
}

extension Timestamped: Sendable where Value: Sendable {}
extension Timestamped: Equatable where Value: Equatable {}

/// Extracts the impact frame window from a time-ordered buffer.
nonisolated enum ImpactWindow {
    static func slice<T>(_ frames: [Timestamped<T>],
                         impactTime: Double,
                         preRoll: Double = 0.040,
                         postRoll: Double = 0.120) -> [Timestamped<T>] {
        let lower = impactTime - preRoll
        let upper = impactTime + postRoll
        return frames.filter { $0.timeSeconds >= lower && $0.timeSeconds <= upper }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Core/Timestamped.swift chunky/chunkyTests/ImpactWindowTests.swift && \
git commit -m "feat(capturekit): add timestamped frames and impact-window slice

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Audio impact-onset detector

**Files:**
- Create: `chunky/chunky/CaptureKit/Core/AudioImpactDetector.swift`
- Test: `chunky/chunkyTests/AudioImpactDetectorTests.swift`

**Interfaces:**
- Produces: `nonisolated struct AudioImpactDetector` with tunable params `energyRatioThreshold` (default 4.0), `absoluteFloor` (default 0.01), `refractorySeconds` (default 0.20), `baselineSmoothing` (default 0.1), and `mutating func process(energy: Double, time: Double) -> Bool` — returns true on the frame where a sharp broadband transient (energy far above a running baseline, out of refractory) is detected. Detects onsets of club-ball contact from a stream of short-time energies.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/AudioImpactDetectorTests.swift
import XCTest
@testable import chunky

final class AudioImpactDetectorTests: XCTestCase {
    func testDetectsSpikeAfterQuietBaseline() {
        var d = AudioImpactDetector()
        var detections: [Double] = []
        // 0.5 s of quiet (energy ~0.02) at 1 kHz frames, then a spike at t=0.5
        var t = 0.0
        for _ in 0..<500 { if d.process(energy: 0.02, time: t) { detections.append(t) }; t += 0.001 }
        _ = d.process(energy: 0.02, time: t) // keep baseline low
        let spikeTime = t
        if d.process(energy: 1.0, time: spikeTime) { detections.append(spikeTime) }
        XCTAssertEqual(detections.count, 1)
        XCTAssertEqual(detections.first!, spikeTime, accuracy: 1e-9)
    }

    func testRefractorySuppressesDoubleFire() {
        var d = AudioImpactDetector(refractorySeconds: 0.20)
        _ = d.process(energy: 0.02, time: 0.0)      // seed baseline
        for _ in 0..<50 { _ = d.process(energy: 0.02, time: 0.0) }
        let first = d.process(energy: 1.0, time: 1.000)   // detect
        let second = d.process(energy: 1.0, time: 1.100)  // within 0.2 s → suppressed
        let third = d.process(energy: 1.0, time: 1.300)   // after refractory → detect
        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertTrue(third)
    }

    func testIgnoresBelowFloorAndBelowRatio() {
        var d = AudioImpactDetector(energyRatioThreshold: 4.0, absoluteFloor: 0.01)
        _ = d.process(energy: 0.02, time: 0.0)
        // 3× baseline but still tiny / not 4× → no detect
        XCTAssertFalse(d.process(energy: 0.05, time: 0.1))
        // below absolute floor even if ratio high vs a near-zero baseline
        var d2 = AudioImpactDetector(absoluteFloor: 0.5)
        _ = d2.process(energy: 0.001, time: 0.0)
        XCTAssertFalse(d2.process(energy: 0.004, time: 0.1))
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/AudioImpactDetectorTests ...` — Expected: `cannot find 'AudioImpactDetector'`.

- [ ] **Step 3: Write implementation**

```swift
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
```

- [ ] **Step 4: Run test to verify it passes** — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Core/AudioImpactDetector.swift chunky/chunkyTests/AudioImpactDetectorTests.swift && \
git commit -m "feat(capturekit): add audio impact-onset detector

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Capture format selection

**Files:**
- Create: `chunky/chunky/CaptureKit/Core/CaptureFormat.swift`
- Test: `chunky/chunkyTests/CaptureFormatTests.swift`

**Interfaces:**
- Produces:
  - `nonisolated struct CaptureFormatDescriptor: Equatable, Sendable { let width: Int; let height: Int; let maxFrameRate: Double }`.
  - `nonisolated enum CaptureFormatSelector` with `static func best(from: [CaptureFormatDescriptor], targetFPS: Double = 240, targetHeight: Int = 1080) -> CaptureFormatDescriptor?` — prefers a format at `targetHeight` supporting ≥ `targetFPS` (highest fps among those); else the highest-fps format at `targetHeight`; else the highest-fps format overall; nil for empty input.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/CaptureFormatTests.swift
import XCTest
@testable import chunky

final class CaptureFormatTests: XCTestCase {
    private let formats = [
        CaptureFormatDescriptor(width: 1920, height: 1080, maxFrameRate: 60),
        CaptureFormatDescriptor(width: 1920, height: 1080, maxFrameRate: 240),
        CaptureFormatDescriptor(width: 3840, height: 2160, maxFrameRate: 120),
        CaptureFormatDescriptor(width: 1280, height: 720, maxFrameRate: 240),
    ]

    func testPrefers240At1080() {
        let best = CaptureFormatSelector.best(from: formats)!
        XCTAssertEqual(best, CaptureFormatDescriptor(width: 1920, height: 1080, maxFrameRate: 240))
    }

    func testFallsBackToHighestFpsAt1080WhenNoTargetFps() {
        let f = [CaptureFormatDescriptor(width: 1920, height: 1080, maxFrameRate: 120),
                 CaptureFormatDescriptor(width: 1920, height: 1080, maxFrameRate: 60)]
        XCTAssertEqual(CaptureFormatSelector.best(from: f)!.maxFrameRate, 120)
    }

    func testFallsBackToHighestFpsOverallWhenNo1080() {
        let f = [CaptureFormatDescriptor(width: 1280, height: 720, maxFrameRate: 240),
                 CaptureFormatDescriptor(width: 3840, height: 2160, maxFrameRate: 120)]
        XCTAssertEqual(CaptureFormatSelector.best(from: f)!.height, 720)
    }

    func testNilOnEmpty() {
        XCTAssertNil(CaptureFormatSelector.best(from: []))
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/CaptureFormatTests ...` — Expected: `cannot find 'CaptureFormatDescriptor'`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/CaptureKit/Core/CaptureFormat.swift
import Foundation

/// A device-agnostic description of a capture format, so selection logic is
/// testable without AVFoundation. The device layer maps AVCaptureDevice.Format
/// to this and back.
nonisolated struct CaptureFormatDescriptor: Equatable, Sendable {
    let width: Int
    let height: Int
    let maxFrameRate: Double
}

nonisolated enum CaptureFormatSelector {
    static func best(from formats: [CaptureFormatDescriptor],
                     targetFPS: Double = 240,
                     targetHeight: Int = 1080) -> CaptureFormatDescriptor? {
        let byFps: (CaptureFormatDescriptor, CaptureFormatDescriptor) -> Bool = { $0.maxFrameRate < $1.maxFrameRate }
        let atTargetFps = formats.filter { $0.height == targetHeight && $0.maxFrameRate >= targetFPS }
        if let best = atTargetFps.max(by: byFps) { return best }
        let atHeight = formats.filter { $0.height == targetHeight }
        if let best = atHeight.max(by: byFps) { return best }
        return formats.max(by: byFps)
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Core/CaptureFormat.swift chunky/chunkyTests/CaptureFormatTests.swift && \
git commit -m "feat(capturekit): add capture-format descriptor and selector

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Exposure calculator

**Files:**
- Create: `chunky/chunky/CaptureKit/Core/ExposureCalculator.swift`
- Test: `chunky/chunkyTests/ExposureCalculatorTests.swift`

**Interfaces:**
- Produces:
  - `nonisolated struct ExposureRecommendation: Equatable, Sendable { let iso: Double; let needsMoreLight: Bool }`.
  - `nonisolated enum ExposureCalculator` with `static func recommend(autoISO: Double, autoDuration: Double, targetDuration: Double, minISO: Double, maxISO: Double) -> ExposureRecommendation` — to freeze motion at `targetDuration` while preserving the auto-metered exposure, scale ISO by `autoDuration / targetDuration`, clamp to `[minISO, maxISO]`, and set `needsMoreLight` when the ideal ISO exceeds `maxISO` (scene too dark for the short shutter).

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ExposureCalculatorTests.swift
import XCTest
@testable import chunky

final class ExposureCalculatorTests: XCTestCase {
    func testScalesISOToPreserveExposure() {
        // auto: ISO 100 at 1/120 s. Target 1/2000 s is 16.67× shorter → ISO ~1667.
        let r = ExposureCalculator.recommend(autoISO: 100, autoDuration: 1.0/120,
                                             targetDuration: 1.0/2000, minISO: 20, maxISO: 3000)
        XCTAssertEqual(r.iso, 100 * (1.0/120) / (1.0/2000), accuracy: 1e-6) // ≈ 1666.7
        XCTAssertFalse(r.needsMoreLight)
    }

    func testClampsAndWarnsWhenTooDark() {
        let r = ExposureCalculator.recommend(autoISO: 400, autoDuration: 1.0/60,
                                             targetDuration: 1.0/2000, minISO: 20, maxISO: 3000)
        // ideal = 400 * (1/60)/(1/2000) = 400 * 33.33 = 13333 > 3000 → clamp + warn
        XCTAssertEqual(r.iso, 3000, accuracy: 1e-6)
        XCTAssertTrue(r.needsMoreLight)
    }

    func testClampsToMinISO() {
        let r = ExposureCalculator.recommend(autoISO: 20, autoDuration: 1.0/2200,
                                             targetDuration: 1.0/2000, minISO: 25, maxISO: 3000)
        // ideal < minISO → clamp up to minISO, not "more light"
        XCTAssertEqual(r.iso, 25, accuracy: 1e-6)
        XCTAssertFalse(r.needsMoreLight)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/ExposureCalculatorTests ...` — Expected: `cannot find 'ExposureCalculator'`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/CaptureKit/Core/ExposureCalculator.swift
import Foundation

nonisolated struct ExposureRecommendation: Equatable, Sendable {
    let iso: Double
    let needsMoreLight: Bool
}

/// Computes the ISO needed to keep the auto-metered exposure while forcing a
/// short shutter to freeze the ball (spec §5.2). Exposure ∝ duration × ISO, so
/// shortening the duration requires raising ISO by the inverse ratio.
nonisolated enum ExposureCalculator {
    static func recommend(autoISO: Double, autoDuration: Double, targetDuration: Double,
                          minISO: Double, maxISO: Double) -> ExposureRecommendation {
        let ideal = autoISO * (autoDuration / targetDuration)
        let clamped = min(max(ideal, minISO), maxISO)
        return ExposureRecommendation(iso: clamped, needsMoreLight: ideal > maxISO)
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Core/ExposureCalculator.swift chunky/chunkyTests/ExposureCalculatorTests.swift && \
git commit -m "feat(capturekit): add short-shutter exposure calculator

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Impact confirmation / debounce

**Files:**
- Create: `chunky/chunky/CaptureKit/Core/ImpactConfirmation.swift`
- Test: `chunky/chunkyTests/ImpactConfirmationTests.swift`

**Interfaces:**
- Produces: `nonisolated enum ImpactConfirmation` with `static func isConfirmed(audioTransientTime: Double, ballDepartureTime: Double?, window: Double = 0.080) -> Bool` — a real strike requires the ball to actually depart the tee-box ROI within `window` seconds AFTER the audio transient (rejects practice swings, neighbor-bay sounds, and audio with no ball motion). Departure before the transient, or none, is unconfirmed.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ImpactConfirmationTests.swift
import XCTest
@testable import chunky

final class ImpactConfirmationTests: XCTestCase {
    func testConfirmedWhenBallDepartsWithinWindow() {
        XCTAssertTrue(ImpactConfirmation.isConfirmed(audioTransientTime: 1.00,
                                                     ballDepartureTime: 1.03, window: 0.08))
    }
    func testRejectedWhenDepartureTooLate() {
        XCTAssertFalse(ImpactConfirmation.isConfirmed(audioTransientTime: 1.00,
                                                      ballDepartureTime: 1.20, window: 0.08))
    }
    func testRejectedWhenNoDeparture() {
        XCTAssertFalse(ImpactConfirmation.isConfirmed(audioTransientTime: 1.00,
                                                      ballDepartureTime: nil))
    }
    func testRejectedWhenDepartureBeforeAudio() {
        XCTAssertFalse(ImpactConfirmation.isConfirmed(audioTransientTime: 1.00,
                                                      ballDepartureTime: 0.95, window: 0.08))
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/ImpactConfirmationTests ...` — Expected: `cannot find 'ImpactConfirmation'`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/CaptureKit/Core/ImpactConfirmation.swift
import Foundation

/// Debounces the audio trigger against actual ball motion: a strike is real only
/// if the ball leaves the tee-box ROI within `window` seconds after the audio
/// transient (spec §5.4). Prevents phantom shots from practice swings / neighbors.
nonisolated enum ImpactConfirmation {
    static func isConfirmed(audioTransientTime: Double,
                            ballDepartureTime: Double?,
                            window: Double = 0.080) -> Bool {
        guard let departure = ballDepartureTime else { return false }
        return departure >= audioTransientTime && departure <= audioTransientTime + window
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Core/ImpactConfirmation.swift chunky/chunkyTests/ImpactConfirmationTests.swift && \
git commit -m "feat(capturekit): add impact confirmation/debounce

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Capture configuration value type

**Files:**
- Create: `chunky/chunky/CaptureKit/Core/CaptureConfiguration.swift`
- Test: `chunky/chunkyTests/CaptureConfigurationTests.swift`

**Interfaces:**
- Produces: `nonisolated struct CaptureConfiguration: Equatable, Sendable` with nested `enum Lens: String, Sendable { case telephoto, wide }` and fields `lens` (default `.telephoto`), `targetFPS` (240), `resolutionHeight` (1080), `shutterSeconds` (1/2000), `ringBufferSeconds` (0.5), `preRollSeconds` (0.040), `postRollSeconds` (0.120); computed `var ringBufferCapacity: Int { Int((ringBufferSeconds * targetFPS).rounded()) }`; `static let `default``.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/CaptureConfigurationTests.swift
import XCTest
@testable import chunky

final class CaptureConfigurationTests: XCTestCase {
    func testDefaults() {
        let c = CaptureConfiguration.default
        XCTAssertEqual(c.lens, .telephoto)
        XCTAssertEqual(c.targetFPS, 240, accuracy: 1e-9)
        XCTAssertEqual(c.resolutionHeight, 1080)
        XCTAssertEqual(c.shutterSeconds, 1.0/2000, accuracy: 1e-12)
    }

    func testRingBufferCapacity() {
        // 0.5 s * 240 fps = 120 frames
        XCTAssertEqual(CaptureConfiguration.default.ringBufferCapacity, 120)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/CaptureConfigurationTests ...` — Expected: `cannot find 'CaptureConfiguration'`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/CaptureKit/Core/CaptureConfiguration.swift
import Foundation

nonisolated struct CaptureConfiguration: Equatable, Sendable {
    enum Lens: String, Sendable, CaseIterable { case telephoto, wide }

    var lens: Lens = .telephoto
    var targetFPS: Double = 240
    var resolutionHeight: Int = 1080
    var shutterSeconds: Double = 1.0 / 2000
    var ringBufferSeconds: Double = 0.5
    var preRollSeconds: Double = 0.040
    var postRollSeconds: Double = 0.120

    var ringBufferCapacity: Int { Int((ringBufferSeconds * targetFPS).rounded()) }

    static let `default` = CaptureConfiguration()
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Core/CaptureConfiguration.swift chunky/chunkyTests/CaptureConfigurationTests.swift && \
git commit -m "feat(capturekit): add capture configuration value type

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Device seams + camera capture controller

**Files:**
- Create: `chunky/chunky/CaptureKit/Device/CaptureProtocols.swift`
- Create: `chunky/chunky/CaptureKit/Device/CameraCaptureController.swift`
- Test: none (device layer — **build-verified only**; on-device behavior in Task 12).

**Interfaces:**
- Consumes: `CaptureConfiguration`, `CaptureFormatDescriptor`/`CaptureFormatSelector`, `ExposureCalculator`, `Timestamped`, `RingBuffer`.
- Produces:
  - `CaptureProtocols.swift`: `protocol FrameReceiver: AnyObject, Sendable { func receiveFrame(_ pixelBuffer: CVPixelBuffer, at timeSeconds: Double) }` and `enum CaptureSetupError: Error { case noCamera, noSuitableFormat, configurationFailed(String) }` and `enum CaptureStatus: Sendable { case idle, running, needsMoreLight, unauthorized, failed(String) }`.
  - `CameraCaptureController`: configures and owns an `AVCaptureSession` per a `CaptureConfiguration`, selecting the camera (`.builtInTelephotoCamera` preferred, `.builtInWideAngleCamera` fallback) via `AVCaptureDevice.DiscoverySession`, choosing the best format by mapping `device.formats` → `[CaptureFormatDescriptor]` through `CaptureFormatSelector`, setting `activeVideoMin/MaxFrameDuration = CMTime(value: 1, timescale: Int32(targetFPS))`, applying custom short-shutter exposure via `ExposureCalculator` + `setExposureModeCustom`, locking white balance and focus, and delivering frames from an `AVCaptureVideoDataOutput` (serial queue, `alwaysDiscardsLateVideoFrames = true`, BGRA/420f pixel format) to a `FrameReceiver`. Exposes `func requestAuthorization() async -> Bool`, `func start() throws`, `func stop()`, and a `status` callback.

- [ ] **Step 1: Implement the protocols**

```swift
// chunky/chunky/CaptureKit/Device/CaptureProtocols.swift
import CoreVideo

protocol FrameReceiver: AnyObject, Sendable {
    func receiveFrame(_ pixelBuffer: CVPixelBuffer, at timeSeconds: Double)
}

enum CaptureSetupError: Error, Equatable {
    case noCamera
    case noSuitableFormat
    case configurationFailed(String)
}

enum CaptureStatus: Sendable, Equatable {
    case idle
    case running
    case needsMoreLight
    case unauthorized
    case failed(String)
}
```

- [ ] **Step 2: Implement `CameraCaptureController`**

Implement a complete, idiomatic AVFoundation controller meeting the Interfaces above. It MUST:
- Discover the device: `AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTelephotoCamera, .builtInWideAngleCamera], mediaType: .video, position: .back)`, preferring telephoto when `config.lens == .telephoto` and it exists, else wide; throw `CaptureSetupError.noCamera` if none.
- Map `device.formats` to `[CaptureFormatDescriptor]` (using `CMVideoFormatDescriptionGetDimensions` for width/height and each format's `videoSupportedFrameRateRanges.maxFrameRate`), pick with `CaptureFormatSelector.best(from:targetFPS:targetHeight:)`, and set the matching `AVCaptureDevice.Format` as `activeFormat` inside `lockForConfiguration()`; throw `noSuitableFormat` if selection returns nil or no matching real format is found.
- Set `activeVideoMinFrameDuration = activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(config.targetFPS))`.
- Apply exposure: read `device.iso` and `device.exposureDuration.seconds` under the current auto exposure, compute `ExposureCalculator.recommend(autoISO:autoDuration:targetDuration: config.shutterSeconds, minISO: activeFormat.minISO, maxISO: activeFormat.maxISO)`, then `setExposureModeCustom(duration: CMTime(seconds: config.shutterSeconds, preferredTimescale: 1_000_000), iso: Float(rec.iso))`; publish `.needsMoreLight` via the status callback when `rec.needsMoreLight`.
- Lock white balance (`whiteBalanceMode = .locked`) and focus (`focusMode = .locked`).
- Add an `AVCaptureVideoDataOutput` with `alwaysDiscardsLateVideoFrames = true`, `videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]`, a dedicated serial `DispatchQueue(label: "capturekit.frames")`, and a delegate that forwards each sample buffer's `CVImageBuffer` + `CMSampleBufferGetPresentationTimeStamp(...).seconds` to the injected `FrameReceiver`.
- `requestAuthorization()` wraps `AVCaptureDevice.requestAccess(for: .video)`.
- Never block the capture queue; do detection elsewhere (the receiver just buffers).
Provide a preview-friendly accessor (`var session: AVCaptureSession`) so a later Live screen can attach an `AVCaptureVideoPreviewLayer`.

- [ ] **Step 3: Build to verify it compiles**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. (Behavior is verified on-device in Task 12 — a simulator build only proves it compiles.)

- [ ] **Step 4: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Device/CaptureProtocols.swift chunky/chunky/CaptureKit/Device/CameraCaptureController.swift && \
git commit -m "feat(capturekit): add camera capture controller (device, build-verified)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Audio impact monitor (device)

**Files:**
- Create: `chunky/chunky/CaptureKit/Device/AudioImpactMonitor.swift`
- Test: none (device — build-verified; on-device in Task 12).

**Interfaces:**
- Consumes: `AudioImpactDetector`.
- Produces: `final class AudioImpactMonitor` that installs a tap on `AVAudioEngine().inputNode`, computes per-buffer short-time energy (mean square of the float samples), feeds `AudioImpactDetector.process(energy:time:)` (time from the buffer's sample time / sample rate or host time), and invokes an `onImpact: (Double) -> Void` callback with the transient time. Exposes `func requestAuthorization() async -> Bool` (mic), `func start() throws`, `func stop()`.

- [ ] **Step 1: Implement `AudioImpactMonitor`**

Implement a complete AVFAudio monitor: create an `AVAudioEngine`, install a tap on `inputNode` (bufferSize ~1024, format from the input node), in the tap block compute energy = mean of `sample*sample` over `buffer.floatChannelData?[0]` for `buffer.frameLength`, derive a monotonically increasing time in seconds, call `detector.process(energy: Double(energy), time: t)`, and on `true` call `onImpact(t)` on the main queue. Configure the `AVAudioSession` category `.playAndRecord`/`.record` as appropriate and activate it. `requestAuthorization()` wraps `AVAudioApplication.requestRecordPermission` (iOS 17+) / `AVAudioSession.requestRecordPermission`. Handle start/stop cleanly (remove tap, stop engine).

- [ ] **Step 2: Build** — full build → `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Device/AudioImpactMonitor.swift && \
git commit -m "feat(capturekit): add audio impact monitor (device, build-verified)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Impact clip writer (device)

**Files:**
- Create: `chunky/chunky/CaptureKit/Device/ImpactClipWriter.swift`
- Test: none (device — build-verified; on-device in Task 12).

**Interfaces:**
- Consumes: `Timestamped`.
- Produces: `final class ImpactClipWriter` with `func write(frames: [Timestamped<CVPixelBuffer>], fps: Double, to url: URL) async throws` — writes the frame window to an `.mov` via `AVAssetWriter` + `AVAssetWriterInputPixelBufferAdaptor`, using each frame's timestamp (relative to the first) for presentation times; returns/throws on completion. A convenience `func makeClipURL() -> URL` producing a unique temp/Documents URL.

- [ ] **Step 1: Implement `ImpactClipWriter`**

Implement a complete `AVAssetWriter` flow: create the writer for `.mov`, add an `AVAssetWriterInput` (codec `.h264` or `.hevc`, dimensions from the first pixel buffer via `CVPixelBufferGetWidth/Height`), attach an `AVAssetWriterInputPixelBufferAdaptor`, `startWriting()` + `startSession(atSourceTime: .zero)`, append each pixel buffer at `CMTime(seconds: frame.timeSeconds - firstTime, preferredTimescale: 600)` (waiting on `input.isReadyForMoreMediaData`), then `markAsFinished()` + `await writer.finishWriting()`. Throw on empty input or writer failure.

- [ ] **Step 2: Build** — full build → `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Device/ImpactClipWriter.swift && \
git commit -m "feat(capturekit): add impact clip writer (device, build-verified)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Capture coordinator (orchestration)

**Files:**
- Create: `chunky/chunky/CaptureKit/Device/CaptureCoordinator.swift`
- Test: none (device — build-verified; on-device in Task 12).

**Interfaces:**
- Consumes: everything above.
- Produces: `@MainActor final class CaptureCoordinator: ObservableObject` (or `@Observable`) that owns a `CameraCaptureController`, an `AudioImpactMonitor`, a frame `RingBuffer<Timestamped<CVPixelBuffer>>` (sized by `config.ringBufferCapacity`), and an `ImpactClipWriter`. It conforms to `FrameReceiver` (appends incoming frames to the ring buffer on the capture queue — guarded), listens for `onImpact`, and on a confirmed impact snapshots the ring-buffer window via `ImpactWindow.slice` and publishes an `ImpactCapture` (impact time + the frame window) — and optionally writes a clip. Public API: `func arm() async throws`, `func disarm()`, a published `status: CaptureStatus`, and an `onImpactCapture: (ImpactCapture) -> Void` (or an `AsyncStream`). `struct ImpactCapture { let impactTime: Double; let frames: [Timestamped<CVPixelBuffer>] }`.

**Note on motion confirmation:** Task 6's `ImpactConfirmation` needs a `ballDepartureTime`. Full motion detection (ROI frame-differencing) belongs to VisionCore (Plan 5). For Phase 0, the coordinator MAY confirm on audio alone (record the impact window on the audio transient) and expose a hook (`departureProvider`) that Plan 5/6 fills in; document this clearly. Do not fake a departure time — leave the confirmation seam explicit.

- [ ] **Step 1: Implement `CaptureCoordinator`** per the Interfaces + note. Ring-buffer appends happen on the capture serial queue; snapshotting for an impact copies the current buffer contents. Keep the capture queue non-blocking (no clip writing on it — dispatch clip writing to a background task).

- [ ] **Step 2: Build** — full build → `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/CaptureKit/Device/CaptureCoordinator.swift && \
git commit -m "feat(capturekit): add capture coordinator (device, build-verified)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Green gate, purity guard & on-device acceptance checklist

**Files:**
- Create: `docs/capturekit-ondevice-acceptance.md` (the checklist the human runs on an iPhone)
- Otherwise verification only.

- [ ] **Step 1: Run the full unit suite** — `... test -only-testing:chunkyTests 2>&1 | tail -30` — Expected `** TEST SUCCEEDED **` (all Core tests + Plans 1–3 pass).

- [ ] **Step 2: Full build** — `... build 2>&1 | tail -5` → `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Purity guards** — Run:

```bash
cd /Users/kason/Documents/github/Chunky && \
! grep -rEl "import (AVFoundation|AVFAudio|CoreMedia|CoreVideo|Vision|SwiftUI|SwiftData)" chunky/chunky/CaptureKit/Core/ && echo "OK: CaptureKit/Core is device-free" && \
! grep -rEl "import (AVFoundation|AVFAudio|Vision)" chunky/chunky/Ballistics/ chunky/chunky/Metrics/ chunky/chunky/DataStore/ && echo "OK: math/data layers still capture-free"
```
Expected both OK lines.

- [ ] **Step 4: Write the on-device acceptance checklist** `docs/capturekit-ondevice-acceptance.md` capturing the Phase-0 acceptance criteria (spec §13) for the human to run on an iPhone 16 Pro Max+:
  - Confirm the selected lens is telephoto and the active format is 1080p @ 240 fps.
  - Hit ~20 shots; confirm the ball appears as a **sharp (non-blurred) disk** in saved frames; ≥ 8 frames captured between address and ball leaving frame.
  - Confirm the audio trigger fires on real strikes and NOT on practice swings (≥ 90% on the 20-shot test).
  - Confirm the "more light needed" warning appears in low light and clears in good light.
  - Note measured values / issues for field tuning.

- [ ] **Step 5: Commit the checklist**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add docs/capturekit-ondevice-acceptance.md && \
git commit -m "docs(capturekit): add Phase-0 on-device acceptance checklist

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage (§5 / Phase 0):**
- §5.1 device & format (telephoto/wide, 240@1080, frame durations, lockForConfiguration) → Tasks 4, 8. ✅
- §5.2 manual short-shutter exposure + ISO compensation + "more light" warning + locked WB/focus → Tasks 5, 8. ✅
- §5.3 frame delivery + ring buffer + serial queue + discard-late + cheap-buffering strategy → Tasks 1, 8, 11. ✅
- §5.4 impact trigger: audio primary (onset detection + refractory) + motion-confirm debounce + window snapshot → Tasks 3, 6, 9, 11 (motion-departure seam left explicit for Plan 5). ✅
- Save triggered impact clip to disk → Task 10. ✅
- Phase-0 acceptance (sharp ball, ≥8 frames, ≥90% audio trigger) → Task 12 on-device checklist (cannot be automated in this sandbox). ✅
- Dependency rule (Core device-free; math/data layers untouched) → global constraint + Task 12 guards. ✅
- Out of scope here (later plans): ROI motion detection & ball tracking (VisionCore, Plan 5), the Live capture screen (Plan 6), wiring capture → Metrics → DataStore (Plan 6).

**2. Placeholder scan:** `Core/` tasks (1–7) carry complete code + full test bodies. `Device/` tasks (8–11) specify complete, concrete AVFoundation implementations (exact APIs, settings, and structure) verified by build; they are "flexible" per their framework but are not "TODO" stubs. The one deliberate seam — motion `ballDepartureTime` — is documented as a Plan-5 hook, not faked.

**3. Type consistency:** `CaptureConfiguration` (fields + `ringBufferCapacity`), `CaptureFormatDescriptor`/`CaptureFormatSelector.best(from:targetFPS:targetHeight:)`, `ExposureCalculator.recommend(...)→ExposureRecommendation`, `AudioImpactDetector.process(energy:time:)`, `ImpactConfirmation.isConfirmed(audioTransientTime:ballDepartureTime:window:)`, `RingBuffer`, `Timestamped`/`ImpactWindow.slice(...)`, and `FrameReceiver`/`CaptureStatus`/`ImpactCapture` are referenced consistently across the device tasks that consume them. Core types are `nonisolated` + `Sendable`; the coordinator is `@MainActor`.
