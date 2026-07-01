# Build Spec — iPhone Camera Golf Carry Monitor

**Working title:** CarryCam
**Target hardware:** iPhone 16 Pro Max and newer (A18 Pro or later)
**Platform:** iOS 18+, Swift 6, SwiftUI, Xcode
**Primary goal:** Produce accurate **carry distance** per shot from a single face-on camera, by measuring launch conditions and integrating a ballistics model — no external hardware.

> This document is written to be handed directly to Claude Code as the project brief. It defines scope, architecture, algorithms, module boundaries, the Xcode project layout, phased milestones, and per-phase acceptance criteria. Build strictly in the phase order given — each phase is independently testable.

---

## 1. Product goal and non-goals

**Goal.** At a driving range, the user places an iPhone on a tripod to the side (face-on), hits a shot, and within ~1 second sees an estimated carry distance. The app logs shots per club so the user can learn their yardage gaps.

**In scope (in priority order):**
1. Ball speed (launch speed)
2. Vertical launch angle
3. Carry distance (derived from 1, 2, and spin via a ballistics model)
4. Start direction / azimuth (secondary; affects total & dispersion more than carry)
5. Backspin (marked balls only; falls back to a model on blank balls)
6. **Club speed & smash factor (opportunistic).** Not a priority, but the impact window is already captured, so if the clubhead can be tracked reliably through impact, compute club speed and smash factor (`ball speed ÷ club speed`) and store them. Treat as best-effort with a confidence tag; never let it block or slow the carry result. See §3.4 and Phase 3.5.

**Data & club management is first-class (must-have, not optional):**
- Every shot **must** be tagged to a selected club and **saved automatically** — hitting a 7-iron always writes a 7-iron record.
- Fully **customizable club list** (add / rename / reorder / remove clubs).
- **Filterable history** of every saved shot (by club, session, date, confidence).
- **Per-club averages dashboard** maintained automatically across all saved shots.
- **Delete** individual or multiple shots, and **exclude** mishits from averages, with averages recalculating immediately.

**Explicit non-goals (do not build):**
- Club path / face angle / attack angle.
- Cloud sync, accounts, social features.
- Android / iPad-optimized layouts (iPhone only).
- Real-time on-screen ball tracer overlay during flight (nice-to-have, not required).

**Design principle — graceful degradation.** Everything except spin needs only the ball's centroid (a bright blob), so **speed, launch angle, and direction work on any ball including blank range balls.** Spin needs surface markings; with a Titleist Pro V1 (side stamp + alignment line) it is measurable, and on blank balls the app substitutes a modeled spin. The app must never block a shot for lack of markings — it downgrades the spin source and flags lower confidence.

---

## 2. Hardware assumptions and rationale

Target device family: **iPhone 16 Pro Max and newer.** Rely only on capabilities common to that family and later:

- **Rear camera system** with wide (main), ultra-wide, and 5× telephoto (≈120 mm equiv.) lenses.
- **High frame-rate capture:** 1080p up to 240 fps; 4K up to 120 fps. The app uses a high-fps format (target **240 fps at 1080p**) for the launch window.
- **Manual exposure control** via `AVCaptureDevice` custom exposure (short shutter to freeze the ball).
- **A18 Pro Neural Engine** for on-device Core ML inference (ball detector).
- Do **not** depend on LiDAR — its ~5 m range is useless for ball flight. It may optionally be used once at setup to help range the calibration target, but must not be required.

**Camera choice at runtime:** default to the **telephoto (5×)** lens shot from ~8–12 ft to approximate an orthographic (flat) projection, minimizing perspective distortion. Provide a fallback to the wide lens for tight indoor spaces (with a documented accuracy penalty). The lens is a user-visible setting stored per session.

---

## 3. Measurement model (the physics the app implements)

Carry is determined almost entirely by three launch conditions plus air density:

- **v0** — launch (ball) speed
- **θ** — vertical launch angle
- **ω** — spin (primarily backspin; sidespin tilts the axis)
- **ρ** — air density (from temperature, altitude, humidity)

The app measures v0, θ, and (when possible) ω from the first frames of flight, then **numerically integrates the trajectory** to landing. It does **not** watch the ball land.

### 3.1 Single-camera geometry

A single 2D camera measures displacement only in the image plane. Motion toward/away from the lens is foreshortened and not recoverable without depth. Therefore the camera is placed **face-on** (optical axis perpendicular to the target line) so the ball travels *across* the frame:

- Ball speed → horizontal pixel displacement × scale ÷ frame interval. Clean face-on.
- Vertical launch angle → true elevation angle in the image plane. Clean face-on.
- Backspin → for a straight shot the backspin axis points at a face-on camera, so the ball appears to rotate like a clock face — the ideal geometry to read rotation off markings.
- Azimuth → this is the depth axis for a face-on camera and is the **weak** measurement. It is estimated coarsely (or via the optional second camera). It matters least for carry.

### 3.2 Ballistics model

Integrate a point-mass projectile with aerodynamic drag and Magnus lift:

```
m·a = m·g + F_drag + F_magnus
F_drag   = -0.5·ρ·A·Cd·|v|·v
F_magnus =  0.5·ρ·A·Cl·|v| · (ŵ × v)
```

- Ball: mass `m = 0.04593 kg`, diameter `d = 0.04267 m`, area `A = π(d/2)²`.
- `g = 9.81 m/s²`.
- `Cd`, `Cl` are functions of the **spin ratio** `S = ω·(d/2)/|v|` (and mildly of Reynolds number). Implement as lookup tables interpolated from published golf-ball wind-tunnel data (e.g., Bearman & Harvey / Smits & Smith). Ship a default table in a bundled JSON; keep it swappable.
- Integrate with **RK4**, fixed `dt = 1 ms`, from launch height until the ball returns to launch height. **Carry** = horizontal distance at that point. Continue a simple roll model only if "total" is later requested (out of scope now).
- **Air density** `ρ` from user-entered temperature + altitude (+ optional humidity), default sea level / 15 °C = 1.225 kg/m³. Provide a simple ISA-based helper.

### 3.3 Spin handling

- **Marked ball:** measure ω from marking rotation across the near-impact frames (§8).
- **Blank ball or low-confidence spin:** substitute a **modeled spin** from a per-club table keyed on measured v0 and θ (e.g., driver ~2,300–2,800 rpm, 7-iron ~6,500 rpm, PW ~9,000 rpm). Ship editable defaults; let the app refine them per user over time (Phase 4+, optional).
- Every carry result carries a **confidence tag** derived from spin source and tracking quality.

### 3.4 Club speed & smash factor (opportunistic)

Reuses the same face-on impact window — no extra hardware or capture change.

- **Club speed:** track the **clubhead** in the frames immediately *before* impact and compute its speed the same way as the ball (metric displacement ÷ frame interval, using the calibration scale). Measure velocity at the last clean pre-impact frame.
- **Smash factor:** `ballSpeed ÷ clubSpeed`.
- **Reality check / caveats (put in code + UI):** the clubhead is faster, larger, motion-blurred even at short shutter, and partly occluded by the golfer/shaft, so it is **harder to track than the ball**. Expect lower reliability than the ball metrics, and worse for driver. Physically valid smash factor is roughly **1.2–1.5** (irons ~1.33, driver ~1.45–1.50); reject/flag out-of-range values rather than displaying garbage.
- **Never gate the carry result on it.** If clubhead tracking fails or confidence is low, club speed and smash are simply left blank for that shot; carry is unaffected.
- Implementation lives behind the same `BallDetector`/tracking machinery (a `ClubheadDetector` variant) and is populated in `Metrics` only when confident.

---

## 4. System architecture

Modular, testable Swift packages. Core algorithms must be **pure and deterministic** so they can be unit-tested against recorded fixtures with no camera.

```
CarryCam (app)
├─ CaptureKit        // AVFoundation: device config, high-fps, manual exposure, ring buffer, impact trigger
├─ VisionCore        // ball detection & sub-pixel tracking (classical CV + Core ML detector)
├─ SpinCore          // marking detection & rotation-rate estimation
├─ Calibration       // scale/plane calibration, camera intrinsics handling
├─ Ballistics        // pure trajectory integrator, Cd/Cl tables, air-density helper  [NO Apple frameworks]
├─ Metrics           // orchestration: frames → v0, θ, azimuth, spin → carry + confidence
├─ DataStore         // SwiftData models: Session, Shot, Club, CalibrationProfile
└─ UI                // SwiftUI screens
```

**Dependency rule:** `Ballistics` and `Metrics` math must not import AVFoundation/Vision. `CaptureKit` and `VisionCore` feed them plain value types (arrays of timestamped centroids, angles, scale). This keeps the accuracy-critical code unit-testable and portable.

---

## 5. Capture pipeline (CaptureKit)

Responsibilities: configure the device for a frozen, high-fps launch window, continuously buffer frames, detect impact, and hand the surrounding frame window to `VisionCore`.

### 5.1 Device & format configuration

- Select the rear camera (`.builtInTelephotoCamera` preferred, `.builtInWideAngleCamera` fallback) via `AVCaptureDevice.DiscoverySession`.
- Choose an `AVCaptureDevice.Format` whose `videoSupportedFrameRateRanges` includes the target fps (240) at 1080p. Set `activeVideoMinFrameDuration` and `activeVideoMaxFrameDuration` to `CMTime(value: 1, timescale: 240)`.
- Lock configuration with `lockForConfiguration()` / `unlockForConfiguration()`.

### 5.2 Manual short-shutter exposure (critical — kills motion blur)

- Set custom exposure: `setExposureModeCustom(duration:iso:completionHandler:)` with **duration ≈ 1/2000 s or shorter** (target 1/2000–1/4000). This is non-negotiable — default auto-exposure smears the ball at launch speed.
- Raise ISO to compensate (clamp to `activeFormat.maxISO`). Surface a "more light needed" warning if the metered scene can't support the short shutter at max ISO.
- Lock white balance and focus (`focusMode = .locked`) at the ball plane during a shot to avoid hunting.

### 5.3 Frame delivery & ring buffer

- Use `AVCaptureVideoDataOutput` with a dedicated serial `DispatchQueue`; set `alwaysDiscardsLateVideoFrames = true` and a `kCVPixelFormatType_420YpCbCr8BiPlanarFullRange` (or `_32BGRA`) pixel format.
- Maintain a **ring buffer** of the last ~0.5 s of frames (≈120 frames @ 240 fps) as lightweight references (retain `CVPixelBuffer` + presentation timestamp). Never block the capture queue — do detection on a separate queue.
- At 240 fps, full-frame per-frame ML is too heavy. Strategy: run a **cheap motion/blob pre-pass** on every frame; run the heavier detector only on the impact window frames after trigger.

### 5.4 Impact trigger

- **Primary trigger: audio.** Tap the microphone (`AVAudioEngine`) and detect the sharp broadband transient of club-ball contact (onset detection on RMS/flux with a refractory period). On trigger, snapshot the ring buffer window `[t_impact − 40 ms, t_impact + 120 ms]`.
- **Fallback trigger: motion.** If audio is unreliable (wind, noisy bay), detect the ball leaving its address position via frame differencing in a user-drawn "tee box" ROI.
- Debounce so practice swings / neighbor bays don't create phantom shots (require ball actually departing the ROI within N ms of the audio transient).

---

## 6. Calibration (Calibration)

Accurate scale in the **flight plane** is the single biggest error source. Calibration must be quick and repeated whenever the phone or ball position moves.

### 6.1 Procedure (user-facing, ~20 s)

1. Place a **calibration target of known size** where the ball will fly — ship a printable target (e.g., a 300 mm bar with two ArUco/AprilTag markers) and also allow "enter a known reference length" (e.g., a 1 m alignment stick).
2. App detects the target, computes **pixels-per-meter at the ball plane** and the plane's vertical (gravity) direction (use `CMMotionManager` device attitude to define true vertical, plus the target for horizontal).
3. Store a `CalibrationProfile`: lens, pixels-per-meter, image-plane orientation, camera distance estimate, timestamp.

### 6.2 Notes

- Prefer measuring scale from a physical target in-plane over relying on intrinsics; if `AVCameraCalibrationData` (intrinsics/distortion) is available for the active format, capture it too and undistort centroids before metric conversion.
- Warn and force re-calibration if device attitude drifts beyond a threshold from the stored profile (phone bumped).
- Keep the calibration target visible at frame edge during shots if possible for continuous scale sanity-checking.

---

## 7. Ball detection & tracking (VisionCore)

Two interchangeable detectors behind one protocol so the MVP ships fast and upgrades cleanly.

```swift
protocol BallDetector {
    func detect(in frame: FrameRef) -> [BallCandidate] // center (px), radius (px), confidence
}
```

- **MVP — classical CV:** threshold the bright, round ball against the backdrop (sky/net/mat); Hough-circle or contour + circularity filter; sub-pixel centroid via intensity-weighted centroid or circle fit. Fast, works when contrast is good.
- **Upgrade — Core ML object detector:** a small YOLO-style model trained (Create ML) on golf-ball-at-launch imagery for robustness against clutter, shadows, and low contrast. Runs on the Neural Engine, restricted to the impact-window frames.

**Tracking:** across the impact window, associate candidates into one track (nearest-neighbor with a constant-velocity prior). Reject frames where the ball overlaps the club or leaves frame. Output an ordered list of `(timestamp, centerPx, radiusPx, confidence)`.

**Scale sanity check:** the detected ball radius in px × known ball diameter gives an independent scale estimate; cross-check against the calibration profile and flag large disagreement (usually means the ball isn't in the calibrated plane).

---

## 8. Spin measurement (SpinCore) — marked balls

Runs only on the near-impact frames where the ball is largest and slowest. Experimental; must degrade to modeled spin cleanly.

1. For each impact-window frame, crop the tracked ball, normalize scale/orientation.
2. Detect surface markings (Pro V1 side stamp / alignment line) via template/feature matching; estimate the marking's angular position on the ball face.
3. Compute inter-frame angular displacement → rotation rate. **Handle aliasing:** at high rpm the ball turns a large fraction of a revolution between frames; use the highest fps available, track *incremental* small rotations from the first frames after separation, and reject solutions whose implied rpm is outside physically plausible per-club bounds.
4. Estimate spin-axis tilt (back- vs side-spin) from the apparent motion of the marking; low confidence with a single face-on camera — mark accordingly.
5. Output `spinRPM`, `axisTiltDeg`, `confidence`. Below a confidence threshold, `Metrics` ignores it and uses the modeled spin.

> Set expectations in code comments and UI: spin is most reliable on irons/wedges, least on driver. This is a hardware limit (240 fps + motion blur + small ball), not a bug.

---

## 9. Metric extraction & orchestration (Metrics)

Pure functions consuming tracked centroids + calibration, producing launch conditions, then carry.

- **Ball speed v0:** convert centroids to metric using the calibration scale; least-squares fit position vs time over the first clean N frames (constant-velocity window, before drag/gravity meaningfully bend it); |velocity| = v0. Report m/s and mph.
- **Vertical launch angle θ:** `atan2(vy, vx)` in world coordinates (device-attitude-corrected vertical).
- **Azimuth:** coarse estimate from residual horizontal-plane motion; flag low confidence (single-camera). Refined only with the optional DTL camera.
- **Spin:** from SpinCore if confident, else modeled per-club table.
- **Carry:** call `Ballistics.integrate(v0, θ, spin, axisTilt, ρ)` → carry distance. Attach an overall **confidence** (combining spin source, tracking frame count/quality, scale agreement).

Return a `ShotResult` value type (all metrics + confidence + raw inputs for later re-computation).

---

## 10. Data model & persistence (DataStore — SwiftData)

```
Club        { id, name, type, order, notes, isArchived }
Session     { id, date, location, lens, temperatureC, altitudeM, humidity, calibrationProfileId, shots[] }
Shot        { id, sessionId, clubId, timestamp,
              ballSpeedMS, launchAngleDeg, azimuthDeg,
              spinRPM, spinSource(enum: measured|modeled), spinAxisTiltDeg,
              clubSpeedMS?, smashFactor?,            // opportunistic; nil when not confidently tracked
              carryMeters, confidence(enum: high|med|low),
              isExcludedFromAverages(bool),          // mishit flag — kept but not counted
              rawTrackJSON (centroids+timing for re-compute), videoClipURL? }
CalibrationProfile { id, lens, pxPerMeter, planeOrientation, cameraDistanceM, createdAt }
```

**Persistence & club-data requirements (must-have):**
- **Auto-save every shot** to its selected `clubId` the instant a result is produced — no manual "save" step. A club must be selected before capture is armed.
- **Customizable club list:** add, rename, reorder, and remove clubs. Use `isArchived` (soft-delete) instead of hard-deleting a club that already has shots, so historical shots keep a valid reference; offer hard delete only when a club has no shots.
- **Delete shots:** support deleting a single shot or a multi-selection; deletion is permanent and averages recompute immediately.
- **Exclude, don't always delete:** an `isExcludedFromAverages` flag lets the user drop a mishit from stats **without losing the record** (toggleable). Deletion and exclusion are both offered; excluded shots are visually marked and omitted from all aggregates.
- **Per-club aggregates** (computed over non-excluded shots): count, mean & median carry, std dev, min/max, and — where present — average ball speed, launch angle, spin, club speed, smash factor. Recompute reactively whenever shots are added/deleted/excluded (SwiftData `@Query` + derived view models).
- Persist the **raw track** per shot so carry can be recomputed if the ballistics tables or calibration improve later.
- Optional: save the short impact clip for review; storage-managed setting.
- **CSV export** of the filtered shot set and of the per-club averages table.

---

## 11. UI (SwiftUI screens)

1. **Range/Live screen** — camera preview with the tee-box ROI overlay, lens toggle, exposure/light warning, and a **prominent club selector that must be set before capture is armed** (persists to the next shot). Big result card after each shot: carry + confidence, expandable to v0/θ/spin (and club speed/smash when available). Card offers instant **"exclude (mishit)"** and **"delete"** actions so the user can clean up on the spot.
2. **Shot History screen** — a filterable, sortable list of **every saved shot** across all sessions. Filters: club, session/date range, confidence, included/excluded. Multi-select for bulk delete or bulk exclude. Tapping a shot shows full detail and its raw track.
3. **Per-club Averages dashboard** — one row per club showing count, avg & median carry, std dev, and avg ball speed/launch/spin (+ club speed/smash where present). Auto-updates as shots are added, deleted, or excluded. Includes the gapping chart (carry vs club) and drill-down into that club's shots.
4. **Clubs manager** — add / rename / reorder / remove clubs (soft-archive clubs that already have shots); edit each club's modeled-spin default.
5. **Calibrate sheet** — guided target detection with a live "scale locked" indicator.
6. **Session summary** — shots from the current session, quick stats, CSV export.
7. **Settings** — units (yd/m), fps/lens defaults, environment inputs (temp/altitude/humidity), clip storage, developer/debug overlay.
8. **Debug overlay (dev builds)** — draw the detected ball (and clubhead) track, per-frame centroids, fitted velocity vector, scale, and computed metrics over the captured window. Essential for field tuning.

Keep the live screen glanceable: the number the user cares about (carry) is largest; confidence is always shown so low-quality shots aren't mistaken for gospel. Delete and exclude must be reachable in one tap from both the result card and the history list.

---

## 12. Xcode project layout

```
CarryCam.xcodeproj  (or Swift Package-based workspace)
├─ App/
│   ├─ CarryCamApp.swift          // @main, SwiftData container
│   └─ AppRouter.swift
├─ Packages/
│   ├─ CaptureKit/                // AVFoundation
│   ├─ VisionCore/                // detection/tracking (+ bundled Core ML model)
│   ├─ SpinCore/
│   ├─ Calibration/
│   ├─ Ballistics/                // pure Swift, no Apple frameworks; has its own tests
│   ├─ Metrics/                   // pure Swift; has its own tests
│   └─ DataStore/                 // SwiftData models
├─ Features/                      // SwiftUI screens (UI layer)
│   ├─ Live/  History/  Averages/  Clubs/  Calibrate/  Session/  Settings/
├─ Resources/
│   ├─ aero_tables.json           // Cd/Cl vs spin ratio
│   ├─ modeled_spin.json          // per-club default spin
│   └─ calibration_target.pdf     // printable target
└─ Tests/
    ├─ BallisticsTests/           // trajectory sanity vs known reference carries
    ├─ MetricsTests/              // fixture tracks → expected v0/θ/carry
    └─ Fixtures/                  // recorded impact clips + hand-labeled ground truth
```

- **Deployment target:** iOS 18.0. Gate any newer-only APIs with availability checks; the app targets 16 Pro Max & newer but should still compile/run on other iOS 18 iPhones with reduced fps.
- **Frameworks:** AVFoundation, Vision, CoreML, CoreMotion, SwiftUI, SwiftData, Accelerate (vDSP for fits), AVFAudio. No third-party dependencies required for MVP.
- **Permissions (Info.plist):** `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`. Motion usage if `CMMotionManager` requires it.

---

## 13. Phased milestones & acceptance criteria

Build in order. Each phase must pass its acceptance criteria before the next.

### Phase 0 — Capture foundation
Scaffold app; live preview; select tele lens; configure 240 fps @ 1080p; apply manual short-shutter exposure; ring buffer; save a triggered impact clip to disk.
**Accept:** On-device, a swung ball appears as a **sharp (non-blurred) disk** in saved frames; ≥ 8 frames captured between address and ball leaving frame; audio trigger fires on real strikes and not on practice swings (≥ 90% on a 20-shot manual test).

### Phase 1 — Speed & launch angle (any ball)
Calibration flow; classical ball detector + tracker; compute v0 and θ; debug overlay.
**Accept:** Against a tripod-fixed reference (or a commercial monitor session), **ball speed within ±3% and launch angle within ±1.0°** across 20 shots on blank range balls. Deterministic recomputation from saved fixtures in unit tests.

### Phase 2 — Carry + full data/club management (core)
Ballistics integrator + aero/air-density; modeled-spin table; ShotResult with confidence. **SwiftData persistence with the full club-data feature set:** mandatory club selection, auto-save per club, customizable club list, Shot History with filters + multi-select delete/exclude, per-club Averages dashboard with reactive recompute, gapping chart, CSV export.
**Accept:** `BallisticsTests` reproduce published reference carries for standard driver/7-iron within ±3%. Every shot auto-saves to the selected club; deleting/excluding shots updates the affected club's averages immediately and correctly (unit-tested on the aggregate logic). Filters return the correct shot set. End-to-end field carry (irons) within **±8 yards** vs a reference monitor over 20 shots; gapping monotonic and repeatable session-to-session.

### Phase 3 — Measured spin (marked balls)
SpinCore rotation estimation on Pro V1; integrate measured spin into carry; confidence tagging.
**Accept:** On irons/wedges with Pro V1, measured spin within **±10%** of a reference where available; carry error for irons narrows to **±5–8 yards**; driver spin flagged low-confidence and safely falls back when below threshold.

### Phase 3.5 (opportunistic) — Club speed & smash factor
`ClubheadDetector` + pre-impact tracking; compute club speed and smash; store when confident; display on the result card, detail, and averages. Reject out-of-range smash values.
**Accept:** Where a reference is available, club speed within **±5%** on irons; smash factor stays in a physical range and is left blank (never wrong-but-shown) when tracking is low-confidence; carry pipeline unaffected whether or not club speed is obtained.

### Phase 4 (optional) — Dual-camera & refinements
Add a down-the-line second device for azimuth + spin-axis tilt (time-sync via audio); per-user modeled-spin learning; Core ML detector upgrade.
**Accept:** Azimuth within ±1.5°; no regression in single-camera carry accuracy.

---

## 14. Validation & test strategy

- **Fixtures over field trips.** Record real impact clips with hand-labeled ground truth (ball positions per frame, known scale) and check them into `Tests/Fixtures`. `MetricsTests` and `BallisticsTests` must run offline in CI with no camera.
- **Ballistics ground truth:** validate the integrator against published launch-condition→carry references (e.g., standard driver 167 mph ball speed / ~10–12° / ~2,600 rpm ≈ known carry) before trusting any field numbers.
- **Field calibration harness:** the debug overlay + CSV export let you compare against a borrowed commercial monitor for a session and compute per-club error offsets.
- **Error budget (track these):** scale/calibration error (largest — target <1%), sub-pixel centroid error, frame-rate quantization of v0, motion blur (mitigated by short shutter), spin measurement error (largest physics-side, driver worst), air-density assumptions. Document each shot's dominant error source in dev builds.

---

## 15. Known limitations to state in-app

- Azimuth is coarse on a single face-on camera; carry is the reliable number.
- Spin on driver from 240 fps is inherently limited; treat driver carry as speed/angle-driven with modeled spin unless a confident measurement is obtained.
- Requires good light for the short shutter; low light forces longer exposure and degrades accuracy — warn the user.
- Accuracy depends on the ball flying in the calibrated plane; large pushes/pulls toward/away from the camera increase error.

---

## 16. Instructions for Claude Code (how to proceed)

1. **Start with the pure math, not the camera.** Implement `Ballistics` and `Metrics` first with unit tests and the checked-in fixtures — these are deterministic and need no device. Get `BallisticsTests` passing against reference carries before anything else.
2. Scaffold the app and `CaptureKit` (Phase 0) next; verify the sharp-ball capture on a real device early — the short-shutter exposure is the make-or-break detail.
3. Keep the detector behind the `BallDetector` protocol; ship classical CV first, leave the Core ML slot for later.
4. Never let `Ballistics`/`Metrics` import AVFoundation/Vision — enforce via package boundaries so the accuracy-critical code stays testable.
5. After each phase, run its acceptance test and record measured error before moving on. Do not proceed on a failing phase.
6. Surface confidence everywhere; a low-confidence carry must be visually distinct from a high-confidence one.

**First deliverable to produce:** the `Ballistics` package (integrator + aero tables + air-density helper) and `BallisticsTests` reproducing standard reference carries within ±3%. Everything else depends on trusting that model.
