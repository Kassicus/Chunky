# Live End-to-End (Plan 6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the existing capture → vision → metrics → persistence components into a working app that measures a golf shot and auto-saves it, adding the missing Live/Range and Calibrate screens plus Settings, Session summary, CSV export, and a debug overlay.

**Architecture:** A thin app-orchestration layer (`ShotPipeline`, `LiveSessionController`) bridges the device pieces to the pure math: on a confirmed impact, `CaptureCoordinator` publishes an `ImpactCapture`, `VisionPipeline.track` produces `[TrackPoint]`, `Metrics.computeShot` produces a `ShotResult`, and `ShotStore.saveShot` auto-persists it to the selected club. New SwiftUI screens live in `Features/` and reuse the established "Twilight Range Readout" `Theme`. The accuracy-critical packages (Ballistics/Metrics/DataStore) stay free of capture frameworks; only the orchestration and UI layers import AVFoundation/Vision/CoreVideo/CoreMotion.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, AVFoundation (`AVCaptureVideoPreviewLayer`), CoreVideo, CoreMotion, XCTest. Targets the existing `chunky` app target; tests in `chunkyTests`.

## Global Constraints

- **Platform:** iOS 26.5+ deployment, iPhone-only, Xcode 26.5, Swift 6. `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — pure Foundation-only types must be declared `nonisolated`; non-Sendable device types (`CVPixelBuffer`) use `nonisolated(unsafe)`/`@unchecked Sendable` only where already established.
- **Dependency rule (spec §4):** `Ballistics`, `Metrics`, and `DataStore` MUST NOT import AVFoundation, Vision, CoreVideo, CoreMotion, or AVFAudio. The new orchestration layer (`Orchestration/`, `Features/`) MAY. `ShotTrackCodec` is pure and stays in `Metrics` (no CoreVideo). `ShotPipeline` imports CoreVideo (it consumes `ImpactCapture`) and therefore lives in `Orchestration/`, never in `Metrics`.
- **No project.pbxproj edits.** This project uses `PBXFileSystemSynchronizedRootGroup` (objectVersion 77): files added under `chunky/chunky/**` and `chunky/chunkyTests/**` are auto-included. Never edit `project.pbxproj`; its absence from a diff is correct.
- **Git hygiene:** explicit `git add <paths>` only — never `git add -A`/`git add .` (an untracked user asset `chunky_icon.png` must never be staged). Commit only the files a task creates/modifies.
- **Verification model:** Pure/Core code is unit-tested with XCTest in the Simulator (`iPhone 17 Pro Max`). Device and SwiftUI code **cannot** be exercised in this environment (no camera/mic/motion; XCUITest dies on simulator IPC) — it is **build-verified** and each screen ships a `#Preview`; on-device behavior is validated by the human via `docs/live-ondevice-acceptance.md` (Task 15).
- **Auto-save is mandatory (spec §10):** every produced `ShotResult` saves to the selected club instantly, with no manual save step. A club MUST be selected before capture can be armed.
- **Design identity:** reuse `Features/Theme.swift` ("Twilight Range Readout") tokens for all new screens — do not introduce a new palette/type system. The Live screen is glanceable: carry is the largest element; confidence is always shown and color-coded via `Theme.confidenceColor(_:)`; **exclude** and **delete** are reachable in one tap from the result card. Units follow the `Units` setting (yd default).
- **Build command:** `xcodebuild -project chunky.xcodeproj -scheme chunky -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build` (run from `/Users/kason/Documents/github/Chunky/chunky`). Test command: same with `test -only-testing:chunkyTests`. A SourceKit "No such module 'UIKit'/'CoreVideo'/'AVFoundation'" or "Cannot find type" diagnostic is a benign macOS-index artifact when the `xcodebuild` build/test succeeds — not a failure.

---

## File Structure

**New — Orchestration (app layer; may import capture frameworks):**
- `chunky/chunky/Orchestration/ShotPipeline.swift` — `ImpactCapture`/`[TrackPoint]` → `ShotResult` + raw-track JSON.
- `chunky/chunky/Features/Live/LiveSessionController.swift` — `@MainActor` `ObservableObject` view-model owning the coordinator, current session, calibration, selected club; drives the pipeline and auto-save.

**New — pure (unit-tested):**
- `chunky/chunky/Metrics/ShotTrackCodec.swift` — encode/decode `[TrackPoint]` ↔ JSON string.
- `chunky/chunky/DataStore/CalibrationProfileMapping.swift` — `CalibrationScale` ↔ `CalibrationProfile`.
- Additions to `chunky/chunky/Metrics/Vec2.swift`, `Metrics/TrackPoint.swift` (Codable), `Calibration/Core/CalibrationMath.swift` (manual-length helpers).

**New — settings model:**
- `chunky/chunky/Features/Settings/AppSettings.swift` — `@Observable` UserDefaults-backed app settings.

**New — SwiftUI screens/components (build + #Preview):**
- `chunky/chunky/Features/Live/CameraPreviewView.swift`, `Features/Live/LiveView.swift`, `Features/Live/ResultCardView.swift`, `Features/Live/TeeBoxOverlay.swift`, `Features/Live/DebugOverlayView.swift`
- `chunky/chunky/Features/Calibrate/CalibrateView.swift`
- `chunky/chunky/Features/Settings/SettingsView.swift`
- `chunky/chunky/Features/Session/SessionSummaryView.swift`

**Modified:**
- `chunky/chunky/CaptureKit/Device/CaptureCoordinator.swift` — add `previewSession`, `setLens(_:)`, `recentFrames()`; make `config`/`camera` mutable.
- `chunky/chunky/Features/RootView.swift` — add Live + Settings tabs; inject `AppSettings`.
- `chunky/chunky/chunkyApp.swift` — inject `AppSettings` into the environment.

**New docs:** `docs/live-ondevice-acceptance.md`.

---

## Task 1: Track serialization (pure)

**Files:**
- Modify: `chunky/chunky/Metrics/Vec2.swift`, `chunky/chunky/Metrics/TrackPoint.swift`
- Create: `chunky/chunky/Metrics/ShotTrackCodec.swift`
- Test: `chunky/chunkyTests/ShotTrackCodecTests.swift`

**Interfaces:**
- Consumes: `TrackPoint { timeSeconds: Double; pixel: Vec2; radiusPx: Double; confidence: Double }`, `Vec2` (stored `x,y: Double`).
- Produces: `ShotTrackCodec.encode(_:) -> String`, `ShotTrackCodec.decode(_:) -> [TrackPoint]?`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ShotTrackCodecTests.swift
import XCTest
@testable import chunky

final class ShotTrackCodecTests: XCTestCase {
    func testRoundTripPreservesTrack() {
        let track = [
            TrackPoint(timeSeconds: 0.0,   pixel: Vec2(10, 20), radiusPx: 5, confidence: 0.9),
            TrackPoint(timeSeconds: 0.004, pixel: Vec2(14, 19), radiusPx: 5, confidence: 0.8),
        ]
        let json = ShotTrackCodec.encode(track)
        XCTAssertFalse(json.isEmpty)
        XCTAssertEqual(ShotTrackCodec.decode(json), track)
    }

    func testEmptyTrackRoundTrips() {
        XCTAssertEqual(ShotTrackCodec.decode(ShotTrackCodec.encode([])), [])
    }

    func testDecodeOfGarbageReturnsNil() {
        XCTAssertNil(ShotTrackCodec.decode("not json"))
    }
}
```

- [ ] **Step 2: Run it — expect failure** (`ShotTrackCodec` / Codable not defined). Run: `xcodebuild ... test -only-testing:chunkyTests/ShotTrackCodecTests`.

- [ ] **Step 3: Add Codable conformances + the codec**

In `Metrics/Vec2.swift` add (only if `Vec2` is not already `Codable`):
```swift
extension Vec2: Codable {}
```
In `Metrics/TrackPoint.swift` add:
```swift
extension TrackPoint: Codable {}
```
Create `Metrics/ShotTrackCodec.swift`:
```swift
import Foundation

/// Serializes a tracked ball path to/from a compact JSON string for
/// `Shot.rawTrackJSON`, so carry can be recomputed later (spec §10).
nonisolated enum ShotTrackCodec {
    static func encode(_ track: [TrackPoint]) -> String {
        guard let data = try? JSONEncoder().encode(track),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }

    static func decode(_ json: String) -> [TrackPoint]? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([TrackPoint].self, from: data)
    }
}
```
If synthesized `Codable` fails because a stored property is not `Codable`, add explicit `CodingKeys`/`init(from:)` for that type instead — do not change stored property types.

- [ ] **Step 4: Run the test — expect PASS.**
- [ ] **Step 5: Commit**
```bash
git add chunky/chunky/Metrics/Vec2.swift chunky/chunky/Metrics/TrackPoint.swift chunky/chunky/Metrics/ShotTrackCodec.swift chunky/chunkyTests/ShotTrackCodecTests.swift
git commit -m "feat(metrics): add ShotTrackCodec for raw-track JSON round-trip"
```

---

## Task 2: Manual-length calibration helpers (pure)

**Files:**
- Modify: `chunky/chunky/Calibration/Core/CalibrationMath.swift`
- Test: `chunky/chunkyTests/CalibrationManualTests.swift`

**Interfaces:**
- Consumes: `Vec2` (`-`, `.magnitude`), `CalibrationScale(pixelsPerMeter:imageUpUnit:)`, existing `CalibrationMath.imageUpUnit(imagePlaneGravity:)`.
- Produces: `CalibrationMath.pixelsPerMeter(pointA:pointB:knownLengthMeters:) -> Double?` and `CalibrationMath.calibrationScale(pointA:pointB:knownLengthMeters:imagePlaneGravity:) -> CalibrationScale?`.

- [ ] **Step 1: Write the failing test**
```swift
// chunky/chunkyTests/CalibrationManualTests.swift
import XCTest
@testable import chunky

final class CalibrationManualTests: XCTestCase {
    func testPixelsPerMeterFromTwoPoints() {
        // 200 px apart, 0.5 m reference → 400 px/m
        let ppm = CalibrationMath.pixelsPerMeter(pointA: Vec2(0, 0), pointB: Vec2(200, 0), knownLengthMeters: 0.5)
        XCTAssertEqual(ppm!, 400, accuracy: 1e-9)
    }

    func testZeroLengthReturnsNil() {
        XCTAssertNil(CalibrationMath.pixelsPerMeter(pointA: Vec2(0, 0), pointB: Vec2(200, 0), knownLengthMeters: 0))
    }

    func testCoincidentPointsReturnNil() {
        XCTAssertNil(CalibrationMath.pixelsPerMeter(pointA: Vec2(5, 5), pointB: Vec2(5, 5), knownLengthMeters: 1))
    }

    func testManualScaleUsesGravityForUp() {
        // gravity down (0,+1) → imageUpUnit ≈ (0,-1)
        let scale = CalibrationMath.calibrationScale(pointA: Vec2(0, 0), pointB: Vec2(100, 0),
                                                     knownLengthMeters: 0.5, imagePlaneGravity: Vec2(0, 1))
        XCTAssertEqual(scale!.pixelsPerMeter, 200, accuracy: 1e-9)
        XCTAssertEqual(scale!.imageUpUnit.x, 0, accuracy: 1e-9)
        XCTAssertEqual(scale!.imageUpUnit.y, -1, accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Run it — expect failure** (functions not defined).

- [ ] **Step 3: Implement** (append to the `CalibrationMath` enum):
```swift
    /// Pixels-per-meter from two user-tapped points a known physical distance apart.
    static func pixelsPerMeter(pointA: Vec2, pointB: Vec2, knownLengthMeters: Double) -> Double? {
        guard knownLengthMeters > 0 else { return nil }
        let d = (pointB - pointA).magnitude
        guard d > 0 else { return nil }
        return d / knownLengthMeters
    }

    /// Builds a `CalibrationScale` from two known-distance points plus gravity.
    static func calibrationScale(pointA: Vec2, pointB: Vec2, knownLengthMeters: Double,
                                 imagePlaneGravity: Vec2) -> CalibrationScale? {
        guard let ppm = pixelsPerMeter(pointA: pointA, pointB: pointB, knownLengthMeters: knownLengthMeters)
        else { return nil }
        return CalibrationScale(pixelsPerMeter: ppm,
                                imageUpUnit: imageUpUnit(imagePlaneGravity: imagePlaneGravity))
    }
```

- [ ] **Step 4: Run the test — expect PASS.**
- [ ] **Step 5: Commit**
```bash
git add chunky/chunky/Calibration/Core/CalibrationMath.swift chunky/chunkyTests/CalibrationManualTests.swift
git commit -m "feat(calibration): add manual two-point known-length scale helpers"
```

---

## Task 3: CalibrationProfile ↔ CalibrationScale mapping (pure)

**Files:**
- Create: `chunky/chunky/DataStore/CalibrationProfileMapping.swift`
- Test: `chunky/chunkyTests/CalibrationProfileMappingTests.swift`

**Interfaces:**
- Consumes: `CalibrationScale { pixelsPerMeter: Double; imageUpUnit: Vec2 }`, `CalibrationProfile(lens:pxPerMeter:imageUpX:imageUpY:cameraDistanceM:createdAt:)`, `CameraLens`.
- Produces: `CalibrationProfileMapping.profile(from:lens:cameraDistanceM:createdAt:) -> CalibrationProfile`, `CalibrationProfileMapping.scale(from:) -> CalibrationScale`.

- [ ] **Step 1: Write the failing test**
```swift
// chunky/chunkyTests/CalibrationProfileMappingTests.swift
import XCTest
@testable import chunky

final class CalibrationProfileMappingTests: XCTestCase {
    func testScaleRoundTripsThroughProfile() {
        let scale = CalibrationScale(pixelsPerMeter: 1234.5, imageUpUnit: Vec2(0, -1))
        let created = Date(timeIntervalSince1970: 1_000_000)
        let profile = CalibrationProfileMapping.profile(from: scale, lens: .telephoto,
                                                        cameraDistanceM: 3.0, createdAt: created)
        XCTAssertEqual(profile.pxPerMeter, 1234.5, accuracy: 1e-9)
        XCTAssertEqual(profile.imageUpX, 0, accuracy: 1e-9)
        XCTAssertEqual(profile.imageUpY, -1, accuracy: 1e-9)
        XCTAssertEqual(profile.lens, .telephoto)

        let back = CalibrationProfileMapping.scale(from: profile)
        XCTAssertEqual(back.pixelsPerMeter, scale.pixelsPerMeter, accuracy: 1e-9)
        XCTAssertEqual(back.imageUpUnit.x, scale.imageUpUnit.x, accuracy: 1e-9)
        XCTAssertEqual(back.imageUpUnit.y, scale.imageUpUnit.y, accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Run it — expect failure.**

- [ ] **Step 3: Implement**
```swift
// chunky/chunky/DataStore/CalibrationProfileMapping.swift
import Foundation

/// Bridges the pure `CalibrationScale` (Metrics) and the persisted
/// `CalibrationProfile` (SwiftData). `CalibrationProfile` stores the up-vector
/// as two Doubles rather than a `Vec2`.
@MainActor
enum CalibrationProfileMapping {
    static func profile(from scale: CalibrationScale, lens: CameraLens,
                        cameraDistanceM: Double = 0, createdAt: Date) -> CalibrationProfile {
        CalibrationProfile(lens: lens,
                           pxPerMeter: scale.pixelsPerMeter,
                           imageUpX: scale.imageUpUnit.x,
                           imageUpY: scale.imageUpUnit.y,
                           cameraDistanceM: cameraDistanceM,
                           createdAt: createdAt)
    }

    static func scale(from profile: CalibrationProfile) -> CalibrationScale {
        CalibrationScale(pixelsPerMeter: profile.pxPerMeter,
                         imageUpUnit: Vec2(profile.imageUpX, profile.imageUpY))
    }
}
```
Note: `CalibrationProfile` is a SwiftData `@Model` (MainActor-isolated), so the enum is `@MainActor`. If the test complains about main-actor isolation, annotate the test method with `@MainActor`.

- [ ] **Step 4: Run the test — expect PASS.**
- [ ] **Step 5: Commit**
```bash
git add chunky/chunky/DataStore/CalibrationProfileMapping.swift chunky/chunkyTests/CalibrationProfileMappingTests.swift
git commit -m "feat(datastore): map CalibrationScale to/from CalibrationProfile"
```

---

## Task 4: ShotPipeline — capture/track → ShotResult (orchestration)

**Files:**
- Create: `chunky/chunky/Orchestration/ShotPipeline.swift`
- Test: `chunky/chunkyTests/ShotPipelineTests.swift`

**Interfaces:**
- Consumes: `VisionPipeline.track(_:detector:) -> [TrackPoint]`, `Metrics.computeShot(track:calibration:atmosphere:modeledSpinRPM:...) -> ShotResult?`, `ShotTrackCodec`, `ImpactCapture`, `CalibrationScale`, `Atmosphere`, `BallDetector`/`BlobBallDetector`.
- Produces:
  - `struct ShotPipeline.Output: Equatable { let result: ShotResult; let rawTrackJSON: String; let trackPointCount: Int }`
  - `func output(track:calibration:atmosphere:modeledSpinRPM:) -> Output?` (pure)
  - `func output(from:calibration:atmosphere:modeledSpinRPM:detector:) -> Output?` (thin glue over `VisionPipeline`)

- [ ] **Step 1: Write the failing test** (pure path + one synthetic-buffer end-to-end path)
```swift
// chunky/chunkyTests/ShotPipelineTests.swift
import XCTest
import CoreVideo
@testable import chunky

final class ShotPipelineTests: XCTestCase {
    // Pure path: a clean constant-velocity track yields a ShotResult + JSON.
    func testOutputFromTrackProducesResultAndJSON() {
        // Ball moving up-and-right at a constant image velocity over 6 frames.
        var track: [TrackPoint] = []
        for i in 0..<6 {
            let t = Double(i) * 0.004
            track.append(TrackPoint(timeSeconds: t, pixel: Vec2(100 + Double(i) * 30, 400 - Double(i) * 20),
                                    radiusPx: 6, confidence: 0.9))
        }
        let scale = CalibrationScale(pixelsPerMeter: 500, imageUpUnit: Vec2(0, -1))
        let out = ShotPipeline().output(track: track, calibration: scale,
                                        atmosphere: Atmosphere(), modeledSpinRPM: 2600)
        XCTAssertNotNil(out)
        XCTAssertGreaterThan(out!.result.ballSpeedMS, 0)
        XCTAssertEqual(out!.trackPointCount, 6)
        XCTAssertEqual(ShotTrackCodec.decode(out!.rawTrackJSON)?.count, 6)
    }

    func testTooShortTrackReturnsNil() {
        let scale = CalibrationScale(pixelsPerMeter: 500, imageUpUnit: Vec2(0, -1))
        let out = ShotPipeline().output(track: [], calibration: scale,
                                        atmosphere: Atmosphere(), modeledSpinRPM: 2600)
        XCTAssertNil(out)
    }

    // End-to-end path: synthetic pixel buffers with a moving bright disk.
    func testOutputFromImpactCaptureRunsFullChain() {
        let frames = Self.syntheticImpactFrames()
        let capture = ImpactCapture(impactTime: 0, frames: frames)
        let scale = CalibrationScale(pixelsPerMeter: 500, imageUpUnit: Vec2(0, -1))
        let out = ShotPipeline().output(from: capture, calibration: scale,
                                        atmosphere: Atmosphere(), modeledSpinRPM: 6500)
        // The detector must find the disk in enough frames to fit a launch.
        XCTAssertNotNil(out, "full capture→track→result chain should produce a result")
        XCTAssertGreaterThanOrEqual(out!.trackPointCount, 4)
    }

    /// Builds 6 in-memory 32BGRA buffers, each with a bright filled disk that
    /// translates by (+30, -20) px per frame — mirrors the ShotPipeline unit track.
    static func syntheticImpactFrames() -> [Timestamped<CVPixelBuffer>] {
        let w = 240, h = 180
        var frames: [Timestamped<CVPixelBuffer>] = []
        for i in 0..<6 {
            var pb: CVPixelBuffer?
            let attrs: [String: Any] = [kCVPixelBufferCGImageCompatibilityKey as String: true]
            CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
                                attrs as CFDictionary, &pb)
            let buffer = pb!
            CVPixelBufferLockBaseAddress(buffer, [])
            let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
            let bpr = CVPixelBufferGetBytesPerRow(buffer)
            // Background = dark.
            for y in 0..<h { for x in 0..<w {
                let o = y * bpr + x * 4
                base[o] = 0; base[o+1] = 0; base[o+2] = 0; base[o+3] = 255
            }}
            // Bright disk (radius 6) at the moving center; G channel is what
            // PixelBufferGray reads for BGRA.
            let cx = 100 + i * 30, cy = 400 - i * 20 // note: cy may exceed h; clamp draw
            for dy in -6...6 { for dx in -6...6 {
                if dx*dx + dy*dy > 36 { continue }
                let x = cx + dx, y = cy + dy
                guard x >= 0, x < w, y >= 0, y < h else { continue }
                let o = y * bpr + x * 4
                base[o] = 255; base[o+1] = 255; base[o+2] = 255; base[o+3] = 255
            }}
            CVPixelBufferUnlockBaseAddress(buffer, [])
            frames.append(Timestamped(timeSeconds: Double(i) * 0.004, value: buffer))
        }
        return frames
    }
}
```
> Note on the synthetic frames: `cy` for the given track leaves the frame quickly (400 > 180). Adjust the synthetic centers in `syntheticImpactFrames()` so the disk stays on-screen for ≥4 frames (e.g. start at `cy = 150` and move `-20` per frame, and reduce the per-frame step if needed). The assertion only requires ≥4 tracked points — tune the synthetic geometry until the real `BlobBallDetector`+`BallTracker` produce them. This test proves the whole device-free chain; if tuning proves flaky, keep the pure-track tests as the gate and mark the end-to-end one `XCTSkip`-guarded with a comment, but attempt it first.

- [ ] **Step 2: Run it — expect failure** (`ShotPipeline` undefined).

- [ ] **Step 3: Implement**
```swift
// chunky/chunky/Orchestration/ShotPipeline.swift
import CoreVideo
import Foundation

/// App-orchestration glue: turns a captured impact window (or an already-tracked
/// path) into a `ShotResult` plus the serialized raw track for persistence.
///
/// Imports CoreVideo (via `ImpactCapture`), so it lives in `Orchestration/`,
/// never in the pure `Metrics` package.
nonisolated struct ShotPipeline {
    var vision = VisionPipeline()

    struct Output: Equatable {
        let result: ShotResult
        let rawTrackJSON: String
        let trackPointCount: Int
    }

    /// Pure path: a tracked ball path → result. Unit-tested.
    func output(track: [TrackPoint], calibration: CalibrationScale,
                atmosphere: Atmosphere, modeledSpinRPM: Double) -> Output? {
        guard let result = Metrics.computeShot(track: track, calibration: calibration,
                                               atmosphere: atmosphere,
                                               modeledSpinRPM: modeledSpinRPM) else { return nil }
        return Output(result: result, rawTrackJSON: ShotTrackCodec.encode(track),
                      trackPointCount: track.count)
    }

    /// Full path: raw capture → track → result.
    func output(from capture: ImpactCapture, calibration: CalibrationScale,
                atmosphere: Atmosphere, modeledSpinRPM: Double,
                detector: BallDetector = BlobBallDetector()) -> Output? {
        let track = vision.track(capture, detector: detector)
        return output(track: track, calibration: calibration,
                      atmosphere: atmosphere, modeledSpinRPM: modeledSpinRPM)
    }
}
```

- [ ] **Step 4: Run the tests — expect PASS** (tune synthetic geometry per the note until the end-to-end test passes or is deliberately skipped).
- [ ] **Step 5: Commit**
```bash
git add chunky/chunky/Orchestration/ShotPipeline.swift chunky/chunkyTests/ShotPipelineTests.swift
git commit -m "feat(orchestration): add ShotPipeline (capture/track -> ShotResult + raw JSON)"
```

---

## Task 5: AppSettings model (settings store)

**Files:**
- Create: `chunky/chunky/Features/Settings/AppSettings.swift`
- Test: `chunky/chunkyTests/AppSettingsTests.swift`

**Interfaces:**
- Consumes: `Units`, `CameraLens`, `Atmosphere`, `CaptureConfiguration.Lens`.
- Produces: `@Observable @MainActor final class AppSettings` with `var units: Units`, `var temperatureC/altitudeM/humidity: Double`, `var lens: CameraLens`, `var debugOverlayEnabled: Bool`, computed `var atmosphere: Atmosphere`, computed `var captureLens: CaptureConfiguration.Lens`. UserDefaults-backed via an injectable `UserDefaults` (default `.standard`) so tests use an isolated suite.

- [ ] **Step 1: Write the failing test**
```swift
// chunky/chunkyTests/AppSettingsTests.swift
import XCTest
@testable import chunky

@MainActor
final class AppSettingsTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "AppSettingsTests-\(UUID().uuidString)")!
        return d
    }

    func testDefaults() {
        let s = AppSettings(defaults: makeDefaults())
        XCTAssertEqual(s.units, .yards)
        XCTAssertEqual(s.lens, .telephoto)
        XCTAssertFalse(s.debugOverlayEnabled)
        XCTAssertEqual(s.atmosphere.temperatureC, 15, accuracy: 1e-9)
    }

    func testPersistsAcrossInstances() {
        let d = makeDefaults()
        let a = AppSettings(defaults: d)
        a.units = .meters
        a.temperatureC = 25
        a.debugOverlayEnabled = true
        let b = AppSettings(defaults: d)
        XCTAssertEqual(b.units, .meters)
        XCTAssertEqual(b.temperatureC, 25, accuracy: 1e-9)
        XCTAssertTrue(b.debugOverlayEnabled)
        XCTAssertEqual(b.atmosphere.temperatureC, 25, accuracy: 1e-9)
    }

    func testCaptureLensMapping() {
        let s = AppSettings(defaults: makeDefaults())
        s.lens = .wide
        XCTAssertEqual(s.captureLens, .wide)
    }
}
```

- [ ] **Step 2: Run it — expect failure.**

- [ ] **Step 3: Implement**
```swift
// chunky/chunky/Features/Settings/AppSettings.swift
import Foundation
import Observation

/// App-wide user preferences (units, environment, lens default, debug overlay),
/// persisted to `UserDefaults`. Injected into the SwiftUI environment.
@Observable
@MainActor
final class AppSettings {
    private let defaults: UserDefaults
    private enum Key {
        static let units = "settings.units"
        static let temperatureC = "settings.temperatureC"
        static let altitudeM = "settings.altitudeM"
        static let humidity = "settings.humidity"
        static let lens = "settings.lens"
        static let debugOverlay = "settings.debugOverlay"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Seed defaults on first launch.
        if defaults.object(forKey: Key.temperatureC) == nil { defaults.set(15.0, forKey: Key.temperatureC) }
    }

    var units: Units {
        get { Units(rawValue: defaults.string(forKey: Key.units) ?? "") ?? .yards }
        set { defaults.set(newValue.rawValue, forKey: Key.units) }
    }
    var temperatureC: Double {
        get { defaults.object(forKey: Key.temperatureC) as? Double ?? 15 }
        set { defaults.set(newValue, forKey: Key.temperatureC) }
    }
    var altitudeM: Double {
        get { defaults.double(forKey: Key.altitudeM) }
        set { defaults.set(newValue, forKey: Key.altitudeM) }
    }
    var humidity: Double {
        get { defaults.double(forKey: Key.humidity) }
        set { defaults.set(newValue, forKey: Key.humidity) }
    }
    var lens: CameraLens {
        get { CameraLens(rawValue: defaults.string(forKey: Key.lens) ?? "") ?? .telephoto }
        set { defaults.set(newValue.rawValue, forKey: Key.lens) }
    }
    var debugOverlayEnabled: Bool {
        get { defaults.bool(forKey: Key.debugOverlay) }
        set { defaults.set(newValue, forKey: Key.debugOverlay) }
    }

    var atmosphere: Atmosphere {
        Atmosphere(temperatureC: temperatureC, altitudeM: altitudeM, relativeHumidity: humidity)
    }
    var captureLens: CaptureConfiguration.Lens {
        lens == .telephoto ? .telephoto : .wide
    }
}
```
> If `@Observable` does not re-render on these computed get/set (because it can't track UserDefaults), back each with a stored `@ObservationTracked`-friendly property that mirrors UserDefaults: declare stored `var` properties initialized from `defaults` in `init`, and write-through to `defaults` in `didSet`. Prefer the stored-property form if the Settings screen doesn't live-update in the `#Preview`.

- [ ] **Step 4: Run the tests — expect PASS.**
- [ ] **Step 5: Commit**
```bash
git add chunky/chunky/Features/Settings/AppSettings.swift chunky/chunkyTests/AppSettingsTests.swift
git commit -m "feat(settings): add UserDefaults-backed AppSettings model"
```

---

## Task 6: CaptureCoordinator — preview, lens toggle, recentFrames (device, build-verified)

**Files:**
- Modify: `chunky/chunky/CaptureKit/Device/CaptureCoordinator.swift`
- Test: none (device glue; build-verified). The pure pieces it exposes are already tested.

**Interfaces:**
- Produces (new on `CaptureCoordinator`):
  - `var previewSession: AVCaptureSession { camera.session }`
  - `func setLens(_ lens: CaptureConfiguration.Lens) async throws`
  - `func recentFrames() -> [Timestamped<CVPixelBuffer>]`
  - `var currentLens: CaptureConfiguration.Lens { config.lens }`

- [ ] **Step 1: Make `config` and `camera` mutable.** Change:
```swift
private let config: CaptureConfiguration
private let camera: CameraCaptureController
```
to
```swift
private var config: CaptureConfiguration
private var camera: CameraCaptureController
```

- [ ] **Step 2: Add the accessors** (after the `disarm()` method, in a new `// MARK: - Live-screen integration` section). `import AVFoundation` is already present via the camera types; add `import AVFoundation` at the top if not.
```swift
    // MARK: - Live-screen integration

    /// The `AVCaptureSession` for attaching an `AVCaptureVideoPreviewLayer`.
    /// Available immediately (before `arm()`); begins delivering frames after arm.
    var previewSession: AVCaptureSession { camera.session }

    /// The lens currently configured.
    var currentLens: CaptureConfiguration.Lens { config.lens }

    /// Snapshot of the ring buffer (most recent frames), for motion-departure
    /// analysis. Thread-safe via the locked buffer.
    func recentFrames() -> [Timestamped<CVPixelBuffer>] {
        lockedBuffer.snapshot()
    }

    /// Switches the capture lens. Recreates the camera controller on the same
    /// frame forwarder (fps/ring-buffer capacity are unchanged), re-arming if the
    /// session was running. `previewSession` changes — the preview view must
    /// re-attach to the new session.
    func setLens(_ lens: CaptureConfiguration.Lens) async throws {
        guard config.lens != lens else { return }
        let wasArmed = isArmed
        if wasArmed { disarm() }
        config.lens = lens
        camera = CameraCaptureController(config: config, receiver: frameForwarder)
        if wasArmed { try await arm() }
    }
```
> `LockedRingBuffer` must expose a `snapshot() -> [Element]`. If it does not, add a method that copies its contents under its `NSLock` (mirror its existing locked-access pattern). Read `CaptureCoordinator.swift`'s `LockedRingBuffer` and add `func snapshot() -> [Element]` returning the buffered elements in order.

- [ ] **Step 3: Build** → `** BUILD SUCCEEDED **`. Confirm the existing `chunkyTests` still pass (nothing in the Core suite depends on these device internals): run `... test -only-testing:chunkyTests`.

- [ ] **Step 4: Commit**
```bash
git add chunky/chunky/CaptureKit/Device/CaptureCoordinator.swift
git commit -m "feat(capture): expose preview session, lens toggle, and ring-buffer snapshot"
```

---

## Task 7: CameraPreviewView (device UIViewRepresentable, build-verified)

**Files:**
- Create: `chunky/chunky/Features/Live/CameraPreviewView.swift`
- Test: none (UIKit/AVFoundation; build-verified; no camera in Simulator).

**Interfaces:**
- Consumes: `AVCaptureSession` (from `CaptureCoordinator.previewSession`).
- Produces: `struct CameraPreviewView: UIViewRepresentable` taking `let session: AVCaptureSession`.

- [ ] **Step 1: Implement**
```swift
// chunky/chunky/Features/Live/CameraPreviewView.swift
import SwiftUI
import AVFoundation

/// Displays a live `AVCaptureSession` via `AVCaptureVideoPreviewLayer`.
/// Re-attaches when the session identity changes (e.g. after a lens switch).
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
```

- [ ] **Step 2: Build** → `** BUILD SUCCEEDED **`. (No `#Preview` — a preview layer needs a live session; a preview would show black. Document this in a comment.)
- [ ] **Step 3: Commit**
```bash
git add chunky/chunky/Features/Live/CameraPreviewView.swift
git commit -m "feat(live): add AVCaptureVideoPreviewLayer SwiftUI wrapper"
```

---

## Task 8: LiveSessionController (view-model, build-verified + logic tests)

**Files:**
- Create: `chunky/chunky/Features/Live/LiveSessionController.swift`
- Test: `chunky/chunkyTests/LiveSessionControllerTests.swift` (the pure decision logic only).

**Interfaces:**
- Consumes: `CaptureCoordinator` (`arm/disarm/onImpactCapture/departureProvider/previewSession/setLens/recentFrames/status`), `ShotPipeline`, `AppSettings`, `ShotStore`, `CalibrationScale`, `Club`, `Session`, `VisionPipeline.makeDepartureProvider`.
- Produces: `@MainActor @Observable final class LiveSessionController` with published-ish state: `private(set) var latestResult: ShotResult?`, `private(set) var latestShot: Shot?`, `var selectedClub: Club?`, `var activeCalibration: CalibrationScale?`, `private(set) var status: CaptureStatus`, `var teeBoxROI: (x:Int,y:Int,w:Int,h:Int)?`; methods `canArm: Bool`, `arm() async`, `disarm()`, `toggleLens() async`, `handleCapture(_:)`, and `attach(store:settings:)`. Also `static func shouldAutoSave(result:club:) -> Bool` (pure, testable).

- [ ] **Step 1: Write the failing test** (pure gating logic — no device)
```swift
// chunky/chunkyTests/LiveSessionControllerTests.swift
import XCTest
@testable import chunky

@MainActor
final class LiveSessionControllerTests: XCTestCase {
    func testCannotArmWithoutClubOrCalibration() {
        let c = LiveSessionController()
        XCTAssertFalse(c.canArm)                 // no club, no calibration
    }
    // Full arm()/capture paths need a device and are validated on-device.
}
```
> Keep this task's automated test minimal — arming requires camera/mic. The value of this task is the wiring; assert only the `canArm` gate here.

- [ ] **Step 2: Run it — expect failure.**

- [ ] **Step 3: Implement**
```swift
// chunky/chunky/Features/Live/LiveSessionController.swift
import Foundation
import Observation

/// Drives the Live screen: owns the capture coordinator, current calibration and
/// club, runs the vision→metrics pipeline on each impact, and auto-saves the
/// resulting shot to the selected club (spec §10 — no manual save step).
@MainActor
@Observable
final class LiveSessionController {
    // Injected
    private var store: ShotStore?
    private var settings: AppSettings?

    // Capture
    private let coordinator: CaptureCoordinator
    private let pipeline = ShotPipeline()
    private let vision = VisionPipeline()

    // State
    private(set) var status: CaptureStatus = .idle
    private(set) var latestResult: ShotResult?
    private(set) var latestShot: Shot?
    private(set) var latestTrackJSON: String?
    var selectedClub: Club?
    var activeCalibration: CalibrationScale?
    var currentSession: Session?
    /// Tee-box region for motion confirmation, in image-pixel coords (y-down).
    var teeBoxROI: (x: Int, y: Int, w: Int, h: Int)?
    var motionActivityThreshold: Double = 0.02

    init(coordinator: CaptureCoordinator = CaptureCoordinator()) {
        self.coordinator = coordinator
    }

    var previewSession: AVCaptureSession { coordinator.previewSession }
    var currentLens: CaptureConfiguration.Lens { coordinator.currentLens }

    func attach(store: ShotStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    /// A club and a calibration are both required before capture can be armed.
    var canArm: Bool { selectedClub != nil && activeCalibration != nil }

    /// Pure: whether a produced result should auto-save (guards against a nil club).
    static func shouldAutoSave(result: ShotResult?, club: Club?) -> Bool {
        result != nil && club != nil
    }

    func arm() async {
        guard canArm else { return }
        coordinator.onImpactCapture = { [weak self] capture in
            self?.handleCapture(capture)
        }
        // Wire motion confirmation from the tee-box ROI, if set.
        if let roi = teeBoxROI {
            coordinator.departureProvider = vision.makeDepartureProvider(
                recentFrames: { [weak coordinator] in coordinator?.recentFrames() ?? [] },
                roi: roi, activityThreshold: motionActivityThreshold)
        } else {
            coordinator.departureProvider = nil   // audio-only
        }
        do { try await coordinator.arm() } catch { status = .failed("\(error)") ; return }
        status = coordinator.status
    }

    func disarm() {
        coordinator.disarm()
        status = .idle
    }

    func toggleLens() async {
        let next: CaptureConfiguration.Lens = coordinator.currentLens == .telephoto ? .wide : .telephoto
        try? await coordinator.setLens(next)
        settings?.lens = next == .telephoto ? .telephoto : .wide
    }

    /// Runs vision→metrics on the captured window and auto-saves the shot.
    func handleCapture(_ capture: ImpactCapture) {
        guard let calibration = activeCalibration,
              let club = selectedClub,
              let settings else { return }
        guard let out = pipeline.output(from: capture, calibration: calibration,
                                        atmosphere: settings.atmosphere,
                                        modeledSpinRPM: club.modeledSpinRPM) else { return }
        latestResult = out.result
        latestTrackJSON = out.rawTrackJSON
        guard Self.shouldAutoSave(result: out.result, club: club), let store else { return }
        latestShot = try? store.saveShot(out.result, to: club, session: currentSession,
                                         rawTrackJSON: out.rawTrackJSON)
    }
}
import AVFoundation
```
> Place the `import AVFoundation` at the top of the file (shown at the bottom here only for brevity). If `@Observable` + `weak coordinator` capture warns, capture `self` weakly and read `self?.coordinator`.

- [ ] **Step 4: Run the test — expect PASS. Build the app** → `** BUILD SUCCEEDED **`.
- [ ] **Step 5: Commit**
```bash
git add chunky/chunky/Features/Live/LiveSessionController.swift chunky/chunkyTests/LiveSessionControllerTests.swift
git commit -m "feat(live): add LiveSessionController driving pipeline + auto-save"
```

---

## Task 9: Calibrate screen (SwiftUI, build + #Preview)

**Files:**
- Create: `chunky/chunky/Features/Calibrate/CalibrateView.swift`
- Test: none automated; ships a `#Preview`.

**Interfaces:**
- Consumes: `CameraPreviewView`, `LiveSessionController` (for `previewSession`, `recentFrames` via coordinator — expose a `latestFrame()` helper if needed), `MarkerDetector.detectCorners(in:) async -> [Vec2]?`, `DeviceAttitude` (`start/stop`, `imagePlaneGravity`), `CalibrationMath.calibrationScale(markerCornersPx:markerSideMeters:imagePlaneGravity:)` and the manual `calibrationScale(pointA:pointB:knownLengthMeters:imagePlaneGravity:)`, `CalibrationProfileMapping`, `ShotStore.context` (to insert the `CalibrationProfile`), `Theme`.
- Produces: `struct CalibrateView: View` presented as a sheet; on confirm calls a `onCalibrated: (CalibrationScale) -> Void` closure and dismisses.

- [ ] **Step 1: Implement** the screen with two modes (segmented control):
  - **Marker auto-detect:** a `TextField` for marker side length in mm (default 150). A "Detect" button grabs the latest frame (`LiveSessionController.latestFrame()` — add a helper that returns `coordinator.recentFrames().last?.value`), runs `await MarkerDetector().detectCorners(in:)`, and on 4 corners builds `CalibrationMath.calibrationScale(markerCornersPx: corners, markerSideMeters: mm/1000, imagePlaneGravity: attitude.imagePlaneGravity ?? Vec2(0,1))`. Show a green "Scale locked — N px/m" indicator (`Theme.optic`) on success, red guidance (`Theme.flag`) on failure.
  - **Manual:** instruct the user to tap two points on the frozen preview a known distance apart; a `TextField` for the known length (m). Capture two tap locations (`DragGesture`/`onTapGesture` with `GeometryReader`), convert view points to image-pixel coordinates using the preview layer's `captureDevicePointConverted`/`layerPointConverted` (device-only; build-verified), then `CalibrationMath.calibrationScale(pointA:pointB:knownLengthMeters:imagePlaneGravity:)`.
  - **Confirm** persists a `CalibrationProfile` via `CalibrationProfileMapping.profile(from:lens:createdAt:)` inserted into `store.context` (`context.insert`; `try? context.save()`), calls `onCalibrated(scale)`, and dismisses.
  - Start `DeviceAttitude` in `.onAppear`, stop in `.onDisappear`.
- Use `Theme` tokens throughout (`rangeDusk` background, `turf` cards, `chalk` text, `optic` accent, `Theme.display/number/eyebrow`). Keep the "scale locked" state the signature element.

- [ ] **Step 2: Add a `#Preview`** that renders `CalibrateView` in a static "no camera" state (guard the preview against a nil session by showing a placeholder rectangle where `CameraPreviewView` would be). Build → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Commit**
```bash
git add chunky/chunky/Features/Calibrate/CalibrateView.swift
git commit -m "feat(calibrate): add marker + manual calibration sheet"
```
> If `LiveSessionController` needs a `latestFrame()` helper, add it there in this task and note it in the commit.

---

## Task 10: Result card + tee-box overlay (SwiftUI, build + #Preview)

**Files:**
- Create: `chunky/chunky/Features/Live/ResultCardView.swift`, `chunky/chunky/Features/Live/TeeBoxOverlay.swift`
- Test: none automated; each ships a `#Preview`.

**Interfaces:**
- Consumes: `ShotResult`, `Shot`, `Units`, `Theme`, `ShotStore` (`setExcluded`, `deleteShots`).
- Produces:
  - `struct ResultCardView: View` — inputs `result: ShotResult`, `shot: Shot?`, `units: Units`, `onExclude: () -> Void`, `onDelete: () -> Void`.
  - `struct TeeBoxOverlay: View` — a draggable/resizable rectangle producing a normalized ROI binding `@Binding var roi: CGRect` in 0…1 view space.

- [ ] **Step 1: Implement `ResultCardView`** — carry is the dominant element (`Theme.number(64)`, `Theme.confidenceColor(result.confidence)`), with `units.formattedCarry(fromMeters: result.carryMeters)`. A confidence chip (`result.confidence.rawValue`, color-coded). A disclosure/expand reveals ball speed (`result.ballSpeedMPH` mph), launch angle (`result.launchAngleDeg`°), spin (`result.spinRPM` rpm + `result.spinSource.rawValue`). Two one-tap buttons: **Exclude (mishit)** (`Theme.amber`) and **Delete** (`Theme.flag`) calling the closures. Confidence is always visible.
- [ ] **Step 2: Implement `TeeBoxOverlay`** — a rectangle with drag-to-move and corner drag-to-resize over a `GeometryReader`, writing a normalized `CGRect` back through the binding; styled with a dashed `Theme.optic` stroke and an "TEE BOX" eyebrow label.
- [ ] **Step 3: Add `#Preview`s** for both (feed `ResultCardView` a sample `ShotResult`; `TeeBoxOverlay` a `@Previewable @State` rect). Build → `** BUILD SUCCEEDED **`.
- [ ] **Step 4: Commit**
```bash
git add chunky/chunky/Features/Live/ResultCardView.swift chunky/chunky/Features/Live/TeeBoxOverlay.swift
git commit -m "feat(live): add result card and tee-box ROI overlay"
```

---

## Task 11: Live/Range screen (SwiftUI, build + #Preview)

**Files:**
- Create: `chunky/chunky/Features/Live/LiveView.swift`
- Test: none automated; ships a `#Preview`.

**Interfaces:**
- Consumes: `LiveSessionController`, `AppSettings` (`@Environment`), `ShotStore` (`@Environment(\.shotStore)`), `Club` (via `@Query` for the club selector), `CameraPreviewView`, `TeeBoxOverlay`, `ResultCardView`, `CalibrateView` (sheet), `DebugOverlayView` (Task 12), `CaptureStatus`, `Theme`.
- Produces: `struct LiveView: View`.

- [ ] **Step 1: Implement** the screen:
  - Full-bleed `CameraPreviewView(session: controller.previewSession)` with `TeeBoxOverlay` on top (writes `controller.teeBoxROI` — convert the normalized rect to image pixels using the active format dimensions; for build-verify, store normalized and convert at arm time).
  - A **club selector** (`Menu`/`Picker` over `@Query(filter: #Predicate { !$0.isArchived })` clubs sorted by `order`) bound to `controller.selectedClub`. Prominent; when nil, show "Select a club" and disable Arm.
  - A **Calibrate** button opening `CalibrateView` as a `.sheet`; on `onCalibrated`, set `controller.activeCalibration` and show a small "scale locked" badge.
  - A **lens toggle** button (`controller.currentLens`), calling `await controller.toggleLens()`.
  - A **light warning** banner when `controller.status == .needsMoreLight` (`Theme.amber`, "More light needed"), and permission/failure banners for `.unauthorized`/`.failed` (`Theme.flag`).
  - An **Arm/Disarm** button, disabled unless `controller.canArm`; label reflects state. Arming calls `await controller.arm()`.
  - When `controller.latestResult != nil`, present `ResultCardView` over the bottom of the screen with `onExclude`/`onDelete` wired to `store.setExcluded(shot, true)` / `store.deleteShots([shot])` using `controller.latestShot`.
  - If `settings.debugOverlayEnabled` and a track is present, offer a "Debug" affordance to present `DebugOverlayView`.
  - Create the `currentSession` on first arm: insert a `Session(date: Date(), lens: settings.lens, temperatureC: settings.temperatureC, altitudeM: settings.altitudeM, humidity: settings.humidity, calibrationProfileId: nil)` into `store.context`, assign to `controller.currentSession`. Call `controller.attach(store:settings:)` in `.task`/`.onAppear`.
  - Copy: empty state before first shot is an invitation ("Select a club, calibrate, then arm.").
- Use `Theme` tokens; carry (via the result card) is the largest element; confidence always visible.

- [ ] **Step 2: Add a `#Preview`** that injects an in-memory `ModelContainer` (see chunkyApp schema) + an `AppSettings(defaults:)` on a throwaway suite, and a `LiveSessionController`; show the non-camera chrome (the preview will show a placeholder for the camera). Build → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Commit**
```bash
git add chunky/chunky/Features/Live/LiveView.swift
git commit -m "feat(live): add Live/Range capture screen"
```

---

## Task 12: Debug overlay (SwiftUI, build + #Preview)

**Files:**
- Create: `chunky/chunky/Features/Live/DebugOverlayView.swift`
- Test: none automated; ships a `#Preview`.

**Interfaces:**
- Consumes: `[TrackPoint]` (decode `controller.latestTrackJSON` via `ShotTrackCodec`), `ShotResult`, `CalibrationScale`, `Theme`.
- Produces: `struct DebugOverlayView: View` — inputs `track: [TrackPoint]`, `result: ShotResult`, `calibration: CalibrationScale`.

- [ ] **Step 1: Implement** — a `Canvas`/`GeometryReader` that plots the track's `pixel` positions (auto-scaled to the view bounds), draws the fitted launch velocity vector (from the first `usedFrameCount` points), and lists per-frame centroids plus the computed metrics (v0 mph, θ°, px/m, frame count, RMS residual `result.fitRmsResidualMeters`). This is the field-tuning surface (spec §11.8, §14).
- [ ] **Step 2: Add a `#Preview`** with a synthetic track + sample `ShotResult`. Build → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Commit**
```bash
git add chunky/chunky/Features/Live/DebugOverlayView.swift
git commit -m "feat(live): add debug overlay for track + metrics"
```

---

## Task 13: Settings + Session summary screens (SwiftUI, build + #Preview)

**Files:**
- Create: `chunky/chunky/Features/Settings/SettingsView.swift`, `chunky/chunky/Features/Session/SessionSummaryView.swift`
- Test: none automated; each ships a `#Preview`.

**Interfaces:**
- Consumes: `AppSettings` (`@Environment`), `Units`, `CameraLens`, `Session`, `Shot`, `ShotStore.record(from:)`, `ClubAggregates.compute(from:)`, `CSVExport.shots(_:units:)`, `Theme`.
- Produces: `struct SettingsView: View`, `struct SessionSummaryView: View` (inputs `session: Session`).

- [ ] **Step 1: Implement `SettingsView`** — a `Form` with: units `Picker` (`Units.allCases`), environment inputs (temperature °C, altitude m, humidity % as `TextField`/`Stepper` bound to `settings.temperatureC/altitudeM/humidity`), lens default `Picker` (`CameraLens.allCases`), and a debug-overlay `Toggle` (`settings.debugOverlayEnabled`). Style with `Theme`.
- [ ] **Step 2: Implement `SessionSummaryView`** — list the session's shots (map `session.shots` → `ShotStore.record(from:)`), show quick stats via `ClubAggregates.compute(from: records)` (count, mean/median carry using `settings.units`), and a **CSV Export** button that builds `CSVExport.shots(records, units: settings.units)` and presents a `ShareLink`/share sheet with the CSV as a file.
- [ ] **Step 3: Add `#Preview`s** (in-memory container + sample data + `AppSettings`). Build → `** BUILD SUCCEEDED **`.
- [ ] **Step 4: Commit**
```bash
git add chunky/chunky/Features/Settings/SettingsView.swift chunky/chunky/Features/Session/SessionSummaryView.swift
git commit -m "feat(ui): add Settings and Session summary screens with CSV export"
```

---

## Task 14: RootView + app integration (SwiftUI, build + #Preview)

**Files:**
- Modify: `chunky/chunky/Features/RootView.swift`, `chunky/chunky/chunkyApp.swift`
- Test: none automated; RootView keeps/gains a `#Preview`.

**Interfaces:**
- Consumes: `LiveView`, `SettingsView`, `AppSettings`, existing `AveragesView`/`HistoryView`/`ClubsView`, `Theme`.
- Produces: updated `RootView` tab set and an `AppSettings` injected at the app root.

- [ ] **Step 1: Inject `AppSettings` at the app root.** In `chunkyApp.swift`, add `@State private var appSettings = AppSettings()` and `.environment(appSettings)` on `RootView()` (alongside `.modelContainer(...)`).
- [ ] **Step 2: Update `RootView`** — add **Live** as the first/primary tab and **Settings** as the last tab; keep Averages, History, Clubs. Provide the `LiveSessionController` via `@State` in `RootView` and pass it to `LiveView` (so it survives tab switches). Read `@Environment(AppSettings.self)`. Final tab order: Live (`scope`/`camera.viewfinder`), Averages, History, Clubs, Settings (`gearshape.fill`). Keep the existing `.environment(\.shotStore, ShotStore(context: modelContext))`, `.tint(Theme.optic)`, `.background(Theme.rangeDusk)`.
```swift
// sketch — match existing style
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var appSettings
    @State private var live = LiveSessionController()

    var body: some View {
        TabView {
            NavigationStack { LiveView(controller: live) }
                .tabItem { Label("Live", systemImage: "camera.viewfinder") }
            NavigationStack { AveragesView() }
                .tabItem { Label("Averages", systemImage: "chart.bar.fill") }
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "list.bullet") }
            NavigationStack { ClubsView() }
                .tabItem { Label("Clubs", systemImage: "bag.fill") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .environment(\.shotStore, ShotStore(context: modelContext))
        .tint(Theme.optic)
        .background(Theme.rangeDusk)
    }
}
```
- [ ] **Step 3: Update the `#Preview`** to provide the in-memory container and `.environment(AppSettings(defaults:))`. Build → `** BUILD SUCCEEDED **`.
- [ ] **Step 4: Commit**
```bash
git add chunky/chunky/Features/RootView.swift chunky/chunky/chunkyApp.swift
git commit -m "feat(app): add Live and Settings tabs; inject AppSettings"
```

---

## Task 15: Green gate, purity guards & on-device acceptance checklist

**Files:**
- Create: `docs/live-ondevice-acceptance.md`
- Test: full suite (verification only).

- [ ] **Step 1: Full unit suite** — `... test -only-testing:chunkyTests 2>&1 | tail -30` → `** TEST SUCCEEDED **` (all prior tests + Tasks 1–5/8 new tests; the only permitted failure is the known pre-existing `ClubsSmokeUITests` XCUITest IPC failure, out of scope).
- [ ] **Step 2: Full build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Purity guards** — run and expect all OK lines:
```bash
cd /Users/kason/Documents/github/Chunky && \
( ! grep -rEl "import (Vision|CoreVideo|CoreMotion|AVFoundation|AVFAudio|SwiftUI|SwiftData)" chunky/chunky/Ballistics/ chunky/chunky/Metrics/ && echo "OK: Ballistics+Metrics stay pure" ) ; \
( ! grep -rEl "import (Vision|CoreVideo|CoreMotion|AVFoundation|AVFAudio)" chunky/chunky/DataStore/ && echo "OK: DataStore free of capture frameworks" ) ; \
( ! grep -rEl "import (Vision|AVFoundation)" chunky/chunky/VisionCore/Core/ chunky/chunky/Calibration/Core/ && echo "OK: Vision/Calibration Core still device-free" )
```
> `DataStore` may import `SwiftData`/`SwiftUI`-free Foundation; it must NOT import capture frameworks. `ShotPipeline` (Orchestration) importing CoreVideo is expected and correct — it is not under the guarded paths.

- [ ] **Step 4: Write `docs/live-ondevice-acceptance.md`** — the human on-device checklist mirroring `docs/capturekit-ondevice-acceptance.md` and `docs/visioncore-ondevice-acceptance.md`, covering spec Phase 1 acceptance: (a) calibrate (marker + manual) and confirm "scale locked" + sane px/m; (b) select a club (arming blocked until a club AND calibration are set); (c) hit 20 shots and confirm each auto-saves to the selected club and a result card shows carry + confidence in one glance; (d) **ball speed within ±3% and launch angle within ±1.0°** vs a reference monitor across 20 shots; (e) exclude and delete from the result card update averages immediately; (f) the debug overlay shows the track + fitted velocity + px/m; (g) lens toggle and "more light" warning behave; (h) CSV export produces a valid file. Include a field-tuning table (detector threshold/minArea/minCircularity, tee-box ROI, motion threshold) and a sign-off table.
- [ ] **Step 5: Commit**
```bash
git add docs/live-ondevice-acceptance.md
git commit -m "docs(live): add Phase-1 on-device acceptance checklist"
```

---

## Self-Review

**1. Spec coverage:**
- §11.1 Range/Live screen (preview, ROI, lens toggle, light warning, mandatory club selector, result card with expand + exclude/delete) → Tasks 7, 10, 11. ✅
- §11.5 Calibrate sheet (marker + manual, "scale locked") → Tasks 2, 3, 9. ✅
- §11.6 Session summary + CSV export → Task 13. ✅
- §11.7 Settings (units, environment inputs, lens default, debug toggle) → Tasks 5, 13. ✅
- §11.8 Debug overlay (track, centroids, velocity vector, scale, metrics) → Task 12. ✅
- §9 orchestration frames→v0/θ→carry (`ShotResult`) → Task 4 (reuses `Metrics.computeShot`). ✅
- §10 auto-save per club, raw track persisted → Tasks 1, 4, 8. ✅ (History/Averages/Clubs management already shipped in Plan 3.)
- §6 calibration produces `CalibrationProfile` (px/m + gravity vertical) → Tasks 3, 9. ✅
- §5.4 motion-confirmation fallback wired from the tee-box ROI → Tasks 6, 8 (build-verified; on-device-tunable). ✅
- Phase 1 acceptance (±3% speed, ±1° launch) → Task 15 checklist (on-device). ✅
- Out of scope (later plans): measured spin (SpinCore, Phase 3), club speed/smash (Phase 3.5), dual-camera/Core ML (Phase 4), camera-intrinsics undistortion.

**2. Placeholder scan:** Pure tasks (1–5, 8-gate) carry full test + implementation code. Device/UI tasks specify exact types, wiring, and the concrete APIs to call, with `#Preview` + build gates — no "TODO" stubs. The one soft spot (synthetic-buffer geometry in Task 4) is called out with explicit tuning guidance and a fallback.

**3. Type consistency:** `ShotPipeline.Output`, `LiveSessionController` state, `AppSettings.atmosphere/captureLens`, `CalibrationProfileMapping`, and `ShotTrackCodec` all use the verified signatures from the interface digest (`Metrics.computeShot`, `ShotStore.saveShot`, `CaptureCoordinator.arm/disarm/onImpactCapture/departureProvider`, `VisionPipeline.track/makeDepartureProvider`, `MarkerDetector.detectCorners`, `CalibrationMath.calibrationScale`, `Club.modeledSpinRPM`, `Session` init, `CalibrationProfile` init, `Units`, `CSVExport`, `ClubAggregates`, `Theme`). New members added to existing types (Codable on `Vec2`/`TrackPoint`; `previewSession`/`setLens`/`recentFrames` on `CaptureCoordinator`; `snapshot()` on `LockedRingBuffer`) are introduced in the task that first needs them and consumed by name thereafter.
