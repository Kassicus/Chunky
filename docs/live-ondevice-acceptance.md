# Live End-to-End On-Device Acceptance Checklist

**App:** Chunky (CarryCam)
**Plan:** 6 — Live End-to-End
**Spec reference:** §11 (UI), §9 (orchestration), §6 (calibration), §13 Phase 1 acceptance
**Required hardware:** iPhone 16 Pro Max or newer (A18 Pro or later)
**Required iOS:** project deployment target (iOS 26.5+)

Run this on a physical device at a range (good light) before declaring Phase 1 complete. The Simulator cannot exercise capture, calibration, motion, or the measurement pipeline end-to-end — the entire Live/Calibrate flow is device-only. Prerequisites: the Phase-0 capture checklist (`docs/capturekit-ondevice-acceptance.md`) and the VisionCore checklist (`docs/visioncore-ondevice-acceptance.md`) should already pass, since Live builds on both.

> **What automated tests already cover (device-free):** 175 unit tests pass, including the full `ShotPipeline` chain on synthetic pixel buffers (real detector→tracker→metrics), `ShotTrackCodec` round-trip, both calibration math paths, `CalibrationProfile` mapping, and `AppSettings` persistence. The SwiftUI screens are build-verified with `#Preview`s. This checklist covers what only hardware can: capture accuracy, live calibration against a real target, motion, and the end-to-end measure→save loop.

---

## Pre-flight

- [ ] App builds and installs from Xcode (no provisioning warnings).
- [ ] Camera + microphone permissions granted on first launch.
- [ ] At least one **Club** exists (add via the Clubs tab if empty) — the Live screen requires a club selection before it can arm.
- [ ] A printed **calibration target** of known size (QR preferred, or a rectangle / known-length stick) is placed in the ball plane.
- [ ] Device on a tripod, landscape, face-on to the ball/target line, 8–12 ft away.
- [ ] A reference launch monitor (or a known-good session) is available for the accuracy checks (Check 4).

---

## Check 1: Calibration establishes a sane scale

**Goal:** The Calibrate sheet produces a believable pixels-per-metre scale and locks it (spec §6).

**How to verify:**
1. On the **Live** tab, tap **Calibrate**.
2. **Marker mode:** enter the target's real side length (mm), point at the target filling a good fraction of the frame, tap **Detect**. Confirm the **"SCALE LOCKED"** indicator appears with a plausible px/m value, stable (±2%) across 5 detections.
3. **Manual mode:** enter a known length (m), tap two points that far apart on the frozen preview. Confirm a scale is produced.
4. Hand-check: measure the target's on-screen pixel size and divide by its real size; the reported marker px/m should match within ~5%.
5. Tap **Use Scale** and confirm the Live screen shows a "SCALE LOCKED" badge.

**Pass:** Marker px/m within ~5% of hand measure and stable; manual mode produces a scale; badge shows on return.

| Value | Result |
|---|---|
| Target side length (mm) | |
| Marker px/m reported | |
| Hand-measured px/m | |
| Agreement (%) | |
| Manual-mode px/m (same target) | |

> **Known caveat (manual mode):** the two-tap→pixel conversion currently uses a fractional approximation over an aspect-fill preview (`TODO(on-device)` in `CalibrateView`). Prefer **marker mode** for accuracy until the `captureDevicePointConverted` fix lands. Record any manual-vs-marker discrepancy below.

| Manual vs marker px/m discrepancy (%) | |
|---|---|

---

## Check 2: Mandatory club + calibration gating

**Goal:** Capture cannot be armed without a club AND a calibration (spec §10, §11.1).

**How to verify:**
1. Fresh launch, Live tab, no club selected, no calibration. Confirm the **Arm** button is disabled.
2. Select a club only → Arm still disabled.
3. Calibrate only (deselect club if possible) → Arm still disabled.
4. Select a club AND calibrate → Arm becomes enabled.
5. Deny camera permission on a fresh install and confirm Arm stays disabled (no stray empty session created) while the permission banner shows.

**Pass:** Arm is enabled only when both a club and a calibration are set.

| Condition | Arm enabled? |
|---|---|
| No club, no calibration | No |
| Club only | No |
| Calibration only | No |
| Club + calibration | Yes |

---

## Check 3: Auto-save per club (no manual save)

**Goal:** Every produced shot saves instantly to the selected club (spec §10).

**How to verify:**
1. Arm, hit a shot. Confirm a **result card** appears within ~1 s showing **carry** (largest element) and a **confidence** chip.
2. Without any "save" tap, go to **History** / **Averages** and confirm the shot is recorded under the selected club.
3. Hit 20 shots; confirm all 20 auto-save to the correct club.

**Pass:** All shots auto-save to the selected club; the result card is glanceable (carry dominant, confidence always shown).

| Shots hit | Shots auto-saved to club | Result card shows carry + confidence? |
|---|---|---|
| 20 | | |

---

## Check 4: Accuracy — ball speed ±3%, launch angle ±1.0° (Phase 1 gate)

**Goal:** The measured launch conditions match a reference (spec §13 Phase 1 accept).

**How to verify:**
1. Calibrate carefully (Check 1). Hit 20 blank range balls alongside a reference monitor (or a known-good baseline).
2. For each shot, record app ball speed (mph) and launch angle (°) vs the reference.
3. Compute mean absolute error and % error across the 20 shots.

**Pass:** Ball speed within **±3%** and launch angle within **±1.0°** across the 20 shots.

| Shot | App speed (mph) | Ref speed | App launch (°) | Ref launch |
|---|---|---|---|---|
| 1–20 | | | | |
| **Mean abs error** | **speed %:** | | **launch °:** | |

> If speed error is high, suspect calibration scale (largest error source) — re-check Check 1. If frame count is low (see the debug overlay, Check 6), the ball is leaving frame too fast or the shutter/light is marginal (Phase-0 checklist).

---

## Check 5: Exclude & delete update averages immediately

**Goal:** One-tap exclude/delete from the result card, with immediate aggregate recompute (spec §10, §11.1).

**How to verify:**
1. After a shot, tap **Exclude (mishit)** on the result card. Confirm the shot is marked excluded and the club's Averages drop it immediately.
2. On another shot, tap **Delete**. Confirm it's removed and averages recompute at once.

**Pass:** Exclude and delete are one tap each; averages update immediately and correctly.

| Action | Averages updated immediately? |
|---|---|
| Exclude | |
| Delete | |

---

## Check 6: Debug overlay

**Goal:** The dev debug overlay shows the track + fitted velocity + scale + metrics for field tuning (spec §11.8, §14).

**How to verify:**
1. Settings → enable **Debug overlay**.
2. After a shot, open the debug affordance on the Live screen.
3. Confirm the overlay plots the ball centroids, draws the fitted launch vector, and lists v0 / launch / carry / px-m / frames used / RMS residual / confidence.

**Pass:** Overlay renders the track and metrics; frame count and RMS look reasonable.

| Value | Observation |
|---|---|
| Tracked points (used/total) | |
| Fitted v0 (mph) shown | |
| RMS residual (m) | |

---

## Check 7: Lens toggle, light warning, CSV export

**How to verify:**
- **Lens toggle:** switch telephoto↔wide on the Live screen; confirm the preview re-attaches and capture still works after re-arming.
- **Light warning:** point at a dim area; confirm a "More light needed" banner appears and clears in good light.
- **Session summary + CSV:** open **This Session** from the Live toolbar; confirm the shot list + stats; tap **Export CSV** and confirm a valid CSV file shares out (opens in a spreadsheet with correct columns and units).

| Item | Result |
|---|---|
| Lens toggle re-attaches preview | |
| "More light needed" appears/clears | |
| CSV opens with correct columns/units | |

---

## Field Tuning Notes

Record measured values for tuning in later passes.

| Parameter | Value / Observation | Notes |
|---|---|---|
| Calibration px/m (marker) | | matches hand ±5% |
| Detector threshold / minArea / minCircularity | | defaults 180 / 6 / 0.6 |
| Tee-box ROI (if motion confirmation used) | | ROI→pixel is on-device-approximate |
| Motion activity threshold | | default 0.02 |
| Median tracked points per shot | | ≥ ~5 in-flight preferred |
| Ball speed mean abs error (%) | | ≤ 3% |
| Launch angle mean abs error (°) | | ≤ 1.0° |
| Manual-calibration accuracy vs marker | | prefer marker until captureDevicePointConverted fix |

---

## Known On-Device Caveats (deliberate Plan-6 boundaries)

- **Manual calibration geometry** uses a fractional aspect-fill approximation; the exact `captureDevicePointConverted` fix is a documented `TODO(on-device)`. Marker mode is the exact primary path.
- **Tee-box ROI → pixel conversion** at arm time is approximate (also aspect-fill); the motion-confirmation `departureProvider` is wired but its ROI/threshold need on-device tuning. With no ROI it runs audio-only (Phase-0 behavior).
- **Azimuth** is reported as 0 (not measurable face-on, single camera) — carry is the reliable number (spec §15).
- **Spin** is modeled per-club (measured spin = Plan 7 / SpinCore).

---

## Sign-off

| Criterion | Status |
|---|---|
| Calibration px/m sane & stable (±5% marker) | PASS / FAIL |
| Arm gated on club + calibration | PASS / FAIL |
| Every shot auto-saves to the selected club | PASS / FAIL |
| Ball speed within ±3% (20 shots) | PASS / FAIL |
| Launch angle within ±1.0° (20 shots) | PASS / FAIL |
| Exclude/delete update averages immediately | PASS / FAIL |
| Debug overlay shows track + metrics | PASS / FAIL |
| Lens toggle / light warning / CSV export | PASS / FAIL |
| **Overall Phase 1** | **PASS / FAIL** |

Tester: ___________________________  Date: _______________  Device: ___________________________
