# VisionCore & Calibration On-Device Acceptance Checklist

**App:** Chunky (CarryCam)
**Plan:** 5 — VisionCore & Calibration
**Spec reference:** §6 (calibration), §7 (ball detection / tracking / scale sanity)
**Required hardware:** iPhone 16 Pro Max or newer (A18 Pro or later — same as the capture pipeline this consumes)
**Required iOS:** project deployment target (iOS 26.5+)

Run this checklist on a physical device in good outdoor or range lighting before declaring the VisionCore layer field-ready. Simulator cannot substitute: `CMMotionManager` device motion, the Vision marker detector against a real printed target, and full-rate frame delivery are device-only.

> **Scope note — read first.** Plan 5 delivers the *engine*, not the screens.
> The detection, tracking, calibration, ROI-difference, and motion-departure
> **math** is pure and unit-tested (160 unit tests green, incl. the
> `PixelBufferGray` CVPixelBuffer→GrayImage conversion run in the Simulator).
> The **device adapters** — `PixelBufferGray`, `MarkerDetector` (Vision),
> `DeviceAttitude` (CoreMotion), and the `VisionPipeline`/`ROIDifference`
> glue — are **build-verified only**. End-to-end on-device validation
> therefore depends on the **Plan 6 Live/Calibrate screens + a debug
> overlay** that surface calibration output, the up-vector, and the ball
> track. Until that wiring lands, run the checks below through a temporary
> developer harness (a `#Preview` / debug screen that instantiates the
> types directly) where noted. Treat this document as the acceptance
> criteria to satisfy the moment that UI exists.

---

## Pre-flight

- [ ] App builds and installs cleanly from Xcode (no provisioning warnings).
- [ ] Motion (`CMMotionManager`) is available (`isDeviceMotionAvailable == true`) — always true on a real iPhone, always false on Simulator.
- [ ] Camera/microphone permissions granted (inherited from the Phase-0 capture pipeline; see `capturekit-ondevice-acceptance.md`).
- [ ] A **printed calibration target** of known physical size is on hand: a QR code (preferred — read by `VNDetectBarcodesRequest`) or a high-contrast rectangle (fallback — `VNDetectRectanglesRequest`). Measure and record its real side length in metres.
- [ ] Device mounted on a tripod, landscape, face-on to the ball/target line, at the same 8–12 ft capture distance used for shots.

---

## Check 1: Calibration — pixels-per-metre at the ball plane

**Goal:** Confirm `MarkerDetector` locates the printed target's four corners and `CalibrationMath` derives a sane pixels-per-metre scale at the ball plane (spec §6).

**How to verify:**
1. Place the printed target **in the ball plane** (where the ball will sit), filling a reasonable fraction of the frame.
2. In the Calibrate screen (or dev harness), run marker detection on a live frame. Confirm the four detected corners visually bracket the target (overlay the returned corner pixels).
3. Read the reported **pixels-per-metre** (`CalibrationScale`).
4. Independently sanity-check: measure the target's on-screen width in pixels (overlay ruler or screenshot), divide by the known side length in metres. This hand value should match the reported scale within ~5%.

**Pass criteria:** Corners bracket the target; reported px/m matches the hand-measured px/m within ~5%; the value is stable (±2%) across 5 consecutive detections without moving the target.

| Measured value | Result |
|---|---|
| Target physical side length (m) | |
| Corners bracket target? (Y/N) | |
| Reported px/m | |
| Hand-measured px/m | |
| Agreement (%) | |
| Stable across 5 detections? (Y/N) | |

---

## Check 2: Up-vector tracks device roll (gravity → image plane)

**Goal:** Confirm `DeviceAttitude` maps CoreMotion gravity into the image plane correctly, so `CalibrationMath.imageUpUnit` reports a true "up" that tracks device roll (spec §6). Convention: image y-DOWN, so gravity-down ≈ image-plane `(0, +1)` and up ≈ `(0, −1)`.

**How to verify:**
1. Hold the device level in the normal landscape capture orientation. Read `imagePlaneGravity` (dev overlay).
2. Confirm it reads approximately `(0, +1)` — gravity pointing straight down in the frame.
3. Roll the device clockwise ~15–20° about the lens axis (keeping it roughly face-on). Confirm the reported up-vector (`imageUpUnit`, i.e. `−imagePlaneGravity` normalized) rotates by the same angle in the correct direction (an overlay arrow should stay pointing at the true vertical of the scene, not the tilted frame).
4. Rotate the opposite way and confirm the arrow follows.
5. Verify the sign is not inverted: the up arrow must point toward the sky in the scene, never toward the ground.

**Pass criteria:** Level → `imagePlaneGravity ≈ (0, +1)` (±~0.05); the up arrow tracks scene vertical through ±20° of device roll in the correct direction, with **no sign inversion**.

| Measured value | Result |
|---|---|
| `imagePlaneGravity` when level | |
| Up arrow points to sky (not ground)? (Y/N) | |
| Tracks roll correctly CW? (Y/N) | |
| Tracks roll correctly CCW? (Y/N) | |

---

## Check 3: Ball detection + tracking across the impact window

**Goal:** Confirm `VisionPipeline.track(_:)` detects the ball per frame and produces a continuous `[TrackPoint]` track spanning enough of the captured impact window for Metrics (spec §7).

**How to verify:**
1. Calibrate (Check 1), then hit 20 shots with a clean white range ball.
2. For each shot, run the captured `ImpactCapture` through `VisionPipeline.track` and overlay the returned `TrackPoint` pixels on the clip.
3. Confirm the track: (a) picks up the ball, not the club/glove/background; (b) is monotonic along the launch direction with no large gaps; (c) rejects spurious detections (the constant-velocity gate should drop off-line blobs).
4. Count the number of `TrackPoint`s per shot (the tracked frame count).

**Pass criteria:**
- The ball is detected as a sharp disk and tracked (not the club head or a shadow) in ≥ 15 of 20 shots.
- **≥ 5 tracked points** across the flight portion of the window on the majority of shots (Metrics' least-squares launch fit needs several in-flight samples; more is better). Cross-check against the ≥ 8 sharp frames Phase-0 requires.
- No track jumps to an off-line blob (gate holds).

| Shot # | TrackPoints | Ball (not club)? | Gaps/jumps? | Notes |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| … | | | | |
| 20 | | | | |
| **Totals / median** | | | | |

---

## Check 4: Ball-radius scale sanity agrees with calibration

**Goal:** Confirm the independent scale derived from the tracked ball's pixel radius (`ScaleSanity`, using the standard 42.67 mm ball diameter) agrees with the marker-based calibration scale — a cross-check that catches a bad calibration or a wrong-distance setup (spec §7).

**How to verify:**
1. For several of the Check-3 shots, take the median tracked ball radius (px) near address/launch.
2. Compute the ball-radius px/m: `2 · radiusPx / 0.04267`.
3. Compare to the marker calibration px/m from Check 1.

**Pass criteria:** The two px/m values agree within the `ScaleSanity` tolerance (they should be within ~15–20%; large disagreement means the ball is not in the calibrated plane or calibration is off). Record the agreement ratio.

| Measured value | Result |
|---|---|
| Median ball radius (px) | |
| Ball-radius px/m (`2r/0.04267`) | |
| Marker calibration px/m (Check 1) | |
| Agreement (ratio / %) | |
| Within tolerance? (Y/N) | |

---

## Known Limitations & Upgrade Paths (verify / note during testing)

The following are deliberate Plan-5 boundaries, not defects. Record observations for the plans that address them.

### Marker detection = QR/rectangle via Apple Vision (not true ArUco)

Calibration uses `VNDetectBarcodesRequest` (QR) with a `VNDetectRectanglesRequest` fallback, using each observation's perspective-correct corners (`topLeft`/`topRight`/`bottomRight`/`bottomLeft`) — correct for a **tilted** marker, not just an axis-aligned bounding box. True ArUco markers require OpenCV, which is out of scope here. If QR detection is unreliable at range (small marker, glare), note it — the OpenCV/ArUco upgrade is a future plan. Prefer a large, matte-printed QR target.

| Observation | Notes |
|---|---|
| QR detected reliably at capture distance? (Y/N) | |
| Fell back to rectangle detection? (Y/N) | |
| Glare / small-marker issues? | |

### Detector orientation is fixed to `.up`

`MarkerDetector` runs Vision with a hardcoded `.up` image orientation. If the calibration frame is captured in a rotated orientation and corners come back wrong, this is why — the orientation parameter is a documented later-plan hook. Note the capture orientation used.

### Ball detector is a classical blob detector (Core ML slot open)

Ball detection is `BlobBallDetector` (threshold → connected components → circularity), behind the `BallDetector` protocol. A Core ML detector can be dropped into that same protocol slot in a later plan (Plan 9). If the blob detector struggles (busy background, non-white ball, low contrast), record the condition — it motivates the ML detector. The threshold (default 180), `minArea` (6), and `minCircularity` (0.6) are the tunables.

| Observation | Notes |
|---|---|
| Blob detector false positives (background/club)? | |
| Missed ball detections & lighting condition | |
| Threshold/minArea/minCircularity adjusted? | |

### Motion-departure seam is engine-only until Plan 6

`VisionPipeline.makeDepartureProvider(...)` builds a `CaptureCoordinator.departureProvider` closure (rolling `ROIDifference` activity → `MotionDeparture`), but wiring it to the live ring buffer and the tee-box ROI happens in Plan 6. Until then, capture confirmation remains audio-only (see the Phase-0 checklist's motion-confirmation seam note). No departure time is fabricated.

### Camera-intrinsics undistortion not applied

Pixel measurements are used directly without lens-distortion correction. At the telephoto's field of view this is usually negligible near frame centre; note any curvature of a known-straight edge near the frame border. Undistortion is an optional later refinement.

---

## Field Tuning Notes

| Parameter | Measured/Observed value | Target / Notes |
|---|---|---|
| Calibration px/m | | Matches hand measure ±5% |
| Up-vector when level | | ≈ (0, +1) |
| Median TrackPoints per shot | | ≥ 5 in-flight |
| Ball-radius vs marker scale agreement | | Within ScaleSanity tolerance |
| Detector threshold used | | Default 180 |
| Detector minArea / minCircularity | | 6 / 0.6 |
| QR vs rectangle detection used | | QR preferred |
| Other observations | | |

---

## Sign-off

| Criterion | Status |
|---|---|
| Calibration px/m sane & matches hand measure (±5%) | PASS / FAIL |
| Up-vector reads ≈ (0,+1) level & tracks roll (no inversion) | PASS / FAIL |
| Ball detected (not club) & tracked in ≥ 15/20 shots | PASS / FAIL |
| ≥ 5 in-flight TrackPoints on majority of shots | PASS / FAIL |
| Ball-radius scale agrees with calibration | PASS / FAIL |
| **Overall VisionCore/Calibration** | **PASS / FAIL** |

Tester: ___________________________  Date: _______________  Device: ___________________________
