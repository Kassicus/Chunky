# DataStore & Data UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Chunky's first-class data layer and its screens: SwiftData models (Club, Session, Shot, CalibrationProfile), pure per-club aggregate statistics, shot filtering/sorting, CSV export, a persistence store (auto-save, exclude, delete, soft-archive), and three themed SwiftUI screens — Clubs manager, Shot History, and a per-club Averages dashboard with a gapping-ladder chart — under the "Twilight Range Readout" visual identity.

**Architecture:** Two layers in the `chunky` app target. (1) A data/logic core: SwiftData `@Model` classes plus pure, `nonisolated` value types and functions (`Stats`, `ShotRecord`, `ClubAggregates`, `ShotFilter`, `CSVExport`) that operate on a value-type projection so the accuracy-sensitive math is unit-tested without a database, and a `ShotStore` wrapping `ModelContext` for persistence rules (tested with an in-memory container). It consumes Plan 2's `ShotResult`/`SpinSource`/`ConfidenceLevel` and Plan 1's `Conversions`. (2) A SwiftUI layer: a `TabView` shell and three screens driven by `@Query` + the pure logic, styled by a shared `Theme`. The data core stays free of SwiftUI.

**Tech Stack:** Swift 6, Xcode 26.5, iOS 26.5, SwiftData, SwiftUI, Swift Charts, XCTest. No third-party dependencies.

## Roadmap (Plan 3 of the per-phase sequence)
1. Foundation & Ballistics ✅ (PR #1) · 2. Metrics ✅ (PR #2) · **3. DataStore & Data UI ← this plan** (spec §10–11) · 4. CaptureKit (§5) · 5. VisionCore + Calibration (§6–7) · 6. Live UI end-to-end · 7. SpinCore (§8) · 8. Clubhead & smash (§3.4) · 9. Dual-camera & Core ML.

---

**Goal / Architecture / Tech Stack:** (see above)

## Global Constraints

- **Platform:** iOS 26.5, Swift 6, iPhone-only. Build/test simulator: **iPhone 17 Pro Max**.
- **Layering:** the data/logic core (`DataStore/` folder: models, `Stats`, `ShotRecord`, `ClubAggregates`, `ShotFilter`, `CSVExport`, `ShotStore`) must NOT import SwiftUI/Charts. Models import `SwiftData`+`Foundation`; pure logic imports `Foundation` only. The SwiftUI layer (`Features/` folder) may import SwiftUI/SwiftData/Charts.
- **Reuse (same module):** use Plan 2's `SpinSource`, `ConfidenceLevel`, `ShotResult` and Plan 1's `Conversions` directly (no imports needed).
- **Concurrency:** pure value types/functions are `nonisolated`. SwiftData `@Model` classes and any code touching `ModelContext`/SwiftUI are MainActor (the app target defaults to `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). Test classes that use `ModelContext` or SwiftUI must be annotated `@MainActor`; pure-logic test classes are not.
- **Data rules (spec §10 — must-have):**
  - Every shot is tagged to a `Club` and auto-saved the instant a result exists (a `ShotStore.saveShot` helper; no manual save step).
  - Fully customizable club list: add / rename / reorder / remove. Use `isArchived` (soft-delete) for clubs that already have shots; hard delete only when a club has zero shots.
  - Delete single or multiple shots (permanent); aggregates recompute.
  - `isExcludedFromAverages` flag drops a mishit from stats WITHOUT deleting the record (toggleable); excluded shots are visually marked and omitted from every aggregate.
  - Per-club aggregates over **non-excluded** shots: count, mean & median carry, std dev, min/max, and mean ball speed / launch angle / spin (+ club speed / smash where present).
  - Persist `rawTrackJSON` per shot (spec §9/§10 — carry can be recomputed later). The caller passes it into `saveShot`.
  - CSV export of the filtered shot set and of the per-club averages table.
- **Units:** SI stored internally (meters, m/s); a `Units` setting (yards/meters) formats at display. Convert via Plan 1's `Conversions`.
- **Design identity — "Twilight Range Readout":** see the Design System section below; all screens derive color/type from `Theme`. Copy is plain, active-voice, sentence case; empty states invite action; destructive actions named plainly.
- **Git hygiene:** each task stages ONLY its own files (explicit `git add <paths>`); never `git add -A`/`.`/`-a`.
- **Process:** TDD for the data/logic core (red→green with real assertions). UI tasks are verified by a clean build plus a SwiftUI `#Preview` and, where noted, a lightweight XCUITest smoke check; their view-model/logic dependencies are already unit-tested. Frequent commits; DRY; YAGNI.

## Design System — "Twilight Range Readout"

A golf launch monitor for amateurs: a precise instrument with range-day warmth. Dark fairway-green surfaces, chalk text, range-ball optic-yellow reserved for the single hero number, flag-orange for mishits/exclusions. Numbers use tabular figures so columns align like a monitor readout.

**Palette** (define in `Theme`; parsed from hex):
- `rangeDusk` `#0C1E16` — app background
- `turf` `#16382A` — cards / rows
- `turfLine` `#23503C` — hairline dividers
- `chalk` `#F1ECDB` — primary text & numerals
- `mist` `#8AA396` — secondary text / labels
- `optic` `#DDF24A` — hero carry number + primary accent (range-ball)
- `flag` `#E4572E` — destructive / excluded / warnings
- `amber` `#E8B84B` — medium confidence

**Type** (system faces, deliberate treatment): display = SF Pro **Rounded** bold (hero number, screen titles); data = system with `.monospacedDigit()` (all numeric columns); eyebrow = caption, `.textCase(.uppercase)`, tracked (`.kerning(1.5)`) for labels/club names.

**Confidence styling:** high → chalk text + optic dot; medium → amber; low → mist (desaturated) — a low-confidence shot must be visually distinct so it isn't mistaken for gospel (spec §11).

**Signature — the Gapping Ladder:** the Averages dashboard renders clubs as rungs on a vertical yardage ladder; each rung's bar length ∝ carry, so the gaps between clubs are literal visual spacing (evokes range yardage markers). This is the one bold element; everything else stays quiet.

## File Structure

```
chunky/chunky/DataStore/
├─ HexColor.swift          // pure hex -> RGBA parse
├─ Units.swift             // yd/m enum + formatting (pure)
├─ ConfidenceStyle.swift   // ConfidenceLevel -> label + token (pure)
├─ ClubType.swift          // ClubType + CameraLens enums
├─ Club.swift              // @Model
├─ Shot.swift              // @Model
├─ Session.swift           // @Model
├─ CalibrationProfile.swift// @Model
├─ Stats.swift             // pure mean/median/stddev/minmax
├─ ShotRecord.swift        // pure value projection of a Shot
├─ ClubAggregates.swift    // pure aggregate over [ShotRecord]
├─ ShotFilter.swift        // pure filter + sort over [ShotRecord]
├─ CSVExport.swift         // pure CSV strings
└─ ShotStore.swift         // ModelContext ops + Shot<->ShotRecord + saveShot(ShotResult)

chunky/chunky/Features/
├─ Theme.swift             // SwiftUI Color/Font from the design tokens
├─ RootView.swift          // TabView shell (replaces ContentView usage)
├─ Clubs/ClubsView.swift
├─ History/HistoryView.swift  History/ShotDetailView.swift
└─ Averages/AveragesView.swift  Averages/GappingLadder.swift

chunky/chunkyTests/        // *Tests.swift per pure unit; @MainActor for model/store tests
chunky/chunkyUITests/      // ClubsSmokeUITests.swift (one smoke flow)
```

---

### Task 1: Pure design primitives (HexColor, Units, ConfidenceStyle)

**Files:**
- Create: `chunky/chunky/DataStore/HexColor.swift`, `chunky/chunky/DataStore/Units.swift`, `chunky/chunky/DataStore/ConfidenceStyle.swift`
- Test: `chunky/chunkyTests/DesignPrimitivesTests.swift`

**Interfaces:**
- Consumes: `Conversions` (Plan 1), `ConfidenceLevel` (Plan 2).
- Produces:
  - `nonisolated enum HexColor { static func rgba(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double)? }` — parses `#RRGGBB`/`RRGGBB` (and `#RRGGBBAA`), components 0…1, nil on malformed.
  - `nonisolated enum Units: String, CaseIterable { case yards, meters; func carry(fromMeters:) -> Double; var abbreviation: String; func formattedCarry(fromMeters:) -> String }` (whole-number carry).
  - `nonisolated enum ConfidenceStyle { static func label(_:) -> String; static func token(_:) -> String }` mapping `ConfidenceLevel` → display label ("High"/"Med"/"Low") and a palette token name ("chalk"/"amber"/"mist").

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/DesignPrimitivesTests.swift
import XCTest
@testable import chunky

final class DesignPrimitivesTests: XCTestCase {
    func testHexParsesSixDigits() {
        let c = HexColor.rgba("#DDF24A")!
        XCTAssertEqual(c.r, 0xDD / 255.0, accuracy: 1e-9)
        XCTAssertEqual(c.g, 0xF2 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(c.b, 0x4A / 255.0, accuracy: 1e-9)
        XCTAssertEqual(c.a, 1.0, accuracy: 1e-9)
    }

    func testHexAcceptsNoHashAndAlpha() {
        XCTAssertNotNil(HexColor.rgba("0C1E16"))
        XCTAssertEqual(HexColor.rgba("#000000FF")!.a, 1.0, accuracy: 1e-9)
    }

    func testHexRejectsMalformed() {
        XCTAssertNil(HexColor.rgba("#ZZZ"))
        XCTAssertNil(HexColor.rgba("12345"))
    }

    func testUnitsCarryConversionAndFormat() {
        XCTAssertEqual(Units.yards.carry(fromMeters: 91.44), 100, accuracy: 1e-9)
        XCTAssertEqual(Units.meters.carry(fromMeters: 150), 150, accuracy: 1e-9)
        XCTAssertEqual(Units.yards.formattedCarry(fromMeters: 91.44), "100 yd")
        XCTAssertEqual(Units.meters.formattedCarry(fromMeters: 149.6), "150 m")
    }

    func testConfidenceStyle() {
        XCTAssertEqual(ConfidenceStyle.label(.high), "High")
        XCTAssertEqual(ConfidenceStyle.label(.medium), "Med")
        XCTAssertEqual(ConfidenceStyle.label(.low), "Low")
        XCTAssertEqual(ConfidenceStyle.token(.high), "chalk")
        XCTAssertEqual(ConfidenceStyle.token(.medium), "amber")
        XCTAssertEqual(ConfidenceStyle.token(.low), "mist")
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Run: `cd /Users/kason/Documents/github/Chunky/chunky && xcodebuild -project chunky.xcodeproj -scheme chunky -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:chunkyTests/DesignPrimitivesTests 2>&1 | tail -15` — Expected: `cannot find 'HexColor' in scope`.

- [ ] **Step 3: Write implementations**

```swift
// chunky/chunky/DataStore/HexColor.swift
import Foundation

nonisolated enum HexColor {
    static func rgba(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double)? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        guard let value = UInt64(s, radix: 16) else { return nil }
        let hasAlpha = s.count == 8
        let r = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255.0
        let g = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255.0
        let b = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255.0
        let a = hasAlpha ? Double(value & 0xFF) / 255.0 : 1.0
        return (r, g, b, a)
    }
}
```

```swift
// chunky/chunky/DataStore/Units.swift
import Foundation

nonisolated enum Units: String, CaseIterable, Codable {
    case yards
    case meters

    var abbreviation: String { self == .yards ? "yd" : "m" }

    func carry(fromMeters meters: Double) -> Double {
        self == .yards ? Conversions.metersToYards(meters) : meters
    }

    func formattedCarry(fromMeters meters: Double) -> String {
        "\(Int(carry(fromMeters: meters).rounded())) \(abbreviation)"
    }
}
```

```swift
// chunky/chunky/DataStore/ConfidenceStyle.swift
import Foundation

/// Maps a confidence level to a short display label and a palette token name.
/// Kept UI-framework-free so it is unit-testable; Theme turns the token into a Color.
nonisolated enum ConfidenceStyle {
    static func label(_ c: ConfidenceLevel) -> String {
        switch c { case .high: "High"; case .medium: "Med"; case .low: "Low" }
    }
    static func token(_ c: ConfidenceLevel) -> String {
        switch c { case .high: "chalk"; case .medium: "amber"; case .low: "mist" }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — same command as Step 2 — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/DataStore/HexColor.swift chunky/chunky/DataStore/Units.swift chunky/chunky/DataStore/ConfidenceStyle.swift chunky/chunkyTests/DesignPrimitivesTests.swift && \
git commit -m "feat(datastore): add hex-color, units, and confidence-style primitives

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Theme (SwiftUI colors & fonts)

**Files:**
- Create: `chunky/chunky/Features/Theme.swift`
- Test: none (SwiftUI Color has no testable components); verified by build + preview. Its inputs (`HexColor`, `ConfidenceStyle`) are already tested.

**Interfaces:**
- Consumes: `HexColor`, `ConfidenceStyle`, `ConfidenceLevel`.
- Produces: `Color(hex:)` init; `enum Theme` with static Colors `rangeDusk`, `turf`, `turfLine`, `chalk`, `mist`, `optic`, `flag`, `amber`; `static func confidenceColor(_:) -> Color`; `Font` helpers `Theme.display(_:)`, `Theme.number(_:)`, `Theme.eyebrow`.

- [ ] **Step 1: Write the implementation**

```swift
// chunky/chunky/Features/Theme.swift
import SwiftUI

extension Color {
    init(hex: String) {
        let c = HexColor.rgba(hex) ?? (1, 0, 1, 1) // magenta = missing token, caught in preview
        self = Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }
}

enum Theme {
    static let rangeDusk = Color(hex: "#0C1E16")
    static let turf = Color(hex: "#16382A")
    static let turfLine = Color(hex: "#23503C")
    static let chalk = Color(hex: "#F1ECDB")
    static let mist = Color(hex: "#8AA396")
    static let optic = Color(hex: "#DDF24A")
    static let flag = Color(hex: "#E4572E")
    static let amber = Color(hex: "#E8B84B")

    static func confidenceColor(_ c: ConfidenceLevel) -> Color {
        switch ConfidenceStyle.token(c) {
        case "chalk": chalk
        case "amber": amber
        default: mist
        }
    }

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold).monospacedDigit() }
    static let eyebrow = Font.system(.caption, design: .rounded).weight(.semibold)
}
```

- [ ] **Step 2: Add a preview to smoke-check the palette compiles & renders**

Append to `Theme.swift`:

```swift
#Preview {
    VStack(alignment: .leading, spacing: 8) {
        Text("164").font(Theme.display(48)).foregroundStyle(Theme.optic)
        Text("CARRY").font(Theme.eyebrow).kerning(1.5).foregroundStyle(Theme.mist)
        ForEach([ConfidenceLevel.high, .medium, .low], id: \.self) { c in
            Text(ConfidenceStyle.label(c)).font(Theme.number(15)).foregroundStyle(Theme.confidenceColor(c))
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.rangeDusk)
}
```
(This requires `ConfidenceLevel` to be `Hashable` — it is `Equatable`; add `Hashable` in Task where defined if needed. `ConfidenceLevel` is a `String` enum so it is already `Hashable`.)

- [ ] **Step 3: Build to verify it compiles**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Features/Theme.swift && \
git commit -m "feat(ui): add Twilight Range Readout theme (colors, fonts)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Enums + Club model

**Files:**
- Create: `chunky/chunky/DataStore/ClubType.swift`, `chunky/chunky/DataStore/Club.swift`
- Test: `chunky/chunkyTests/ClubModelTests.swift`

**Interfaces:**
- Produces:
  - `nonisolated enum ClubType: String, Codable, CaseIterable, Sendable { case driver, wood, hybrid, iron, wedge, putter }`
  - `nonisolated enum CameraLens: String, Codable, CaseIterable, Sendable { case telephoto, wide }`
  - `@Model final class Club` with `id: UUID`, `name: String`, `typeRaw: String`, `order: Int`, `notes: String`, `isArchived: Bool`, `modeledSpinRPM: Double`, `shots: [Shot]` (inverse of `Shot.club`), a computed `var type: ClubType`, and a memberwise `init`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ClubModelTests.swift
import XCTest
import SwiftData
@testable import chunky

@MainActor
final class ClubModelTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Club.self, Shot.self, Session.self, CalibrationProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    func testInsertAndFetchClub() throws {
        let ctx = try makeContext()
        ctx.insert(Club(name: "7-Iron", type: .iron, order: 3, modeledSpinRPM: 6500))
        let clubs = try ctx.fetch(FetchDescriptor<Club>())
        XCTAssertEqual(clubs.count, 1)
        XCTAssertEqual(clubs.first?.name, "7-Iron")
        XCTAssertEqual(clubs.first?.type, .iron)
        XCTAssertFalse(clubs.first!.isArchived)
    }

    func testTypeComputedRoundTrips() {
        let c = Club(name: "Driver", type: .driver, order: 0, modeledSpinRPM: 2600)
        XCTAssertEqual(c.typeRaw, "driver")
        c.type = .wood
        XCTAssertEqual(c.typeRaw, "wood")
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... test -only-testing:chunkyTests/ClubModelTests ...` — Expected: `cannot find 'Club' in scope` (and `Shot`/`Session`/`CalibrationProfile`, which are added in later tasks — see note in Step 3).

- [ ] **Step 3: Write implementations**

```swift
// chunky/chunky/DataStore/ClubType.swift
import Foundation

nonisolated enum ClubType: String, Codable, CaseIterable, Sendable {
    case driver, wood, hybrid, iron, wedge, putter
}

nonisolated enum CameraLens: String, Codable, CaseIterable, Sendable {
    case telephoto, wide
}
```

```swift
// chunky/chunky/DataStore/Club.swift
import Foundation
import SwiftData

@Model
final class Club {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var order: Int
    var notes: String
    var isArchived: Bool
    var modeledSpinRPM: Double
    @Relationship(deleteRule: .nullify, inverse: \Shot.club) var shots: [Shot] = []

    var type: ClubType {
        get { ClubType(rawValue: typeRaw) ?? .iron }
        set { typeRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), name: String, type: ClubType, order: Int,
         notes: String = "", isArchived: Bool = false, modeledSpinRPM: Double) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.order = order
        self.notes = notes
        self.isArchived = isArchived
        self.modeledSpinRPM = modeledSpinRPM
    }
}
```

**Note for the implementer:** `Club` references `Shot` (Task 4), and the test container references `Shot`/`Session`/`CalibrationProfile` (Tasks 4–5). To keep this task independently green, implement `Club` referencing `Shot.club`, then implement `Shot`, `Session`, and `CalibrationProfile` as minimal `@Model` stubs in THIS task's commit IF needed to compile — but prefer the cleaner route: this task's test will only compile once Task 4/5 models exist. Therefore **fold the four models into a coherent build**: if you cannot compile `ClubModelTests` without the other models, implement Tasks 3–5's models together and commit them as this task, then Tasks 4–5 become verification/tests-only. Report which route you took. (This is the one place the model graph is mutually referential; the plan accepts a combined models commit here.)

- [ ] **Step 4: Run test to verify it passes** — same as Step 2 — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/DataStore/ClubType.swift chunky/chunky/DataStore/Club.swift chunky/chunkyTests/ClubModelTests.swift && \
git commit -m "feat(datastore): add ClubType/CameraLens enums and Club model

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Shot model

**Files:**
- Create: `chunky/chunky/DataStore/Shot.swift`
- Test: `chunky/chunkyTests/ShotModelTests.swift`

**Interfaces:**
- Consumes: `Club` (Task 3), `SpinSource`/`ConfidenceLevel` (Plan 2).
- Produces: `@Model final class Shot` with `id: UUID`, `timestamp: Date`, `ballSpeedMS`, `launchAngleDeg`, `azimuthDeg`, `spinRPM: Double`, `spinSourceRaw: String`, `spinAxisTiltDeg: Double`, `clubSpeedMS: Double?`, `smashFactor: Double?`, `carryMeters: Double`, `confidenceRaw: String`, `isExcludedFromAverages: Bool`, `rawTrackJSON: String?`, `videoClipURL: URL?`, `club: Club?`, `session: Session?`, computed `var spinSource: SpinSource` and `var confidence: ConfidenceLevel`, and a memberwise `init` (defaults: `isExcludedFromAverages = false`, optionals nil).

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ShotModelTests.swift
import XCTest
import SwiftData
@testable import chunky

@MainActor
final class ShotModelTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Club.self, Shot.self, Session.self, CalibrationProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    func testShotLinksToClubAndReadsBackEnums() throws {
        let ctx = try makeContext()
        let club = Club(name: "7-Iron", type: .iron, order: 0, modeledSpinRPM: 6500)
        ctx.insert(club)
        let shot = Shot(timestamp: Date(timeIntervalSince1970: 0), ballSpeedMS: 53.6,
                        launchAngleDeg: 16.3, azimuthDeg: 0, spinRPM: 6500,
                        spinSource: .modeled, spinAxisTiltDeg: 0, carryMeters: 150,
                        confidence: .medium)
        shot.club = club
        ctx.insert(shot)
        let shots = try ctx.fetch(FetchDescriptor<Shot>())
        XCTAssertEqual(shots.count, 1)
        XCTAssertEqual(shots.first?.spinSource, .modeled)
        XCTAssertEqual(shots.first?.confidence, .medium)
        XCTAssertEqual(shots.first?.club?.name, "7-Iron")
        XCTAssertEqual(club.shots.count, 1) // inverse populated
    }

    func testOpportunisticFieldsDefaultNil() {
        let shot = Shot(timestamp: Date(timeIntervalSince1970: 0), ballSpeedMS: 70,
                        launchAngleDeg: 11, azimuthDeg: 0, spinRPM: 2600,
                        spinSource: .modeled, spinAxisTiltDeg: 0, carryMeters: 240,
                        confidence: .high)
        XCTAssertNil(shot.clubSpeedMS)
        XCTAssertNil(shot.smashFactor)
        XCTAssertFalse(shot.isExcludedFromAverages)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/ShotModelTests ...`. (If Shot was already added in Task 3's combined commit, this task is tests-only; the RED will instead show a missing test symbol before you add the test file.)

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/DataStore/Shot.swift
import Foundation
import SwiftData

@Model
final class Shot {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var ballSpeedMS: Double
    var launchAngleDeg: Double
    var azimuthDeg: Double
    var spinRPM: Double
    var spinSourceRaw: String
    var spinAxisTiltDeg: Double
    var clubSpeedMS: Double?
    var smashFactor: Double?
    var carryMeters: Double
    var confidenceRaw: String
    var isExcludedFromAverages: Bool
    var rawTrackJSON: String?
    var videoClipURL: URL?
    var club: Club?
    var session: Session?

    var spinSource: SpinSource {
        get { SpinSource(rawValue: spinSourceRaw) ?? .modeled }
        set { spinSourceRaw = newValue.rawValue }
    }
    var confidence: ConfidenceLevel {
        get { ConfidenceLevel(rawValue: confidenceRaw) ?? .low }
        set { confidenceRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), timestamp: Date, ballSpeedMS: Double, launchAngleDeg: Double,
         azimuthDeg: Double, spinRPM: Double, spinSource: SpinSource, spinAxisTiltDeg: Double,
         clubSpeedMS: Double? = nil, smashFactor: Double? = nil, carryMeters: Double,
         confidence: ConfidenceLevel, isExcludedFromAverages: Bool = false,
         rawTrackJSON: String? = nil, videoClipURL: URL? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.ballSpeedMS = ballSpeedMS
        self.launchAngleDeg = launchAngleDeg
        self.azimuthDeg = azimuthDeg
        self.spinRPM = spinRPM
        self.spinSourceRaw = spinSource.rawValue
        self.spinAxisTiltDeg = spinAxisTiltDeg
        self.clubSpeedMS = clubSpeedMS
        self.smashFactor = smashFactor
        self.carryMeters = carryMeters
        self.confidenceRaw = confidence.rawValue
        self.isExcludedFromAverages = isExcludedFromAverages
        self.rawTrackJSON = rawTrackJSON
        self.videoClipURL = videoClipURL
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — same as Step 2 — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/DataStore/Shot.swift chunky/chunkyTests/ShotModelTests.swift && \
git commit -m "feat(datastore): add Shot model with club link and enum accessors

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Session & CalibrationProfile models + app schema wiring

**Files:**
- Create: `chunky/chunky/DataStore/Session.swift`, `chunky/chunky/DataStore/CalibrationProfile.swift`
- Modify: `chunky/chunky/chunkyApp.swift` (ModelContainer schema)
- Test: `chunky/chunkyTests/SessionModelTests.swift`

**Interfaces:**
- Produces:
  - `@Model final class Session` with `id: UUID`, `date: Date`, `location: String`, `lensRaw: String`, `temperatureC`, `altitudeM`, `humidity: Double`, `calibrationProfileId: UUID?`, `shots: [Shot]` (inverse of `Shot.session`, `deleteRule: .cascade`), computed `var lens: CameraLens`, memberwise init.
  - `@Model final class CalibrationProfile` with `id: UUID`, `lensRaw: String`, `pxPerMeter: Double`, `imageUpX: Double`, `imageUpY: Double`, `cameraDistanceM: Double`, `createdAt: Date`, computed `var lens: CameraLens`, memberwise init.
- Modifies `chunkyApp.swift` so the shared `ModelContainer` schema is `[Club.self, Shot.self, Session.self, CalibrationProfile.self]` (the template `Item.self` is removed from the schema; `Item.swift` may remain unused or be deleted — deletion is cleaner and is done in Task 11 when ContentView is replaced).

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/SessionModelTests.swift
import XCTest
import SwiftData
@testable import chunky

@MainActor
final class SessionModelTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Club.self, Shot.self, Session.self, CalibrationProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    func testSessionCascadesShotDeletion() throws {
        let ctx = try makeContext()
        let session = Session(date: Date(timeIntervalSince1970: 0), location: "Range",
                              lens: .telephoto, temperatureC: 15, altitudeM: 0, humidity: 0)
        ctx.insert(session)
        let shot = Shot(timestamp: Date(timeIntervalSince1970: 0), ballSpeedMS: 70,
                        launchAngleDeg: 11, azimuthDeg: 0, spinRPM: 2600, spinSource: .modeled,
                        spinAxisTiltDeg: 0, carryMeters: 240, confidence: .high)
        shot.session = session
        ctx.insert(shot)
        try ctx.save()
        ctx.delete(session)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Shot>()).count, 0) // cascaded
    }

    func testCalibrationProfileStores() throws {
        let ctx = try makeContext()
        ctx.insert(CalibrationProfile(lens: .telephoto, pxPerMeter: 1200,
                                      imageUpX: 0, imageUpY: 1, cameraDistanceM: 3))
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CalibrationProfile>()).first?.lens, .telephoto)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/SessionModelTests ...` — Expected: `cannot find 'Session' in scope`.

- [ ] **Step 3: Write implementations**

```swift
// chunky/chunky/DataStore/Session.swift
import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var date: Date
    var location: String
    var lensRaw: String
    var temperatureC: Double
    var altitudeM: Double
    var humidity: Double
    var calibrationProfileId: UUID?
    @Relationship(deleteRule: .cascade, inverse: \Shot.session) var shots: [Shot] = []

    var lens: CameraLens {
        get { CameraLens(rawValue: lensRaw) ?? .telephoto }
        set { lensRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), date: Date, location: String = "", lens: CameraLens,
         temperatureC: Double, altitudeM: Double, humidity: Double,
         calibrationProfileId: UUID? = nil) {
        self.id = id
        self.date = date
        self.location = location
        self.lensRaw = lens.rawValue
        self.temperatureC = temperatureC
        self.altitudeM = altitudeM
        self.humidity = humidity
        self.calibrationProfileId = calibrationProfileId
    }
}
```

```swift
// chunky/chunky/DataStore/CalibrationProfile.swift
import Foundation
import SwiftData

@Model
final class CalibrationProfile {
    @Attribute(.unique) var id: UUID
    var lensRaw: String
    var pxPerMeter: Double
    var imageUpX: Double
    var imageUpY: Double
    var cameraDistanceM: Double
    var createdAt: Date

    var lens: CameraLens {
        get { CameraLens(rawValue: lensRaw) ?? .telephoto }
        set { lensRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), lens: CameraLens, pxPerMeter: Double, imageUpX: Double,
         imageUpY: Double, cameraDistanceM: Double, createdAt: Date = Date()) {
        self.id = id
        self.lensRaw = lens.rawValue
        self.pxPerMeter = pxPerMeter
        self.imageUpX = imageUpX
        self.imageUpY = imageUpY
        self.cameraDistanceM = cameraDistanceM
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Update the app schema** in `chunky/chunky/chunkyApp.swift` — replace the `Schema([Item.self])` line so the schema is:

```swift
        let schema = Schema([
            Club.self,
            Shot.self,
            Session.self,
            CalibrationProfile.self,
        ])
```
(Leave the rest of `chunkyApp` unchanged. `ContentView()` still loads for now; `Item` is removed from the schema but its file/usage in `ContentView` is cleaned up in Task 11.)

- [ ] **Step 5: Run test + build** — Run the test (`-only-testing:chunkyTests/SessionModelTests`) → `** TEST SUCCEEDED **`, then a full build → `** BUILD SUCCEEDED **`. If `ContentView`/`Item` now fail to compile because `Item` is out of the schema, that's expected only if `Item.swift` was deleted — it is NOT deleted here, so the app still compiles.

- [ ] **Step 6: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/DataStore/Session.swift chunky/chunky/DataStore/CalibrationProfile.swift chunky/chunky/chunkyApp.swift chunky/chunkyTests/SessionModelTests.swift && \
git commit -m "feat(datastore): add Session & CalibrationProfile models; wire app schema

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Statistics helpers

**Files:**
- Create: `chunky/chunky/DataStore/Stats.swift`
- Test: `chunky/chunkyTests/StatsTests.swift`

**Interfaces:**
- Produces: `nonisolated enum Stats` with `static func mean(_: [Double]) -> Double?`, `median(_: [Double]) -> Double?`, `standardDeviation(_: [Double]) -> Double?` (sample std dev, needs ≥ 2 points; nil otherwise), `minMax(_: [Double]) -> (min: Double, max: Double)?`. All return nil on empty.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/StatsTests.swift
import XCTest
@testable import chunky

final class StatsTests: XCTestCase {
    func testMean() { XCTAssertEqual(Stats.mean([2, 4, 6])!, 4, accuracy: 1e-12) }
    func testMedianOdd() { XCTAssertEqual(Stats.median([5, 1, 3])!, 3, accuracy: 1e-12) }
    func testMedianEven() { XCTAssertEqual(Stats.median([1, 2, 3, 4])!, 2.5, accuracy: 1e-12) }
    func testSampleStdDev() {
        // sample stddev of [2,4,4,4,5,5,7,9] = 2.138...
        XCTAssertEqual(Stats.standardDeviation([2,4,4,4,5,5,7,9])!, 2.13809, accuracy: 1e-4)
    }
    func testStdDevNeedsTwo() { XCTAssertNil(Stats.standardDeviation([5])) }
    func testMinMax() {
        let mm = Stats.minMax([3, -1, 7])!
        XCTAssertEqual(mm.min, -1, accuracy: 1e-12)
        XCTAssertEqual(mm.max, 7, accuracy: 1e-12)
    }
    func testEmptyReturnsNil() {
        XCTAssertNil(Stats.mean([]))
        XCTAssertNil(Stats.median([]))
        XCTAssertNil(Stats.minMax([]))
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/StatsTests ...` — Expected: `cannot find 'Stats' in scope`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/DataStore/Stats.swift
import Foundation

nonisolated enum Stats {
    static func mean(_ xs: [Double]) -> Double? {
        xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
    }

    static func median(_ xs: [Double]) -> Double? {
        guard !xs.isEmpty else { return nil }
        let s = xs.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    /// Sample (n−1) standard deviation. Requires at least two values.
    static func standardDeviation(_ xs: [Double]) -> Double? {
        guard xs.count >= 2, let m = mean(xs) else { return nil }
        let sumSq = xs.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (sumSq / Double(xs.count - 1)).squareRoot()
    }

    static func minMax(_ xs: [Double]) -> (min: Double, max: Double)? {
        guard let lo = xs.min(), let hi = xs.max() else { return nil }
        return (lo, hi)
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — same as Step 2 — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/DataStore/Stats.swift chunky/chunkyTests/StatsTests.swift && \
git commit -m "feat(datastore): add statistics helpers (mean/median/stddev/minmax)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: ShotRecord projection + ClubAggregates

**Files:**
- Create: `chunky/chunky/DataStore/ShotRecord.swift`, `chunky/chunky/DataStore/ClubAggregates.swift`
- Test: `chunky/chunkyTests/ClubAggregatesTests.swift`

**Interfaces:**
- Consumes: `Stats`, `SpinSource`, `ConfidenceLevel`.
- Produces:
  - `nonisolated struct ShotRecord: Equatable, Identifiable` — `id: UUID`, `timestamp: Date`, `clubID: UUID?`, `clubName: String`, `carryMeters`, `ballSpeedMS`, `launchAngleDeg`, `spinRPM: Double`, `spinSource: SpinSource`, `clubSpeedMS: Double?`, `smashFactor: Double?`, `confidence: ConfidenceLevel`, `isExcludedFromAverages: Bool`.
  - `nonisolated struct ClubAggregates: Equatable` — `shotCount: Int`, `meanCarryMeters`, `medianCarryMeters`, `carryStdDevMeters`, `minCarryMeters`, `maxCarryMeters`, `meanBallSpeedMS`, `meanLaunchAngleDeg`, `meanSpinRPM: Double`, `meanClubSpeedMS: Double?`, `meanSmashFactor: Double?`; `static func compute(from records: [ShotRecord]) -> ClubAggregates?` (uses only non-excluded; nil if none; std dev is 0 when a single shot).

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ClubAggregatesTests.swift
import XCTest
@testable import chunky

final class ClubAggregatesTests: XCTestCase {
    private func rec(carry: Double, excluded: Bool = false, club: Double? = nil, smash: Double? = nil) -> ShotRecord {
        ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil, clubName: "7-Iron",
                   carryMeters: carry, ballSpeedMS: 50, launchAngleDeg: 16, spinRPM: 6500,
                   spinSource: .modeled, clubSpeedMS: club, smashFactor: smash,
                   confidence: .medium, isExcludedFromAverages: excluded)
    }

    func testAggregatesOverNonExcluded() {
        let agg = ClubAggregates.compute(from: [rec(carry: 150), rec(carry: 160), rec(carry: 170)])!
        XCTAssertEqual(agg.shotCount, 3)
        XCTAssertEqual(agg.meanCarryMeters, 160, accuracy: 1e-9)
        XCTAssertEqual(agg.medianCarryMeters, 160, accuracy: 1e-9)
        XCTAssertEqual(agg.minCarryMeters, 150, accuracy: 1e-9)
        XCTAssertEqual(agg.maxCarryMeters, 170, accuracy: 1e-9)
        XCTAssertEqual(agg.carryStdDevMeters, 10, accuracy: 1e-9)
    }

    func testExcludedShotsIgnored() {
        let agg = ClubAggregates.compute(from: [rec(carry: 150), rec(carry: 999, excluded: true)])!
        XCTAssertEqual(agg.shotCount, 1)
        XCTAssertEqual(agg.meanCarryMeters, 150, accuracy: 1e-9)
        XCTAssertEqual(agg.carryStdDevMeters, 0, accuracy: 1e-9) // single shot -> 0
    }

    func testAllExcludedOrEmptyReturnsNil() {
        XCTAssertNil(ClubAggregates.compute(from: []))
        XCTAssertNil(ClubAggregates.compute(from: [rec(carry: 150, excluded: true)]))
    }

    func testClubSpeedAndSmashOnlyWhenPresent() {
        let noneAgg = ClubAggregates.compute(from: [rec(carry: 150)])!
        XCTAssertNil(noneAgg.meanClubSpeedMS)
        XCTAssertNil(noneAgg.meanSmashFactor)
        let someAgg = ClubAggregates.compute(from: [rec(carry: 150, club: 40, smash: 1.33),
                                                    rec(carry: 160, club: 42, smash: 1.34)])!
        XCTAssertEqual(someAgg.meanClubSpeedMS!, 41, accuracy: 1e-9)
        XCTAssertEqual(someAgg.meanSmashFactor!, 1.335, accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/ClubAggregatesTests ...` — Expected: `cannot find 'ShotRecord' in scope`.

- [ ] **Step 3: Write implementations**

```swift
// chunky/chunky/DataStore/ShotRecord.swift
import Foundation

/// Framework-free value projection of a persisted Shot, so filtering, aggregation,
/// and CSV export are unit-testable without SwiftData.
nonisolated struct ShotRecord: Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let clubID: UUID?
    let clubName: String
    let carryMeters: Double
    let ballSpeedMS: Double
    let launchAngleDeg: Double
    let spinRPM: Double
    let spinSource: SpinSource
    let clubSpeedMS: Double?
    let smashFactor: Double?
    let confidence: ConfidenceLevel
    let isExcludedFromAverages: Bool
}
```

```swift
// chunky/chunky/DataStore/ClubAggregates.swift
import Foundation

nonisolated struct ClubAggregates: Equatable {
    let shotCount: Int
    let meanCarryMeters: Double
    let medianCarryMeters: Double
    let carryStdDevMeters: Double
    let minCarryMeters: Double
    let maxCarryMeters: Double
    let meanBallSpeedMS: Double
    let meanLaunchAngleDeg: Double
    let meanSpinRPM: Double
    let meanClubSpeedMS: Double?
    let meanSmashFactor: Double?

    /// Aggregate over the non-excluded records. Returns nil if none remain.
    static func compute(from records: [ShotRecord]) -> ClubAggregates? {
        let kept = records.filter { !$0.isExcludedFromAverages }
        guard !kept.isEmpty else { return nil }
        let carries = kept.map(\.carryMeters)
        let clubSpeeds = kept.compactMap(\.clubSpeedMS)
        let smashes = kept.compactMap(\.smashFactor)
        return ClubAggregates(
            shotCount: kept.count,
            meanCarryMeters: Stats.mean(carries)!,
            medianCarryMeters: Stats.median(carries)!,
            carryStdDevMeters: Stats.standardDeviation(carries) ?? 0,
            minCarryMeters: Stats.minMax(carries)!.min,
            maxCarryMeters: Stats.minMax(carries)!.max,
            meanBallSpeedMS: Stats.mean(kept.map(\.ballSpeedMS))!,
            meanLaunchAngleDeg: Stats.mean(kept.map(\.launchAngleDeg))!,
            meanSpinRPM: Stats.mean(kept.map(\.spinRPM))!,
            meanClubSpeedMS: clubSpeeds.isEmpty ? nil : Stats.mean(clubSpeeds),
            meanSmashFactor: smashes.isEmpty ? nil : Stats.mean(smashes)
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — same as Step 2 — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/DataStore/ShotRecord.swift chunky/chunky/DataStore/ClubAggregates.swift chunky/chunkyTests/ClubAggregatesTests.swift && \
git commit -m "feat(datastore): add ShotRecord projection and per-club aggregates

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Shot filtering & sorting

**Files:**
- Create: `chunky/chunky/DataStore/ShotFilter.swift`
- Test: `chunky/chunkyTests/ShotFilterTests.swift`

**Interfaces:**
- Consumes: `ShotRecord`, `ConfidenceLevel`.
- Produces: `nonisolated struct ShotFilter` with fields `clubID: UUID?`, `confidence: ConfidenceLevel?`, `includeExcluded: Bool` (default true), `dateRange: ClosedRange<Date>?`, and `func apply(to: [ShotRecord]) -> [ShotRecord]`; plus `nonisolated enum ShotSort { case newest, oldest, longestCarry, shortestCarry; func sort(_: [ShotRecord]) -> [ShotRecord] }`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ShotFilterTests.swift
import XCTest
@testable import chunky

final class ShotFilterTests: XCTestCase {
    private func rec(_ carry: Double, _ t: TimeInterval, club: UUID, conf: ConfidenceLevel = .high, excluded: Bool = false) -> ShotRecord {
        ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: t), clubID: club, clubName: "C",
                   carryMeters: carry, ballSpeedMS: 50, launchAngleDeg: 16, spinRPM: 6000,
                   spinSource: .modeled, clubSpeedMS: nil, smashFactor: nil, conf: conf as ConfidenceLevel,
                   isExcludedFromAverages: excluded) // NOTE: label is `confidence:`; see impl
    }

    func testFilterByClubAndExcluded() {
        let a = UUID(), b = UUID()
        let recs = [rec(150, 1, club: a), rec(160, 2, club: b), rec(170, 3, club: a, excluded: true)]
        var f = ShotFilter(); f.clubID = a; f.includeExcluded = false
        let out = f.apply(to: recs)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out.first?.carryMeters, 150, accuracy: 1e-9)
    }

    func testFilterByConfidenceAndDate() {
        let a = UUID()
        let recs = [rec(150, 10, club: a, conf: .low), rec(160, 20, club: a, conf: .high)]
        var f = ShotFilter(); f.confidence = .high
        XCTAssertEqual(f.apply(to: recs).count, 1)
        var g = ShotFilter(); g.dateRange = Date(timeIntervalSince1970: 15)...Date(timeIntervalSince1970: 25)
        XCTAssertEqual(g.apply(to: recs).count, 1)
    }

    func testSort() {
        let a = UUID()
        let recs = [rec(150, 1, club: a), rec(170, 3, club: a), rec(160, 2, club: a)]
        XCTAssertEqual(ShotSort.longestCarry.sort(recs).map(\.carryMeters), [170, 160, 150])
        XCTAssertEqual(ShotSort.newest.sort(recs).first?.timestamp, Date(timeIntervalSince1970: 3))
    }
}
```

*(Correct the test's `rec` helper to use the real `confidence:` label — the plan's `ShotRecord` init is memberwise; the implementer writes the helper cleanly.)*

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/ShotFilterTests ...` — Expected: `cannot find 'ShotFilter' in scope`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/DataStore/ShotFilter.swift
import Foundation

nonisolated struct ShotFilter {
    var clubID: UUID?
    var confidence: ConfidenceLevel?
    var includeExcluded: Bool
    var dateRange: ClosedRange<Date>?

    init(clubID: UUID? = nil, confidence: ConfidenceLevel? = nil,
         includeExcluded: Bool = true, dateRange: ClosedRange<Date>? = nil) {
        self.clubID = clubID
        self.confidence = confidence
        self.includeExcluded = includeExcluded
        self.dateRange = dateRange
    }

    func apply(to records: [ShotRecord]) -> [ShotRecord] {
        records.filter { r in
            if let clubID, r.clubID != clubID { return false }
            if let confidence, r.confidence != confidence { return false }
            if !includeExcluded && r.isExcludedFromAverages { return false }
            if let dateRange, !dateRange.contains(r.timestamp) { return false }
            return true
        }
    }
}

nonisolated enum ShotSort {
    case newest, oldest, longestCarry, shortestCarry

    func sort(_ records: [ShotRecord]) -> [ShotRecord] {
        switch self {
        case .newest: records.sorted { $0.timestamp > $1.timestamp }
        case .oldest: records.sorted { $0.timestamp < $1.timestamp }
        case .longestCarry: records.sorted { $0.carryMeters > $1.carryMeters }
        case .shortestCarry: records.sorted { $0.carryMeters < $1.carryMeters }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — same as Step 2 — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/DataStore/ShotFilter.swift chunky/chunkyTests/ShotFilterTests.swift && \
git commit -m "feat(datastore): add shot filtering and sorting

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: CSV export

**Files:**
- Create: `chunky/chunky/DataStore/CSVExport.swift`
- Test: `chunky/chunkyTests/CSVExportTests.swift`

**Interfaces:**
- Consumes: `ShotRecord`, `ClubAggregates`, `Units`, `Conversions`.
- Produces: `nonisolated enum CSVExport` with `static func shots(_: [ShotRecord], units: Units) -> String` and `static func clubAverages(_ rows: [(clubName: String, aggregates: ClubAggregates)], units: Units) -> String`. Header row + one row per item; carry/speeds converted to the chosen units; fields comma-joined; text fields with commas are quoted.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/CSVExportTests.swift
import XCTest
@testable import chunky

final class CSVExportTests: XCTestCase {
    func testShotsCSVHeaderAndRow() {
        let rec = ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil,
                             clubName: "7-Iron", carryMeters: 91.44, ballSpeedMS: 44.704,
                             launchAngleDeg: 16, spinRPM: 6500, spinSource: .modeled,
                             clubSpeedMS: nil, smashFactor: nil, confidence: .medium,
                             isExcludedFromAverages: false)
        let csv = CSVExport.shots([rec], units: .yards)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertTrue(lines[0].contains("club"))
        XCTAssertTrue(lines[0].contains("carry_yd"))
        XCTAssertTrue(lines[1].contains("7-Iron"))
        XCTAssertTrue(lines[1].contains("100")) // 91.44 m -> 100 yd
    }

    func testClubWithCommaIsQuoted() {
        let rec = ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil,
                             clubName: "Driver, backup", carryMeters: 100, ballSpeedMS: 70,
                             launchAngleDeg: 11, spinRPM: 2600, spinSource: .modeled,
                             clubSpeedMS: nil, smashFactor: nil, confidence: .high,
                             isExcludedFromAverages: false)
        XCTAssertTrue(CSVExport.shots([rec], units: .meters).contains("\"Driver, backup\""))
    }

    func testAveragesCSV() {
        let agg = ClubAggregates.compute(from: [
            ShotRecord(id: UUID(), timestamp: Date(timeIntervalSince1970: 0), clubID: nil, clubName: "7-Iron",
                       carryMeters: 91.44, ballSpeedMS: 50, launchAngleDeg: 16, spinRPM: 6500,
                       spinSource: .modeled, clubSpeedMS: nil, smashFactor: nil, confidence: .high,
                       isExcludedFromAverages: false)])!
        let csv = CSVExport.clubAverages([(clubName: "7-Iron", aggregates: agg)], units: .yards)
        XCTAssertTrue(csv.contains("mean_carry_yd"))
        XCTAssertTrue(csv.contains("7-Iron"))
        XCTAssertTrue(csv.contains("100"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/CSVExportTests ...` — Expected: `cannot find 'CSVExport' in scope`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/DataStore/CSVExport.swift
import Foundation

nonisolated enum CSVExport {
    private static func field(_ s: String) -> String {
        (s.contains(",") || s.contains("\"") || s.contains("\n"))
            ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
            : s
    }
    private static func num(_ x: Double) -> String { String(Int(x.rounded())) }

    static func shots(_ records: [ShotRecord], units: Units) -> String {
        let u = units.abbreviation
        var lines = ["timestamp,club,carry_\(u),ball_speed_mph,launch_deg,spin_rpm,spin_source,confidence,excluded"]
        for r in records {
            let cols = [
                ISO8601DateFormatter().string(from: r.timestamp),
                field(r.clubName),
                num(units.carry(fromMeters: r.carryMeters)),
                num(Conversions.msToMPH(r.ballSpeedMS)),
                num(r.launchAngleDeg),
                num(r.spinRPM),
                r.spinSource.rawValue,
                r.confidence.rawValue,
                r.isExcludedFromAverages ? "yes" : "no",
            ]
            lines.append(cols.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func clubAverages(_ rows: [(clubName: String, aggregates: ClubAggregates)], units: Units) -> String {
        let u = units.abbreviation
        var lines = ["club,shots,mean_carry_\(u),median_carry_\(u),stddev_\(u),min_\(u),max_\(u),mean_ball_mph,mean_launch_deg,mean_spin_rpm"]
        for row in rows {
            let a = row.aggregates
            let cols = [
                field(row.clubName),
                String(a.shotCount),
                num(units.carry(fromMeters: a.meanCarryMeters)),
                num(units.carry(fromMeters: a.medianCarryMeters)),
                num(units.carry(fromMeters: a.carryStdDevMeters)),
                num(units.carry(fromMeters: a.minCarryMeters)),
                num(units.carry(fromMeters: a.maxCarryMeters)),
                num(Conversions.msToMPH(a.meanBallSpeedMS)),
                num(a.meanLaunchAngleDeg),
                num(a.meanSpinRPM),
            ]
            lines.append(cols.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — same as Step 2 — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/DataStore/CSVExport.swift chunky/chunkyTests/CSVExportTests.swift && \
git commit -m "feat(datastore): add CSV export for shots and club averages

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: ShotStore (persistence rules + bridges)

**Files:**
- Create: `chunky/chunky/DataStore/ShotStore.swift`
- Test: `chunky/chunkyTests/ShotStoreTests.swift`

**Interfaces:**
- Consumes: all models, `ShotRecord`, `ShotResult` (Plan 2).
- Produces: `@MainActor struct ShotStore` holding a `ModelContext`, with:
  - `func record(from: Shot) -> ShotRecord` (projection).
  - `func saveShot(_ result: ShotResult, to club: Club, session: Session?, rawTrackJSON: String?) -> Shot` (auto-save; inserts a Shot built from the ShotResult, links club+session, saves).
  - `func setExcluded(_ shot: Shot, _ excluded: Bool)`.
  - `func deleteShots(_ shots: [Shot])`.
  - `func addClub(name:type:modeledSpinRPM:) -> Club` (order = current max + 1).
  - `func renameClub(_:to:)`, `func reorderClubs(_ ordered: [Club])`.
  - `func removeClub(_ club: Club)` — hard-delete if `club.shots.isEmpty`, else set `isArchived = true`.

- [ ] **Step 1: Write the failing test**

```swift
// chunky/chunkyTests/ShotStoreTests.swift
import XCTest
import SwiftData
@testable import chunky

@MainActor
final class ShotStoreTests: XCTestCase {
    private func makeStore() throws -> ShotStore {
        let container = try ModelContainer(
            for: Club.self, Shot.self, Session.self, CalibrationProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ShotStore(context: ModelContext(container))
    }

    private func sampleResult(carry: Double = 150) -> ShotResult {
        ShotResult(ballSpeedMS: 53.6, launchAngleDeg: 16.3, azimuthDeg: 0, spinRPM: 6500,
                   spinSource: .modeled, spinAxisTiltDeg: 0, carryMeters: carry,
                   confidence: .medium, fitRmsResidualMeters: 0.001, usedFrameCount: 8)
    }

    func testSaveShotAutoLinksClub() throws {
        let store = try makeStore()
        let club = store.addClub(name: "7-Iron", type: .iron, modeledSpinRPM: 6500)
        let shot = store.saveShot(sampleResult(), to: club, session: nil, rawTrackJSON: "[]")
        XCTAssertEqual(shot.club?.name, "7-Iron")
        XCTAssertEqual(shot.rawTrackJSON, "[]")
        XCTAssertEqual(club.shots.count, 1)
    }

    func testExcludeAndDelete() throws {
        let store = try makeStore()
        let club = store.addClub(name: "7-Iron", type: .iron, modeledSpinRPM: 6500)
        let s1 = store.saveShot(sampleResult(carry: 150), to: club, session: nil, rawTrackJSON: nil)
        _ = store.saveShot(sampleResult(carry: 160), to: club, session: nil, rawTrackJSON: nil)
        store.setExcluded(s1, true)
        XCTAssertTrue(s1.isExcludedFromAverages)
        let recs = club.shots.map(store.record(from:))
        XCTAssertEqual(ClubAggregates.compute(from: recs)!.shotCount, 1) // excluded dropped
        store.deleteShots([s1])
        XCTAssertEqual(club.shots.count, 1)
    }

    func testRemoveClubSoftArchivesWhenItHasShots() throws {
        let store = try makeStore()
        let club = store.addClub(name: "7-Iron", type: .iron, modeledSpinRPM: 6500)
        _ = store.saveShot(sampleResult(), to: club, session: nil, rawTrackJSON: nil)
        store.removeClub(club)
        XCTAssertTrue(club.isArchived)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<Club>()).count, 1) // still present
    }

    func testRemoveClubHardDeletesWhenEmpty() throws {
        let store = try makeStore()
        let club = store.addClub(name: "Spare", type: .wedge, modeledSpinRPM: 9000)
        store.removeClub(club)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<Club>()).count, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:chunkyTests/ShotStoreTests ...` — Expected: `cannot find 'ShotStore' in scope`.

- [ ] **Step 3: Write implementation**

```swift
// chunky/chunky/DataStore/ShotStore.swift
import Foundation
import SwiftData

@MainActor
struct ShotStore {
    let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func record(from shot: Shot) -> ShotRecord {
        ShotRecord(
            id: shot.id, timestamp: shot.timestamp, clubID: shot.club?.id,
            clubName: shot.club?.name ?? "—", carryMeters: shot.carryMeters,
            ballSpeedMS: shot.ballSpeedMS, launchAngleDeg: shot.launchAngleDeg,
            spinRPM: shot.spinRPM, spinSource: shot.spinSource,
            clubSpeedMS: shot.clubSpeedMS, smashFactor: shot.smashFactor,
            confidence: shot.confidence, isExcludedFromAverages: shot.isExcludedFromAverages)
    }

    @discardableResult
    func saveShot(_ result: ShotResult, to club: Club, session: Session?, rawTrackJSON: String?) -> Shot {
        let shot = Shot(
            timestamp: Date(), ballSpeedMS: result.ballSpeedMS, launchAngleDeg: result.launchAngleDeg,
            azimuthDeg: result.azimuthDeg, spinRPM: result.spinRPM, spinSource: result.spinSource,
            spinAxisTiltDeg: result.spinAxisTiltDeg, carryMeters: result.carryMeters,
            confidence: result.confidence, rawTrackJSON: rawTrackJSON)
        shot.club = club
        shot.session = session
        context.insert(shot)
        try? context.save()
        return shot
    }

    func setExcluded(_ shot: Shot, _ excluded: Bool) {
        shot.isExcludedFromAverages = excluded
        try? context.save()
    }

    func deleteShots(_ shots: [Shot]) {
        for s in shots { context.delete(s) }
        try? context.save()
    }

    @discardableResult
    func addClub(name: String, type: ClubType, modeledSpinRPM: Double) -> Club {
        let maxOrder = (try? context.fetch(FetchDescriptor<Club>()))?.map(\.order).max() ?? -1
        let club = Club(name: name, type: type, order: maxOrder + 1, modeledSpinRPM: modeledSpinRPM)
        context.insert(club)
        try? context.save()
        return club
    }

    func renameClub(_ club: Club, to name: String) {
        club.name = name
        try? context.save()
    }

    func reorderClubs(_ ordered: [Club]) {
        for (index, club) in ordered.enumerated() { club.order = index }
        try? context.save()
    }

    func removeClub(_ club: Club) {
        if club.shots.isEmpty {
            context.delete(club)
        } else {
            club.isArchived = true
        }
        try? context.save()
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — same as Step 2 — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/DataStore/ShotStore.swift chunky/chunkyTests/ShotStoreTests.swift && \
git commit -m "feat(datastore): add ShotStore (auto-save, exclude, delete, club rules)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: App navigation shell

**Files:**
- Create: `chunky/chunky/Features/RootView.swift`
- Modify: `chunky/chunky/chunkyApp.swift` (present `RootView` instead of `ContentView`)
- Delete: `chunky/chunky/ContentView.swift`, `chunky/chunky/Item.swift` (template leftovers)
- Test: none (build + preview).

**Interfaces:**
- Produces: `struct RootView: View` — a `TabView` with three tabs (Averages, History, Clubs), each a `NavigationStack`, background `Theme.rangeDusk`, tint `Theme.optic`. Uses placeholder text bodies for the three screens for now (real screens land in Tasks 12–14, which replace the placeholders).

- [ ] **Step 1: Create `RootView`**

```swift
// chunky/chunky/Features/RootView.swift
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { AveragesView() }
                .tabItem { Label("Averages", systemImage: "chart.bar.fill") }
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "list.bullet") }
            NavigationStack { ClubsView() }
                .tabItem { Label("Clubs", systemImage: "bag.fill") }
        }
        .tint(Theme.optic)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Club.self, Shot.self, Session.self, CalibrationProfile.self], inMemory: true)
}
```
**Note:** `AveragesView`/`HistoryView`/`ClubsView` are created in Tasks 12–14. To keep THIS task building on its own, add minimal placeholder views in their target files (e.g. `struct ClubsView: View { var body: some View { Text("Clubs").foregroundStyle(Theme.chalk) } }`) inside `Features/Clubs/ClubsView.swift`, `Features/History/HistoryView.swift`, `Features/Averages/AveragesView.swift`. Tasks 12–14 then flesh these out (modify, not create).

- [ ] **Step 2: Point the app at `RootView`** — in `chunky/chunky/chunkyApp.swift`, change `ContentView()` to `RootView()` inside the `WindowGroup`.

- [ ] **Step 3: Delete template leftovers** — `git rm chunky/chunky/ContentView.swift chunky/chunky/Item.swift`. (The schema no longer references `Item`; nothing else uses `ContentView`.)

- [ ] **Step 4: Build** — full build → `** BUILD SUCCEEDED **`. Also run the full test suite once (`-only-testing:chunkyTests`) to confirm removing `Item` broke nothing → `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Features/RootView.swift chunky/chunky/Features/Clubs/ClubsView.swift chunky/chunky/Features/History/HistoryView.swift chunky/chunky/Features/Averages/AveragesView.swift chunky/chunky/chunkyApp.swift && \
git rm chunky/chunky/ContentView.swift chunky/chunky/Item.swift && \
git commit -m "feat(ui): add tabbed RootView; remove template ContentView/Item

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Clubs manager screen

**Files:**
- Modify: `chunky/chunky/Features/Clubs/ClubsView.swift`
- Test: `chunky/chunkyUITests/ClubsSmokeUITests.swift` (one add-club smoke flow)

**Interfaces:**
- Consumes: `Club`, `ShotStore`, `ClubType`, `Theme`.
- Produces: `struct ClubsView: View` — lists non-archived clubs sorted by `order`; add (name + type + modeled spin), rename, reorder (`.onMove`), and remove (soft-archive if it has shots, else delete) via `ShotStore`; edit modeled-spin default. Uses `@Environment(\.modelContext)` to build a `ShotStore`, and `@Query(sort: \Club.order)` for the list. Themed per the design system; empty state invites action ("No clubs yet. Add your first club to start logging shots.").

- [ ] **Step 1: Implement `ClubsView`**

```swift
// chunky/chunky/Features/Clubs/ClubsView.swift
import SwiftUI
import SwiftData

struct ClubsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Club.order) private var clubs: [Club]
    @State private var showingAdd = false

    private var store: ShotStore { ShotStore(context: context) }
    private var activeClubs: [Club] { clubs.filter { !$0.isArchived } }

    var body: some View {
        List {
            if activeClubs.isEmpty {
                Text("No clubs yet. Add your first club to start logging shots.")
                    .font(Theme.number(15)).foregroundStyle(Theme.mist)
                    .listRowBackground(Theme.turf)
            }
            ForEach(activeClubs) { club in
                ClubRow(club: club, store: store)
                    .listRowBackground(Theme.turf)
            }
            .onMove { indices, newOffset in
                var reordered = activeClubs
                reordered.move(fromOffsets: indices, toOffset: newOffset)
                store.reorderClubs(reordered)
            }
            .onDelete { indices in
                indices.map { activeClubs[$0] }.forEach(store.removeClub)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.rangeDusk)
        .navigationTitle("Clubs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarLeading) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) { AddClubSheet(store: store) }
    }
}

private struct ClubRow: View {
    @Bindable var club: Club
    let store: ShotStore
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $club.name).font(Theme.number(17)).foregroundStyle(Theme.chalk)
                Text(club.type.rawValue.uppercased()).font(Theme.eyebrow).kerning(1.2).foregroundStyle(Theme.mist)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(club.modeledSpinRPM))").font(Theme.number(15)).foregroundStyle(Theme.mist)
                Text("rpm model").font(Theme.eyebrow).foregroundStyle(Theme.mist)
            }
        }
    }
}

private struct AddClubSheet: View {
    let store: ShotStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type: ClubType = .iron
    @State private var spin = 6500.0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. 7-Iron)", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(ClubType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Stepper("Modeled spin: \(Int(spin)) rpm", value: $spin, in: 1500...11000, step: 100)
            }
            .navigationTitle("Add club")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addClub(name: name.isEmpty ? "New club" : name, type: type, modeledSpinRPM: spin)
                        dismiss()
                    }.disabled(name.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
```

- [ ] **Step 2: Write a UI smoke test**

```swift
// chunky/chunkyUITests/ClubsSmokeUITests.swift
import XCTest

final class ClubsSmokeUITests: XCTestCase {
    func testAddClubFlow() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Clubs"].tap()
        app.navigationBars.buttons["Add"].firstMatch.tap()   // leading + button label
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("7-Iron")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.textFields["7-Iron"].waitForExistence(timeout: 5))
    }
}
```
*(If the leading "+" button has no accessibility label "Add", the implementer adds `.accessibilityLabel("Add")` to it so the test can find it. Keep app + test in sync.)*

- [ ] **Step 3: Build + run the UI smoke test**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test -only-testing:chunkyUITests/ClubsSmokeUITests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`. (If the UI test proves flaky in the harness, fall back to `build` succeeding + a `#Preview`, and note it.)

- [ ] **Step 4: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Features/Clubs/ClubsView.swift chunky/chunkyUITests/ClubsSmokeUITests.swift && \
git commit -m "feat(ui): clubs manager (add/rename/reorder/remove, modeled spin)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: Shot History screen

**Files:**
- Modify: `chunky/chunky/Features/History/HistoryView.swift`
- Create: `chunky/chunky/Features/History/ShotDetailView.swift`
- Test: none new (build + preview; the filter/sort logic is already unit-tested in Task 8).

**Interfaces:**
- Consumes: `Shot`, `ShotStore`, `ShotFilter`, `ShotSort`, `ShotRecord`, `Units`, `Theme`, `ConfidenceStyle`.
- Produces:
  - `struct HistoryView: View` — `@Query(sort: \Shot.timestamp, order: .reverse)` all shots; projects to `[ShotRecord]` via `ShotStore.record(from:)`; applies a `ShotFilter` + `ShotSort` chosen in a toolbar menu; renders rows (club, carry in the current `Units`, confidence dot via `Theme.confidenceColor`, excluded shots dimmed + a flag mark). Multi-select via `EditMode` + a selection `Set<UUID>`; a bottom bar offers **Delete** and **Exclude** for the selection (both via `ShotStore`). Each row taps into `ShotDetailView`. Empty state: "No shots yet. Tag a club and take a swing."
  - `struct ShotDetailView: View` — full metrics (carry, ball speed, launch, spin + source, confidence, club speed/smash when present) and the raw-track presence indicator; per-shot **Exclude (mishit)** toggle and **Delete** (one tap each, per spec §11).

- [ ] **Step 1: Implement `HistoryView` and `ShotDetailView`** (complete, themed SwiftUI; drives the already-tested `ShotFilter`/`ShotSort`/aggregate-free projection). The implementer writes idiomatic SwiftUI following the design system: `Theme.rangeDusk` background, `Theme.number(...)` for the carry value, `Theme.confidenceColor(...)` for the confidence dot, `Theme.flag` for excluded/delete, tabular carry via `Units.formattedCarry(fromMeters:)`. Selection toolbar shows "Delete" (`Theme.flag`) and "Exclude". Detail view carry is the largest element (`Theme.display(44)`, `Theme.optic`). Provide a `#Preview` seeding an in-memory container with two clubs and a few shots.

  Key wiring (must hold):
  - Convert models → records: `let records = shots.map { store.record(from: $0) }` then `sort.sort(filter.apply(to: records))`.
  - Row displays `record.clubName`, `units.formattedCarry(fromMeters: record.carryMeters)`, confidence dot `Theme.confidenceColor(record.confidence)`, and dims + shows a `flag` marker when `record.isExcludedFromAverages`.
  - Bulk actions map selected `UUID`s back to `Shot` objects (match by `id`) and call `store.deleteShots(_:)` / `store.setExcluded(_:_:)`.

- [ ] **Step 2: Build + preview render**

Run:

```bash
cd /Users/kason/Documents/github/Chunky/chunky && \
xcodebuild -project chunky.xcodeproj -scheme chunky \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Features/History/HistoryView.swift chunky/chunky/Features/History/ShotDetailView.swift && \
git commit -m "feat(ui): shot history with filters, sort, multi-select, detail

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: Averages dashboard + gapping ladder

**Files:**
- Modify: `chunky/chunky/Features/Averages/AveragesView.swift`
- Create: `chunky/chunky/Features/Averages/GappingLadder.swift`
- Test: none new (build + preview; aggregates are unit-tested in Task 7).

**Interfaces:**
- Consumes: `Club`, `Shot`, `ShotStore`, `ClubAggregates`, `ShotRecord`, `Units`, `Theme`.
- Produces:
  - `struct AveragesView: View` — for each non-archived club with ≥1 non-excluded shot, computes `ClubAggregates.compute(from:)` over that club's projected records; renders one card per club (club name eyebrow, big mean carry in `Theme.optic` via `Theme.display`, confidence-neutral secondary stats: median, std dev ±, n, mean ball speed/launch/spin, and club speed/smash when present). Rows are ordered by mean carry descending. A `Units` toggle (yd/m) in the toolbar. A **Share CSV** toolbar action exporting `CSVExport.clubAverages(...)` via a share sheet. Empty state: "No shots yet. Your yardages will show up here as you log them."
  - `struct GappingLadder: View` — the signature: a vertical ladder where each club is a rung whose bar length ∝ mean carry (normalized to the longest), labeled with club + carry, so gaps read as visual spacing. Uses `Theme.optic` for the longest club's rung and `Theme.chalk`/`Theme.mist` for others; hairline `Theme.turfLine` rungs. Shown at the top of `AveragesView`.

- [ ] **Step 1: Implement `GappingLadder`** (complete SwiftUI) — takes `[(clubName: String, carryMeters: Double)]` sorted descending + a `Units`; draws each rung with a `GeometryReader`-based bar width `= carry / maxCarry`. Pure-presentation; deterministic from inputs. Provide a `#Preview` with sample rungs.

- [ ] **Step 2: Implement `AveragesView`** (complete, themed SwiftUI) — assembles per-club aggregates and feeds `GappingLadder` + the stat cards; wires the units toggle and the CSV share sheet (`ShareLink` with the CSV string). `#Preview` seeds an in-memory container with a few clubs+shots so the dashboard and ladder render.

- [ ] **Step 3: Build + preview render** — full `build` → `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
cd /Users/kason/Documents/github/Chunky && \
git add chunky/chunky/Features/Averages/AveragesView.swift chunky/chunky/Features/Averages/GappingLadder.swift && \
git commit -m "feat(ui): per-club averages dashboard with gapping ladder + CSV export

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 15: Full-suite green gate & verification

**Files:** none (verification only; no commit).

- [ ] **Step 1: Run the entire unit-test suite** — `... test -only-testing:chunkyTests 2>&1 | tail -30` — Expected `** TEST SUCCEEDED **` (all Plan 1/2/3 unit tests pass together).

- [ ] **Step 2: Run the UI smoke test** — `... test -only-testing:chunkyUITests/ClubsSmokeUITests 2>&1 | tail -20` — Expected `** TEST SUCCEEDED **` (or, if it was demoted to build-only in Task 12, confirm the app builds and note it).

- [ ] **Step 3: Confirm the data core stayed SwiftUI-free** — Run:

```bash
cd /Users/kason/Documents/github/Chunky && \
! grep -rEl "import (SwiftUI|Charts)" chunky/chunky/DataStore/ && \
echo "OK: DataStore is UI-free"
```
Expected: `OK: DataStore is UI-free`.

- [ ] **Step 4: Confirm working tree clean** — `git status --short` → empty. Do not commit in this task.

---

## Self-Review

**1. Spec coverage:**
- §10 models Club/Session/Shot/CalibrationProfile → Tasks 3–5. ✅
- Auto-save every shot to its club → Task 10 `saveShot`. ✅
- Customizable club list (add/rename/reorder/remove; soft-archive vs hard-delete) → Tasks 10, 12. ✅
- Delete single/multi shots; recompute → Tasks 10, 13, 7. ✅
- Exclude (not delete) flag, kept but omitted from aggregates, visually marked → Tasks 4, 7, 10, 13. ✅
- Per-club aggregates (count, mean & median carry, std dev, min/max, mean ball/launch/spin, +club speed/smash where present) → Tasks 6–7. ✅
- Persist rawTrackJSON → Task 4 field + Task 10 `saveShot(rawTrackJSON:)` (honors Plan 2 decision: caller supplies it). ✅
- CSV export of filtered shots + averages → Task 9, surfaced in Tasks 13/14. ✅
- §11 screens: Shot History (filter/sort/multi-select/detail) → Task 13; per-club Averages dashboard + gapping chart → Task 14; Clubs manager → Task 12. ✅
- Confidence surfaced & low visually distinct (§11) → Tasks 1–2 (`ConfidenceStyle`/`Theme.confidenceColor`), used in 13/14. ✅
- Reactive recompute → `@Query`-driven views recompute aggregates from current shots (Tasks 13/14). ✅
- Units yd/m → Task 1 `Units`, toggles in 13/14. ✅
- Out of scope here (later plans): Live capture screen, Calibrate sheet, Settings, Session summary screen (models exist; their dedicated screens come with the Live/Settings plans).

**2. Placeholder scan:** Data/logic tasks (1,3–10) carry complete code + full test bodies. UI tasks (2,11–14) carry complete SwiftUI for the structural/logic-bearing parts and defer only fine styling to the implementer under the stated design system — no "TODO"/"build the view" placeholders. Task 3 explicitly flags the one mutually-referential model-graph build and how to resolve it.

**3. Type consistency:** `ShotRecord` fields are identical across Tasks 7–10 and CSV/filter usage. `ClubAggregates.compute(from:)`, `ShotFilter.apply(to:)`/`ShotSort.sort(_:)`, `Stats.*`, `Units.carry(fromMeters:)`/`formattedCarry(fromMeters:)`, `ConfidenceStyle.token/label`, `Theme.confidenceColor(_:)`, and `ShotStore` method signatures match everywhere referenced. Models reuse Plan 2's `SpinSource`/`ConfidenceLevel` (String enums → SwiftData-storable) and Plan 1's `Conversions`. `@MainActor` on `ShotStore` and on model/store test classes; `nonisolated` on all pure logic.
```
