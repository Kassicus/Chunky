# Foundation & Ballistics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the Chunky Xcode project to the spec's platform requirements and build the pure, deterministic `Ballistics` module (RK4 trajectory integrator + Cd/Cl aero tables + air-density helper) with tests that reproduce published reference carries within ±3%.

**Architecture:** Ballistics lives in `chunky/chunky/Ballistics/` as pure Swift value types (no AVFoundation/Vision/SwiftUI/SwiftData imports). The build uses Xcode's file-system-synchronized groups, so files added on disk are compiled automatically — no `.pbxproj` file-reference edits. Math types are declared `nonisolated` so they stay callable from the (non-MainActor) test target under Swift 6. Tests run in the `chunkyTests` target via `@testable import chunky` in the iOS Simulator with no camera or device dependency.

**Tech Stack:** Swift 6, Xcode 26.5 toolchain, iOS 26.5 deployment target, XCTest. No third-party dependencies.

## Roadmap (this plan is #1 of a sequence — one plan per spec phase)

Per the spec's "build strictly in phase order, each phase independently testable," the work is decomposed into a sequence of self-contained plans. This document is **Plan 1**. Subsequent plans are written when their predecessor is green:

1. **Foundation & Ballistics** ← *this plan* (spec §3.2, §16 "first deliverable")
2. **Metrics** — pure centroid-track → v0/θ/azimuth, modeled-spin table, `ShotResult` + confidence (spec §9, §3.3)
3. **DataStore + Club/History/Averages/CSV** — SwiftData models & reactive aggregates (spec §10, §11.2–4, Phase 2 data features)
4. **CaptureKit** — device config, short-shutter exposure, 240fps, ring buffer, audio trigger (spec §5, Phase 0)
5. **VisionCore + Calibration** — classical CV ball detection/tracking, scale calibration (spec §6, §7, Phase 1)
6. **Live UI end-to-end** — wire capture→vision→metrics→carry→save (spec §11.1, Phase 2 field carry)
7. **SpinCore** — measured spin on marked balls (spec §8, Phase 3)
8. **Clubhead & smash factor** — opportunistic pre-impact tracking (spec §3.4, Phase 3.5)
9. **Dual-camera & Core ML upgrade** — optional (spec §4-note, Phase 4)

---

**Goal:** (see above)

**Architecture:** (see above)

**Tech Stack:** (see above)

## Global Constraints

Copied verbatim from `reference/GolfCarryMonitor_BuildSpec.md`. Every task below implicitly includes these.

- **Deployment target:** iOS 26.5 (already set; keep). Spec floor was iOS 18.0 — the repo already exceeds it.
- **Swift language version:** Swift 6.
- **Device family:** iPhone only (`TARGETED_DEVICE_FAMILY = "1"`). iPad is an explicit non-goal.
- **Dependency rule:** `Ballistics` must NOT import AVFoundation, Vision, CoreML, SwiftUI, or SwiftData. `import Foundation` only where math needs `pow`/`exp` (`Vec3` needs nothing). Enforced by discipline (grouped folders, not separate SPM targets yet).
- **No third-party dependencies.**
- **Units:** SI internally — meters, m/s, kg, radians, seconds. Convert to mph/yards only at boundaries via the `Conversions` helper.
- **Concurrency:** the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. All Ballistics types are declared `nonisolated` so they are callable from the non-MainActor test target and from any future background queue.
- **Ball constants (spec §3.2):** mass `m = 0.04593 kg`, diameter `d = 0.04267 m`, area `A = π(d/2)²`, `g = 9.81 m/s²`.
- **Integrator (spec §3.2):** RK4, fixed `dt = 1 ms`, integrate from launch height until the ball returns to launch height; **carry** = horizontal distance at that point.
- **Air density default (spec §3.2):** sea level / 15 °C = 1.225 kg/m³.
- **Process:** TDD (red→green), frequent commits, DRY, YAGNI.

## File Structure

```
chunky/chunky/Ballistics/
├─ Vec3.swift            // pure 3D vector value type (no imports)
├─ Conversions.swift     // mph/yard ↔ SI helpers
├─ AirDensity.swift      // ISA-based air density from temp/altitude/humidity
├─ AeroTable.swift       // Cd/Cl vs spin ratio, interpolation + JSON decode
├─ BallModel.swift       // mass/diameter/area constants
├─ LaunchConditions.swift// input value type (v0, θ, azimuth, spin, axis tilt)
├─ Trajectory.swift      // output value type (carry, flight time, apex, points)
└─ Ballistics.swift      // integrate(): RK4 with drag + Magnus

chunky/chunky/Resources/
└─ aero_tables.json      // shipped default Cd/Cl table (mirrors AeroTable.standard)

chunky/chunkyTests/
├─ Vec3Tests.swift
├─ ConversionsTests.swift
├─ AirDensityTests.swift
├─ AeroTableTests.swift
├─ BallisticsIntegratorTests.swift      // analytical + numeric sanity
└─ BallisticsReferenceCarryTests.swift  // published driver/7-iron carries ±3%
```

---

### Task 1: Align project configuration to spec

**Files:**
- Modify: `chunky/chunky.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: nothing.
- Produces: Swift 6 + iPhone-only build with camera/mic Info.plist keys, on which all later tasks compile.

This task is configuration, not code, so it has no failing unit test; its deliverable is verified by a clean build and a settings grep.

- [ ] **Step 1: Set Swift language version to 6**

Edit `project.pbxproj` — replace **all** occurrences of:

```
				SWIFT_VERSION = 5.0;
```

with:

```
				SWIFT_VERSION = 6.0;
```

(6 occurrences: Debug+Release of chunky, chunkyTests, chunkyUITests.)

- [ ] **Step 2: Set device family to iPhone-only**

Edit `project.pbxproj` — replace **all** occurrences of:

```
				TARGETED_DEVICE_FAMILY = "1,2";
```

with:

```
				TARGETED_DEVICE_FAMILY = "1";
```

(6 occurrences.)

- [ ] **Step 3: Add camera & microphone usage descriptions**

Edit `project.pbxproj` — replace **all** occurrences of:

```
					INFOPLIST_KEY_UILaunchScreen_Generation = YES;
```

with:

```
					INFOPLIST_KEY_NSCameraUsageDescription = "Chunky uses the camera to measure your golf ball's launch.";
					INFOPLIST_KEY_NSMicrophoneUsageDescription = "Chunky listens for club-ball impact to detect each shot.";
					INFOPLIST_KEY_UILaunchScreen_Generation = YES;
```

(This anchor line appears exactly twice — the app target's Debug and Release configs — so both get the keys; the test targets are untouched.)

- [ ] **Step 4: Verify settings applied**

Run:

```bash
cd /Users/kason/Documents/github/Chunky && \
grep -c "SWIFT_VERSION = 6.0;" chunky/chunky.xcodeproj/project.pbxproj && \
grep -c 'TARGETED_DEVICE_FAMILY = "1";' chunky/chunky.xcodeproj/project.pbxproj && \
grep -c "INFOPLIST_KEY_NSCameraUsageDescription" chunky/chunky.xcodeproj/project.pbxproj
```

Expected output: `6`, then `6`, then `2`.

- [ ] **Step 5: Verify the project still builds**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. (If no iPhone 17 Pro Max simulator exists, substitute any available iOS 26 simulator name from `xcrun simctl list devices available`.)

- [ ] **Step 6: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky.xcodeproj/project.pbxproj && \
git commit -m "chore: align project to spec (Swift 6, iPhone-only, camera/mic keys)"
```

---

### Task 2: Vec3 value type

**Files:**
- Create: `chunky/chunky/Ballistics/Vec3.swift`
- Test: `chunky/chunkyTests/Vec3Tests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `nonisolated struct Vec3` with `init(_ x: Double, _ y: Double, _ z: Double)`, `static let zero`, operators `+`, `-`, `*(Double, Vec3)`, `*(Vec3, Double)`, and members `var magnitude: Double`, `func dot(_:) -> Double`, `func cross(_:) -> Vec3`, `var normalized: Vec3`. World frame: +x downrange, +y up, +z right.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/Vec3Tests.swift
import XCTest
@testable import chunky

final class Vec3Tests: XCTestCase {
    func testMagnitude() {
        XCTAssertEqual(Vec3(3, 4, 0).magnitude, 5, accuracy: 1e-12)
    }

    func testAddSubtract() {
        XCTAssertEqual(Vec3(1, 2, 3) + Vec3(4, 5, 6), Vec3(5, 7, 9))
        XCTAssertEqual(Vec3(4, 5, 6) - Vec3(1, 2, 3), Vec3(3, 3, 3))
    }

    func testScalarMultiplyBothOrders() {
        XCTAssertEqual(2.0 * Vec3(1, 2, 3), Vec3(2, 4, 6))
        XCTAssertEqual(Vec3(1, 2, 3) * 2.0, Vec3(2, 4, 6))
    }

    func testDot() {
        XCTAssertEqual(Vec3(1, 2, 3).dot(Vec3(4, 5, 6)), 32, accuracy: 1e-12)
    }

    func testCrossRightHanded() {
        // x cross y = z
        XCTAssertEqual(Vec3(1, 0, 0).cross(Vec3(0, 1, 0)), Vec3(0, 0, 1))
        // z cross x = y   (backspin axis +z, velocity +x → lift +y)
        XCTAssertEqual(Vec3(0, 0, 1).cross(Vec3(1, 0, 0)), Vec3(0, 1, 0))
    }

    func testNormalized() {
        let n = Vec3(0, 3, 0).normalized
        XCTAssertEqual(n.x, 0, accuracy: 1e-12)
        XCTAssertEqual(n.y, 1, accuracy: 1e-12)
        XCTAssertEqual(n.z, 0, accuracy: 1e-12)
    }

    func testNormalizedZeroIsZero() {
        XCTAssertEqual(Vec3.zero.normalized, Vec3.zero)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/Vec3Tests 2>&1 | tail -15
```

Expected: build failure — `cannot find 'Vec3' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// chunky/chunky/Ballistics/Vec3.swift
// Pure 3D vector for ballistics math. No Apple frameworks.
// World frame: +x downrange (toward target), +y up, +z to the right.

nonisolated struct Vec3: Equatable {
    var x: Double
    var y: Double
    var z: Double

    init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    static let zero = Vec3(0, 0, 0)

    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func * (s: Double, v: Vec3) -> Vec3 { Vec3(s * v.x, s * v.y, s * v.z) }
    static func * (v: Vec3, s: Double) -> Vec3 { s * v }

    var magnitude: Double { (x * x + y * y + z * z).squareRoot() }

    func dot(_ o: Vec3) -> Double { x * o.x + y * o.y + z * o.z }

    func cross(_ o: Vec3) -> Vec3 {
        Vec3(
            y * o.z - z * o.y,
            z * o.x - x * o.z,
            x * o.y - y * o.x
        )
    }

    /// Unit vector; a zero-length vector normalizes to zero.
    var normalized: Vec3 {
        let m = magnitude
        return m > 0 ? (1.0 / m) * self : .zero
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/Vec3Tests 2>&1 | tail -15
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Ballistics/Vec3.swift chunky/chunkyTests/Vec3Tests.swift && \
git commit -m "feat(ballistics): add Vec3 pure vector type"
```

---

### Task 3: Unit conversions

**Files:**
- Create: `chunky/chunky/Ballistics/Conversions.swift`
- Test: `chunky/chunkyTests/ConversionsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `nonisolated enum Conversions` with `static func mphToMS(_:) -> Double`, `msToMPH(_:) -> Double`, `yardsToMeters(_:) -> Double`, `metersToYards(_:) -> Double`, `rpmToRadPerSec(_:) -> Double`, `degToRad(_:) -> Double`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ConversionsTests.swift
import XCTest
@testable import chunky

final class ConversionsTests: XCTestCase {
    func testMphMs() {
        XCTAssertEqual(Conversions.mphToMS(100), 44.704, accuracy: 1e-9)
        XCTAssertEqual(Conversions.msToMPH(44.704), 100, accuracy: 1e-9)
    }

    func testYardsMeters() {
        XCTAssertEqual(Conversions.yardsToMeters(100), 91.44, accuracy: 1e-9)
        XCTAssertEqual(Conversions.metersToYards(91.44), 100, accuracy: 1e-9)
    }

    func testRpmToRadPerSec() {
        // 60 rpm = 1 rev/s = 2π rad/s
        XCTAssertEqual(Conversions.rpmToRadPerSec(60), 2 * .pi, accuracy: 1e-12)
    }

    func testDegToRad() {
        XCTAssertEqual(Conversions.degToRad(180), .pi, accuracy: 1e-12)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/ConversionsTests 2>&1 | tail -15
```

Expected: `cannot find 'Conversions' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// chunky/chunky/Ballistics/Conversions.swift
import Foundation

nonisolated enum Conversions {
    static let mphPerMS = 2.2369362920544
    static let metersPerYard = 0.9144

    static func mphToMS(_ mph: Double) -> Double { mph / mphPerMS }
    static func msToMPH(_ ms: Double) -> Double { ms * mphPerMS }
    static func yardsToMeters(_ yd: Double) -> Double { yd * metersPerYard }
    static func metersToYards(_ m: Double) -> Double { m / metersPerYard }
    static func rpmToRadPerSec(_ rpm: Double) -> Double { rpm * 2 * .pi / 60 }
    static func degToRad(_ deg: Double) -> Double { deg * .pi / 180 }
}
```

Note: `mphToMS(100)` = `100 / 2.2369362920544` = `44.70400000…` — matches the test's `44.704`.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/ConversionsTests 2>&1 | tail -15
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Ballistics/Conversions.swift chunky/chunkyTests/ConversionsTests.swift && \
git commit -m "feat(ballistics): add unit conversion helpers"
```

---

### Task 4: Air density (ISA helper)

**Files:**
- Create: `chunky/chunky/Ballistics/AirDensity.swift`
- Test: `chunky/chunkyTests/AirDensityTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `nonisolated enum AirDensity` with `static func pressure(altitudeM:) -> Double` (Pa) and `static func density(temperatureC:altitudeM:relativeHumidity:) -> Double` (kg/m³, humidity defaults to 0).

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/AirDensityTests.swift
import XCTest
@testable import chunky

final class AirDensityTests: XCTestCase {
    func testSeaLevelStandardIs1225() {
        // Spec default: sea level / 15 °C = 1.225 kg/m³
        let rho = AirDensity.density(temperatureC: 15, altitudeM: 0)
        XCTAssertEqual(rho, 1.225, accuracy: 0.001)
    }

    func testWarmerAirIsThinner() {
        let cool = AirDensity.density(temperatureC: 5, altitudeM: 0)
        let warm = AirDensity.density(temperatureC: 35, altitudeM: 0)
        XCTAssertLessThan(warm, cool)
    }

    func testAltitudeThinsAir() {
        let sea = AirDensity.density(temperatureC: 15, altitudeM: 0)
        let mile = AirDensity.density(temperatureC: 15, altitudeM: 1609)
        XCTAssertLessThan(mile, sea)
        // Denver-ish: roughly ~0.84x sea-level density at constant temperature.
        XCTAssertEqual(mile / sea, 0.84, accuracy: 0.03)
    }

    func testHumidAirIsSlightlyThinner() {
        let dry = AirDensity.density(temperatureC: 30, altitudeM: 0, relativeHumidity: 0)
        let humid = AirDensity.density(temperatureC: 30, altitudeM: 0, relativeHumidity: 1)
        XCTAssertLessThan(humid, dry)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/AirDensityTests 2>&1 | tail -15
```

Expected: `cannot find 'AirDensity' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// chunky/chunky/Ballistics/AirDensity.swift
import Foundation

/// Air density from temperature, altitude, and humidity using the International
/// Standard Atmosphere for pressure and the ideal gas law for density.
nonisolated enum AirDensity {
    static let seaLevelPressurePa = 101325.0
    static let seaLevelTempK = 288.15
    static let lapseRateKPerM = 0.0065
    static let gravity = 9.80665
    static let molarMassDryAir = 0.0289644          // kg/mol
    static let universalGasConstant = 8.31446       // J/(mol·K)
    static let gasConstantDryAir = 287.058          // J/(kg·K)
    static let gasConstantWaterVapor = 461.495      // J/(kg·K)

    /// ISA tropospheric pressure (Pa) at altitude (m).
    static func pressure(altitudeM: Double) -> Double {
        let exponent = gravity * molarMassDryAir / (universalGasConstant * lapseRateKPerM)
        let base = 1.0 - (lapseRateKPerM * altitudeM) / seaLevelTempK
        return seaLevelPressurePa * pow(base, exponent)
    }

    /// Air density (kg/m³). `relativeHumidity` is 0…1.
    static func density(temperatureC: Double, altitudeM: Double, relativeHumidity: Double = 0) -> Double {
        let tempK = temperatureC + 273.15
        let totalPressure = pressure(altitudeM: altitudeM)
        // Tetens saturation vapor pressure (Pa).
        let satVaporPa = 610.78 * pow(10.0, (7.5 * temperatureC) / (temperatureC + 237.3))
        let vaporPa = max(0, min(1, relativeHumidity)) * satVaporPa
        let dryPa = totalPressure - vaporPa
        return dryPa / (gasConstantDryAir * tempK)
            + vaporPa / (gasConstantWaterVapor * tempK)
    }
}
```

Sanity: `density(15, 0, 0)` = `101325 / (287.058 × 288.15)` = `1.2250 kg/m³`.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/AirDensityTests 2>&1 | tail -15
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Ballistics/AirDensity.swift chunky/chunkyTests/AirDensityTests.swift && \
git commit -m "feat(ballistics): add ISA air-density helper"
```

---

### Task 5: Aero table (Cd/Cl vs spin ratio)

**Files:**
- Create: `chunky/chunky/Ballistics/AeroTable.swift`
- Create: `chunky/chunky/Resources/aero_tables.json`
- Test: `chunky/chunkyTests/AeroTableTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `nonisolated struct AeroTable` with nested `struct Entry: Codable, Equatable { let spinRatio, cd, cl: Double }`, `init(entries: [Entry])` (sorts ascending), `init(data: Data) throws` (decodes `[Entry]`), `func coefficients(spinRatio:) -> (cd: Double, cl: Double)` (linear interpolation, clamps at ends), and `static let standard: AeroTable`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/AeroTableTests.swift
import XCTest
@testable import chunky

final class AeroTableTests: XCTestCase {
    private let table = AeroTable(entries: [
        .init(spinRatio: 0.0, cd: 0.20, cl: 0.00),
        .init(spinRatio: 0.2, cd: 0.30, cl: 0.20),
    ])

    func testInterpolatesMidpoint() {
        let c = table.coefficients(spinRatio: 0.1)
        XCTAssertEqual(c.cd, 0.25, accuracy: 1e-12)
        XCTAssertEqual(c.cl, 0.10, accuracy: 1e-12)
    }

    func testClampsBelowRange() {
        let c = table.coefficients(spinRatio: -1)
        XCTAssertEqual(c.cd, 0.20, accuracy: 1e-12)
        XCTAssertEqual(c.cl, 0.00, accuracy: 1e-12)
    }

    func testClampsAboveRange() {
        let c = table.coefficients(spinRatio: 5)
        XCTAssertEqual(c.cd, 0.30, accuracy: 1e-12)
        XCTAssertEqual(c.cl, 0.20, accuracy: 1e-12)
    }

    func testUnsortedInputIsSorted() {
        let t = AeroTable(entries: [
            .init(spinRatio: 0.2, cd: 0.30, cl: 0.20),
            .init(spinRatio: 0.0, cd: 0.20, cl: 0.00),
        ])
        XCTAssertEqual(t.coefficients(spinRatio: 0.1).cd, 0.25, accuracy: 1e-12)
    }

    func testDecodeFromData() throws {
        let json = """
        [
          {"spinRatio": 0.0, "cd": 0.20, "cl": 0.00},
          {"spinRatio": 0.2, "cd": 0.30, "cl": 0.20}
        ]
        """.data(using: .utf8)!
        let decoded = try AeroTable(data: json)
        XCTAssertEqual(decoded.coefficients(spinRatio: 0.1).cl, 0.10, accuracy: 1e-12)
    }

    func testStandardTableIsMonotonicNonDecreasing() {
        let e = AeroTable.standard.entries
        XCTAssertGreaterThan(e.count, 1)
        for i in 1..<e.count {
            XCTAssertGreaterThan(e[i].spinRatio, e[i - 1].spinRatio)
            XCTAssertGreaterThanOrEqual(e[i].cd, e[i - 1].cd)
            XCTAssertGreaterThanOrEqual(e[i].cl, e[i - 1].cl)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/AeroTableTests 2>&1 | tail -15
```

Expected: `cannot find 'AeroTable' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// chunky/chunky/Ballistics/AeroTable.swift
import Foundation

/// Drag (Cd) and lift (Cl) coefficients as functions of spin ratio S = ω·r/|v|.
/// Values are linearly interpolated from a table sorted ascending by spin ratio;
/// queries outside the table clamp to the nearest endpoint.
nonisolated struct AeroTable {
    struct Entry: Codable, Equatable {
        let spinRatio: Double
        let cd: Double
        let cl: Double
    }

    let entries: [Entry]

    init(entries: [Entry]) {
        self.entries = entries.sorted { $0.spinRatio < $1.spinRatio }
    }

    init(data: Data) throws {
        let decoded = try JSONDecoder().decode([Entry].self, from: data)
        self.init(entries: decoded)
    }

    func coefficients(spinRatio S: Double) -> (cd: Double, cl: Double) {
        guard let first = entries.first, let last = entries.last else {
            return (0.25, 0.0)
        }
        if S <= first.spinRatio { return (first.cd, first.cl) }
        if S >= last.spinRatio { return (last.cd, last.cl) }
        for i in 1..<entries.count {
            let hi = entries[i]
            if S <= hi.spinRatio {
                let lo = entries[i - 1]
                let t = (S - lo.spinRatio) / (hi.spinRatio - lo.spinRatio)
                return (lo.cd + t * (hi.cd - lo.cd), lo.cl + t * (hi.cl - lo.cl))
            }
        }
        return (last.cd, last.cl)
    }

    /// Default table (approximate published golf-ball wind-tunnel values, spec §3.2).
    /// This is the calibration surface validated by BallisticsReferenceCarryTests.
    static let standard = AeroTable(entries: [
        Entry(spinRatio: 0.00, cd: 0.250, cl: 0.000),
        Entry(spinRatio: 0.05, cd: 0.255, cl: 0.100),
        Entry(spinRatio: 0.10, cd: 0.260, cl: 0.160),
        Entry(spinRatio: 0.15, cd: 0.270, cl: 0.210),
        Entry(spinRatio: 0.20, cd: 0.280, cl: 0.240),
        Entry(spinRatio: 0.25, cd: 0.290, cl: 0.260),
        Entry(spinRatio: 0.30, cd: 0.300, cl: 0.280),
        Entry(spinRatio: 0.40, cd: 0.320, cl: 0.310),
        Entry(spinRatio: 0.50, cd: 0.340, cl: 0.330),
    ])
}
```

- [ ] **Step 4: Create the shipped resource JSON (mirrors `AeroTable.standard`)**

```json
[
  {"spinRatio": 0.00, "cd": 0.250, "cl": 0.000},
  {"spinRatio": 0.05, "cd": 0.255, "cl": 0.100},
  {"spinRatio": 0.10, "cd": 0.260, "cl": 0.160},
  {"spinRatio": 0.15, "cd": 0.270, "cl": 0.210},
  {"spinRatio": 0.20, "cd": 0.280, "cl": 0.240},
  {"spinRatio": 0.25, "cd": 0.290, "cl": 0.260},
  {"spinRatio": 0.30, "cd": 0.300, "cl": 0.280},
  {"spinRatio": 0.40, "cd": 0.320, "cl": 0.310},
  {"spinRatio": 0.50, "cd": 0.340, "cl": 0.330}
]
```

(Write this to `chunky/chunky/Resources/aero_tables.json`. It is auto-bundled via the synchronized group and is the swappable runtime table; `AeroTable.standard` remains the in-code default used by the integrator until a later plan wires runtime loading.)

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/AeroTableTests 2>&1 | tail -15
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Ballistics/AeroTable.swift chunky/chunky/Resources/aero_tables.json chunky/chunkyTests/AeroTableTests.swift && \
git commit -m "feat(ballistics): add Cd/Cl aero table with interpolation"
```

---

### Task 6: Ball model and I/O value types

**Files:**
- Create: `chunky/chunky/Ballistics/BallModel.swift`
- Create: `chunky/chunky/Ballistics/LaunchConditions.swift`
- Create: `chunky/chunky/Ballistics/Trajectory.swift`
- Test: `chunky/chunkyTests/BallModelTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `nonisolated struct BallModel { var mass: Double; var diameter: Double; var area: Double { get }; static let standard }`
  - `nonisolated struct LaunchConditions { var speedMS, launchAngleDeg, azimuthDeg, spinRPM, spinAxisTiltDeg: Double }` with a memberwise-style `init(speedMS:launchAngleDeg:azimuthDeg:spinRPM:spinAxisTiltDeg:)` where `azimuthDeg` and `spinAxisTiltDeg` default to 0.
  - `nonisolated struct Trajectory { let carryMeters, flightTimeS, apexMeters: Double; let points: [Vec3] }`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/BallModelTests.swift
import XCTest
@testable import chunky

final class BallModelTests: XCTestCase {
    func testStandardConstants() {
        let b = BallModel.standard
        XCTAssertEqual(b.mass, 0.04593, accuracy: 1e-12)
        XCTAssertEqual(b.diameter, 0.04267, accuracy: 1e-12)
    }

    func testArea() {
        let b = BallModel.standard
        let expected = Double.pi * (0.04267 / 2) * (0.04267 / 2)
        XCTAssertEqual(b.area, expected, accuracy: 1e-15)
    }

    func testLaunchConditionsDefaults() {
        let lc = LaunchConditions(speedMS: 70, launchAngleDeg: 12, spinRPM: 2600)
        XCTAssertEqual(lc.azimuthDeg, 0, accuracy: 1e-12)
        XCTAssertEqual(lc.spinAxisTiltDeg, 0, accuracy: 1e-12)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/BallModelTests 2>&1 | tail -15
```

Expected: `cannot find 'BallModel' in scope`.

- [ ] **Step 3: Write minimal implementations**

```swift
// chunky/chunky/Ballistics/BallModel.swift
import Foundation

nonisolated struct BallModel {
    var mass: Double        // kg
    var diameter: Double    // m
    var area: Double { Double.pi * (diameter / 2) * (diameter / 2) }

    static let standard = BallModel(mass: 0.04593, diameter: 0.04267)
}
```

```swift
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
```

```swift
// chunky/chunky/Ballistics/Trajectory.swift
import Foundation

/// Output of the ballistics integrator.
nonisolated struct Trajectory {
    let carryMeters: Double
    let flightTimeS: Double
    let apexMeters: Double
    let points: [Vec3]   // sampled positions from launch to landing (debug/plot)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/BallModelTests 2>&1 | tail -15
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Ballistics/BallModel.swift chunky/chunky/Ballistics/LaunchConditions.swift chunky/chunky/Ballistics/Trajectory.swift chunky/chunkyTests/BallModelTests.swift && \
git commit -m "feat(ballistics): add BallModel, LaunchConditions, Trajectory types"
```

---

### Task 7: RK4 trajectory integrator

**Files:**
- Create: `chunky/chunky/Ballistics/Ballistics.swift`
- Test: `chunky/chunkyTests/BallisticsIntegratorTests.swift`

**Interfaces:**
- Consumes: `Vec3`, `BallModel`, `AeroTable`, `LaunchConditions`, `Trajectory`, `Conversions`.
- Produces: `nonisolated enum Ballistics` with
  `static func integrate(launch: LaunchConditions, airDensityKgM3: Double, ball: BallModel = .standard, aero: AeroTable = .standard, dt: Double = 0.001, gravity: Double = 9.81) -> Trajectory`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/BallisticsIntegratorTests.swift
import XCTest
@testable import chunky

final class BallisticsIntegratorTests: XCTestCase {
    // With no air (ρ=0) and no spin, the integrator must match the analytical
    // vacuum projectile range R = v0² sin(2θ) / g.
    func testVacuumRangeMatchesAnalytical() {
        let v0 = 20.0, thetaDeg = 45.0, g = 9.81
        let traj = Ballistics.integrate(
            launch: LaunchConditions(speedMS: v0, launchAngleDeg: thetaDeg, spinRPM: 0),
            airDensityKgM3: 0,
            dt: 0.001,
            gravity: g
        )
        let theta = thetaDeg * .pi / 180
        let expected = v0 * v0 * sin(2 * theta) / g   // 40.77 m
        XCTAssertEqual(traj.carryMeters, expected, accuracy: 0.05)
    }

    func testVacuumApexMatchesAnalytical() {
        let v0 = 20.0, thetaDeg = 45.0, g = 9.81
        let traj = Ballistics.integrate(
            launch: LaunchConditions(speedMS: v0, launchAngleDeg: thetaDeg, spinRPM: 0),
            airDensityKgM3: 0, dt: 0.001, gravity: g
        )
        let theta = thetaDeg * .pi / 180
        let vy = v0 * sin(theta)
        let expectedApex = vy * vy / (2 * g)          // 10.19 m
        XCTAssertEqual(traj.apexMeters, expectedApex, accuracy: 0.02)
    }

    func testDragShortensCarry() {
        let launch = LaunchConditions(speedMS: 60, launchAngleDeg: 15, spinRPM: 3000)
        let vacuum = Ballistics.integrate(launch: launch, airDensityKgM3: 0)
        let withAir = Ballistics.integrate(launch: launch, airDensityKgM3: 1.225)
        XCTAssertLessThan(withAir.carryMeters, vacuum.carryMeters)
    }

    func testBackspinAddsCarryVersusNoSpin() {
        // Backspin lift should extend carry relative to a spinless ball in air.
        let base = LaunchConditions(speedMS: 60, launchAngleDeg: 12, spinRPM: 0)
        let spun = LaunchConditions(speedMS: 60, launchAngleDeg: 12, spinRPM: 4000)
        let noSpin = Ballistics.integrate(launch: base, airDensityKgM3: 1.225)
        let withSpin = Ballistics.integrate(launch: spun, airDensityKgM3: 1.225)
        XCTAssertGreaterThan(withSpin.carryMeters, noSpin.carryMeters)
    }

    func testStepSizeConvergence() {
        // Halving dt should change carry by < 0.1 m (RK4 is 4th-order accurate).
        let launch = LaunchConditions(speedMS: 70, launchAngleDeg: 11, spinRPM: 2600)
        let coarse = Ballistics.integrate(launch: launch, airDensityKgM3: 1.225, dt: 0.001)
        let fine = Ballistics.integrate(launch: launch, airDensityKgM3: 1.225, dt: 0.0005)
        XCTAssertEqual(coarse.carryMeters, fine.carryMeters, accuracy: 0.1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/BallisticsIntegratorTests 2>&1 | tail -15
```

Expected: `cannot find 'Ballistics' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// chunky/chunky/Ballistics/Ballistics.swift
import Foundation

/// Pure point-mass trajectory integrator with aerodynamic drag and Magnus lift.
/// No Apple UI/capture frameworks — deterministic and unit-testable.
nonisolated enum Ballistics {

    /// Integrate from launch (origin, height 0) until the ball returns to launch
    /// height. Carry = horizontal distance from origin at that landing point.
    static func integrate(
        launch: LaunchConditions,
        airDensityKgM3 rho: Double,
        ball: BallModel = .standard,
        aero: AeroTable = .standard,
        dt: Double = 0.001,
        gravity g: Double = 9.81
    ) -> Trajectory {
        let theta = Conversions.degToRad(launch.launchAngleDeg)
        let psi = Conversions.degToRad(launch.azimuthDeg)
        let v0 = launch.speedMS

        var position = Vec3.zero
        var velocity = Vec3(
            v0 * cos(theta) * cos(psi),
            v0 * sin(theta),
            v0 * cos(theta) * sin(psi)
        )

        let omega = Conversions.rpmToRadPerSec(launch.spinRPM)   // rad/s
        let tilt = Conversions.degToRad(launch.spinAxisTiltDeg)
        // Pure backspin axis is +z (with velocity +x this yields lift +y);
        // tilt rotates the axis toward +y to introduce sidespin.
        let spinAxis = Vec3(0, sin(tilt), cos(tilt)).normalized

        let radius = ball.diameter / 2
        let area = ball.area
        let mass = ball.mass
        let gravityAcc = Vec3(0, -g, 0)

        func acceleration(_ v: Vec3) -> Vec3 {
            let speed = v.magnitude
            guard speed > 0 else { return gravityAcc }
            let spinRatio = omega * radius / speed
            let (cd, cl) = aero.coefficients(spinRatio: spinRatio)
            let dragForce = (-0.5 * rho * area * cd * speed) * v
            let magnusForce = (0.5 * rho * area * cl * speed) * spinAxis.cross(v)
            return gravityAcc + (1.0 / mass) * (dragForce + magnusForce)
        }

        var t = 0.0
        var apex = 0.0
        var points: [Vec3] = [position]
        let maxTime = 30.0

        while t < maxTime {
            // RK4 over state (position, velocity); acceleration depends only on velocity.
            let a1 = acceleration(velocity)
            let v2 = velocity + (dt / 2) * a1
            let a2 = acceleration(v2)
            let v3 = velocity + (dt / 2) * a2
            let a3 = acceleration(v3)
            let v4 = velocity + dt * a3
            let a4 = acceleration(v4)

            let prev = position
            position = position + (dt / 6) * (velocity + 2.0 * v2 + 2.0 * v3 + v4)
            velocity = velocity + (dt / 6) * (a1 + 2.0 * a2 + 2.0 * a3 + a4)
            t += dt
            apex = max(apex, position.y)
            points.append(position)

            // Landing: ball descends back through launch height.
            if position.y <= 0 && velocity.y < 0 {
                let denom = prev.y - position.y
                let frac = denom != 0 ? prev.y / denom : 0
                let landing = prev + frac * (position - prev)
                let carry = (landing.x * landing.x + landing.z * landing.z).squareRoot()
                return Trajectory(
                    carryMeters: carry,
                    flightTimeS: t - dt + frac * dt,
                    apexMeters: apex,
                    points: points
                )
            }
        }

        let carry = (position.x * position.x + position.z * position.z).squareRoot()
        return Trajectory(carryMeters: carry, flightTimeS: t, apexMeters: apex, points: points)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/BallisticsIntegratorTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`. The vacuum-range and apex tests confirm integrator correctness against closed-form physics; drag/backspin tests confirm force directions.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Ballistics/Ballistics.swift chunky/chunkyTests/BallisticsIntegratorTests.swift && \
git commit -m "feat(ballistics): add RK4 drag+Magnus trajectory integrator"
```

---

### Task 8: Reference-carry validation (acceptance gate)

**Files:**
- Test: `chunky/chunkyTests/BallisticsReferenceCarryTests.swift`
- (Possible tuning) Modify: `chunky/chunky/Ballistics/AeroTable.swift` (`static let standard`)

**Interfaces:**
- Consumes: `Ballistics.integrate`, `AirDensity.density`, `Conversions`, `AeroTable.standard`.
- Produces: no new symbols — this is the Phase-2 acceptance test from spec §13 ("`BallisticsTests` reproduce published reference carries for standard driver/7-iron within ±3%").

**Note on empirical calibration:** the aero coefficients in `AeroTable.standard` are the model's one tunable surface. If the first run of these reference tests lands outside ±3%, that is expected empirical TDD, not a code defect: adjust the `standard` table's `cd`/`cl` values (staying within published golf-ball wind-tunnel ranges — Cd ≈ 0.21–0.35, Cl ≈ 0.0–0.34) toward the reference and re-run. Do not loosen the ±3% tolerance; the spec fixes it. Reference launch conditions and carries below are published Trackman tour averages.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/BallisticsReferenceCarryTests.swift
import XCTest
@testable import chunky

final class BallisticsReferenceCarryTests: XCTestCase {
    private let seaLevel = AirDensity.density(temperatureC: 15, altitudeM: 0)  // 1.225

    private func carryYards(ballSpeedMPH: Double, launchDeg: Double, spinRPM: Double) -> Double {
        let launch = LaunchConditions(
            speedMS: Conversions.mphToMS(ballSpeedMPH),
            launchAngleDeg: launchDeg,
            spinRPM: spinRPM
        )
        let traj = Ballistics.integrate(launch: launch, airDensityKgM3: seaLevel)
        return Conversions.metersToYards(traj.carryMeters)
    }

    // Trackman tour-average driver: 167 mph ball, 10.9° launch, 2686 rpm ≈ 275 yd carry.
    func testDriverReferenceCarry() {
        let carry = carryYards(ballSpeedMPH: 167, launchDeg: 10.9, spinRPM: 2686)
        XCTAssertEqual(carry, 275, accuracy: 275 * 0.03)   // ±3% = ±8.25 yd
    }

    // Trackman tour-average 7-iron: 120 mph ball, 16.3° launch, 7000 rpm ≈ 172 yd carry.
    func testSevenIronReferenceCarry() {
        let carry = carryYards(ballSpeedMPH: 120, launchDeg: 16.3, spinRPM: 7000)
        XCTAssertEqual(carry, 172, accuracy: 172 * 0.03)   // ±3% = ±5.16 yd
    }

    // Altitude must increase carry (thinner air) — directional sanity, not a fixed target.
    func testAltitudeIncreasesCarry() {
        let launch = LaunchConditions(speedMS: Conversions.mphToMS(167),
                                      launchAngleDeg: 10.9, spinRPM: 2686)
        let sea = Ballistics.integrate(launch: launch, airDensityKgM3: seaLevel)
        let denver = Ballistics.integrate(
            launch: launch,
            airDensityKgM3: AirDensity.density(temperatureC: 15, altitudeM: 1609)
        )
        XCTAssertGreaterThan(denver.carryMeters, sea.carryMeters)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/BallisticsReferenceCarryTests 2>&1 | tail -20
```

Expected: FAIL — the file is new (compiles) but the reference assertions may not yet be within ±3% given the untuned `AeroTable.standard`. Record the printed actual carries.

- [ ] **Step 3: Tune the aero table to hit the references**

Adjust `AeroTable.standard` in `chunky/chunky/Ballistics/AeroTable.swift` toward the measured gap, keeping values within published ranges (Cd 0.21–0.35, Cl 0.0–0.34) and keeping the table monotonic non-decreasing (Task 5's `testStandardTableIsMonotonicNonDecreasing` must stay green). Typical adjustments: raise Cl in the S ≈ 0.05–0.15 band to lengthen carry; raise Cd to shorten it. Re-run after each change. Example of the kind of edit (values illustrative — use the actuals from Step 2 to decide direction and magnitude):

```swift
        Entry(spinRatio: 0.05, cd: 0.255, cl: 0.120),
        Entry(spinRatio: 0.10, cd: 0.260, cl: 0.175),
        Entry(spinRatio: 0.15, cd: 0.270, cl: 0.220),
```

- [ ] **Step 4: Run reference + interpolation tests to verify green**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests/BallisticsReferenceCarryTests \
       -only-testing:chunkyTests/AeroTableTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` for both — driver and 7-iron carries within ±3% and the standard table still monotonic.

- [ ] **Step 5: Keep the shipped JSON in sync with the tuned table**

If `AeroTable.standard` changed in Step 3, update `chunky/chunky/Resources/aero_tables.json` to the same values so the shipped resource matches the validated code default.

- [ ] **Step 6: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunkyTests/BallisticsReferenceCarryTests.swift chunky/chunky/Ballistics/AeroTable.swift chunky/chunky/Resources/aero_tables.json && \
git commit -m "test(ballistics): validate driver & 7-iron reference carries within ±3%"
```

---

### Task 9: Full-suite green gate

**Files:**
- None (verification only).

**Interfaces:**
- Consumes: all prior tasks.
- Produces: confidence that the whole Ballistics module + config change build and pass together.

- [ ] **Step 1: Run the entire test suite**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyTests 2>&1 | tail -25
```

Expected: `** TEST SUCCEEDED **` with all Ballistics test classes passing.

- [ ] **Step 2: Confirm no forbidden imports leaked into Ballistics**

Run:

```bash
cd /Users/kason/Documents/github/Chunky && \
! grep -rEl "import (AVFoundation|Vision|CoreML|SwiftUI|SwiftData|UIKit)" chunky/chunky/Ballistics/ && \
echo "OK: Ballistics is framework-pure"
```

Expected: `OK: Ballistics is framework-pure`.

- [ ] **Step 3: Final commit (if anything uncommitted)**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add -A && git commit -m "chore(ballistics): phase 1 foundation & ballistics complete" || echo "nothing to commit"
```

---

## Self-Review

**1. Spec coverage (this plan's scope only):**
- §3.2 ballistics equations (drag + Magnus), ball constants, RK4 @ dt=1ms, integrate-to-launch-height, carry definition → Tasks 6–8. ✅
- §3.2 Cd/Cl as functions of spin ratio, interpolated table, bundled swappable JSON → Task 5. ✅
- §3.2 air density from temp/altitude(/humidity), ISA helper, 1.225 default → Task 4. ✅
- §13 Phase 2 acceptance: BallisticsTests reproduce driver/7-iron reference carries within ±3% → Task 8. ✅
- §16 "first deliverable: Ballistics package + BallisticsTests" → whole plan. ✅
- §4 dependency rule (no AVFoundation/Vision in Ballistics) → global constraint + Task 9 Step 2. ✅
- Config alignment chosen by user (Swift 6, iPhone-only, camera/mic keys) → Task 1. ✅
- Out of scope here (later plans): Metrics, capture, vision, spin, data/UI — listed in Roadmap. ✅

**2. Placeholder scan:** No "TBD"/"handle edge cases"/"write tests for the above" left. Task 8's tuning step shows the exact file, exact ranges, exact direction of change, and the gate that proves it — it is empirical TDD with concrete content, not a hand-wave.

**3. Type consistency:** `Ballistics.integrate(launch:airDensityKgM3:ball:aero:dt:gravity:)` signature is identical across Tasks 7 and 8. `AeroTable.coefficients(spinRatio:) -> (cd:cl:)`, `AirDensity.density(temperatureC:altitudeM:relativeHumidity:)`, `Conversions.*`, `LaunchConditions.init(speedMS:launchAngleDeg:azimuthDeg:spinRPM:spinAxisTiltDeg:)`, `Trajectory.{carryMeters,flightTimeS,apexMeters,points}`, and `Vec3` operators/members match everywhere they are used. `nonisolated` applied to every math type per the global concurrency constraint.
