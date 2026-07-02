# Phase-0 On-Device Acceptance Checklist

**App:** Chunky (CarryCam)
**Phase:** 0 — Capture Foundation
**Spec reference:** §13 Phase 0
**Required hardware:** iPhone 16 Pro Max or newer (A18 Pro or later)
**Required iOS:** 18.0+

Run this checklist on a physical device in good outdoor or range lighting before declaring Phase 0 complete. Simulator cannot substitute — frame delivery, audio latency, and exposure behavior are device-only.

---

## Pre-flight

- [ ] App builds and installs cleanly from Xcode (no provisioning warnings).
- [ ] Camera (`NSCameraUsageDescription`) and microphone (`NSMicrophoneUsageDescription`) permissions granted on first launch.
- [ ] Device mounted on a tripod, face-on to the target line, 8–12 ft from the ball position.
- [ ] Club selected in the app before arming capture.

---

## Check 1: Telephoto lens + 1080p @ 240 fps

**Goal:** Confirm the capture session uses the 5× telephoto rear camera at the target format.

**How to verify:**
1. Open the app and navigate to the Live/Range screen.
2. Enable the debug overlay (Settings → Developer → Debug Overlay, or tap the dev badge if present).
3. The overlay must report:
   - Lens: `builtInTelephotoCamera` (5×)
   - Active format: `1920 × 1080` (1080p)
   - Frame rate: `240 fps` (min/max frame duration both `1/240 s`)
4. Alternatively, after a triggered capture, inspect the saved clip metadata in Files or the app's clip viewer and confirm `240` fps.

**Pass criteria:** Overlay or clip metadata confirms telephoto + 1080p + 240 fps.

| Measured value | Pass/Fail |
|---|---|
| Lens reported | |
| Resolution reported | |
| Frame rate reported | |

---

## Check 2: Sharp ball in saved frames (non-blurred disk)

**Goal:** Confirm the manual short-shutter exposure (≤ 1/2000 s) freezes the ball during flight.

**How to verify:**
1. Hit 20 shots with a standard range ball (white, clean).
2. After each triggered capture, review the saved impact-window frames in the app's clip viewer or Files.
3. In each frame containing the ball, the ball must appear as a **sharp, circular (non-blurred) disk** — not a smear or oval streak.
4. Count the number of frames in each clip from address/launch until the ball leaves the frame edge.

**Pass criteria:**
- Ball is a sharp disk (no perceptible motion blur tail) in the retained frames.
- **≥ 8 frames** captured between the address position and the ball leaving the frame, across the majority (≥ 15 of 20) of shots.

| Shot # | Frames captured | Ball sharp? | Notes |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
| 6 | | | |
| 7 | | | |
| 8 | | | |
| 9 | | | |
| 10 | | | |
| 11 | | | |
| 12 | | | |
| 13 | | | |
| 14 | | | |
| 15 | | | |
| 16 | | | |
| 17 | | | |
| 18 | | | |
| 19 | | | |
| 20 | | | |
| **Totals** | | | |

---

## Check 3: Audio trigger accuracy (≥ 90% on 20 shots)

**Goal:** Confirm the audio impact detector fires on real strikes and suppresses practice swings.

### 3a — Real strike detection

1. Take the same 20 shots above. For each, confirm a clip was saved (i.e., the trigger fired) within ~1 s of contact.
2. Record how many of the 20 real strikes triggered a saved clip.

**Pass criteria:** ≥ 18 of 20 real strikes trigger a clip (≥ 90%).

| Real strikes that triggered a clip | / 20 |
|---|---|
| | |

### 3b — Practice-swing suppression

1. Make 5 practice swings (full swings stopping before contact or swinging through air with no ball).
2. Confirm no clip is saved during or after each practice swing.

**Pass criteria:** 0 of 5 practice swings trigger a clip.

| Phantom triggers on practice swings | / 5 |
|---|---|
| | |

---

## Check 4: "More light needed" warning

**Goal:** Confirm the low-light warning appears and clears correctly.

**How to verify:**
1. Cover or point the camera at a dim area (indoors, shade, or hand partially over lens).
2. Confirm a "More light needed" (or equivalent) warning label/banner appears on screen within ~1 s.
3. Return the camera to normal outdoor/range lighting.
4. Confirm the warning clears within ~2 s.

**Pass criteria:** Warning appears in low light AND clears in good light.

| Condition | Warning shown? |
|---|---|
| Low light (covered / dim interior) | Yes / No |
| Good light (outdoor / range) | Cleared / Not cleared |

---

## Known On-Device Caveats (check during testing)

The following are expected behaviors or known limitations at Phase 0. Document observed values for field tuning; do not treat them as blocking failures unless noted.

### Cold-start ISO / exposure snapshot

The app snapshots the metered scene to set manual exposure before auto-exposure has fully converged. On cold start (first launch after a lock/reboot), the initial ISO reading may be stale by 0.5–2 s. **Workaround:** arm capture only after the preview has been live for ≥ 2 s. If the first 1–2 frames after a cold-start trigger appear brighter/darker than steady-state, this is the cause. Record the symptom and the time-to-convergence below.

| Observation | Value |
|---|---|
| Cold-start ISO before convergence | |
| Time until ISO stabilizes | |
| First-shot overexposed on cold start? | |

### Audio-to-video clock alignment

The audio engine (`AVAudioEngine`) and video capture session (`AVCaptureVideoDataOutput`) run on separate hardware clocks. The impact window snapshot uses `[t_audio − 40 ms, t_audio + 120 ms]`. At Phase 0, verify that the ball is visibly in the captured window (not clipped at the start). If the ball enters the window late, the audio clock is leading the video clock and the pre-trigger offset needs to be increased.

| Observation | Value |
|---|---|
| Ball present in first frame of window? | |
| Approx. frames before peak-speed frame | |
| Estimated clock offset (ms, + = audio leads) | |

### H.264 vs HEVC codec suitability

Saved clips are encoded by the device's hardware codec. At Phase 0, review whether inter-frame codec artifacts (macroblocking, reference-frame smearing) are visible on the ball in saved clips. HEVC can produce more pronounced inter-frame artifacts at the sharp transient of ball launch; H.264 is more forgiving at the cost of file size. If artifacts are visible, note the encoder and file size below for Plan 6 codec selection.

| Observation | Value |
|---|---|
| Codec used (H.264 / HEVC) | |
| Visible inter-frame artifacts on ball? | |
| Clip file size (MB, ~160-frame window) | |

### Motion-confirmation seam (Plan 5 hook)

At Phase 0, the trigger is **audio-only**. Ball departure from the tee-box ROI (motion confirmation) is a deliberate Plan-5 seam — it is not wired at this phase. As a result, the refractory debounce relies entirely on the audio trigger's refractory period (default 200 ms). Neighboring bay impact sounds or loud broadband noise may produce phantom triggers that would be suppressed by motion confirmation in Plan 5. If you observe phantom triggers that are not practice swings, note the acoustic condition; these are expected and tracked for Plan 5. Note: the ring buffer retains biplanar 420f frames over ~0.3 s (72 frames @ 240 fps).

| Observation | Notes |
|---|---|
| Phantom triggers observed (non-practice-swing) | |
| Acoustic condition when phantom fired | |

---

## Field Tuning Notes

Use this section to record measured values and issues discovered during the 20-shot test for tuning in subsequent plan tasks.

| Parameter | Measured/Observed value | Target / Notes |
|---|---|---|
| Shutter duration used (s) | | ≤ 1/2000 s |
| ISO range during test | | Clamp to device maxISO |
| Avg frames per clip | | ≥ 8 |
| Audio trigger latency (ms from contact to clip save) | | < 200 ms |
| Real-strike trigger rate | / 20 | ≥ 18 (90%) |
| False-positive trigger rate | / 5 practice swings | 0 |
| Low-light warning threshold (lux or EV) | | Surface in settings |
| Any lens switch to wide fallback? | | Telephoto preferred |
| Other observations | | |

---

## Sign-off

| Criterion | Status |
|---|---|
| Telephoto + 1080p + 240 fps confirmed | PASS / FAIL |
| Sharp ball disk in saved frames | PASS / FAIL |
| ≥ 8 frames between address and exit (≥ 15/20 shots) | PASS / FAIL |
| Audio trigger ≥ 90% on real strikes | PASS / FAIL |
| Audio trigger 0% on practice swings | PASS / FAIL |
| "More light needed" warning appears and clears | PASS / FAIL |
| **Overall Phase 0** | **PASS / FAIL** |

Tester: ___________________________  Date: _______________  Device: ___________________________
