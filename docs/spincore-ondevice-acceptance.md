# SpinCore (Measured Spin) On-Device Acceptance Checklist

**App:** Chunky (CarryCam)
**Plan:** 7 — SpinCore (measured spin)
**Spec reference:** §8 (spin measurement), §3.3 (spin handling), §13 Phase 3
**Required hardware:** iPhone 16 Pro Max or newer (A18 Pro or later)
**Required iOS:** project deployment target (iOS 26.5+)

Run this at a range in good light, with a **marked ball**, after the Live end-to-end flow (Plan 6) already passes on device. Spin is measured from the marking's rotation across the near-impact frames; it is **experimental and hardware-limited** — most reliable on irons/wedges, least on driver (240 fps + a small, fast, motion-blur-prone ball). Below a confidence threshold the app silently uses modeled spin — that fallback is the safety net, not a failure.

> **What automated tests already cover (device-free):** 189 unit tests pass, including the full SpinCore chain on synthetic rotating-marking `GrayImage`s (crop → `ClassicalMarkingEstimator` → aliasing-resolved `SpinRateEstimator` → `MeasuredSpin`), and the `ShotPipeline` fallback (unmarked ball → modeled spin). This checklist covers what only hardware can: real marking contrast/blur, real rpm accuracy vs a reference, and the driver/blank fallback behavior.

---

## Pre-flight

- [ ] Plan-6 Live flow passes on device (`docs/live-ondevice-acceptance.md`).
- [ ] A **marked ball**: a Titleist Pro V1 side stamp, or draw a bold dark alignment mark / dot on a white ball with a marker. The mark must be a solid, off-center dark region (not a thin faint line).
- [ ] Tripod, landscape, face-on to the flight line, calibrated (Calibrate sheet → SCALE LOCKED).
- [ ] A reference launch monitor (or known-good baseline) for the ±10% spin check, where available.

---

## Check 1: Measured spin engages on irons/wedges

**Goal:** With a marked ball, iron/wedge shots report **spin source = measured** with a plausible rpm (spec §8).

**How to verify:**
1. Select a 7-iron (or wedge). Hit 20 shots with the marked ball, keeping the mark roughly facing the camera at address.
2. On each result card, expand to the spin row and note whether it reads **measured** (vs modeled) and the rpm.

**Pass:** ≥ ~12 of 20 iron/wedge shots report **measured** spin with a plausible rpm (roughly 5,000–9,000 rpm for irons/wedges). Shots that fall back to modeled are acceptable (marking not seen clearly) — they must not show wrong-but-measured values.

| Metric | Result |
|---|---|
| Shots reporting measured spin | / 20 |
| Typical measured rpm | |
| Any implausible measured rpm shown? (should be none) | |

---

## Check 2: Measured spin accuracy (±10% vs reference)

**Goal:** Where a reference is available, measured spin is within **±10%** (spec §13 Phase 3).

**How to verify:** For iron/wedge shots that reported *measured* spin alongside a reference monitor, record both and compute % error.

**Pass:** Mean absolute spin error within **±10%** across the measured-spin shots.

| Shot | App rpm (measured) | Ref rpm | % error |
|---|---|---|---|
| 1–N (measured only) | | | |
| **Mean abs % error** | | | |

---

## Check 3: Driver flags low-confidence and falls back cleanly

**Goal:** Driver spin (hardest case) is not trusted when the marking can't be resolved; it falls back to modeled without wrong values (spec §8 note, §13 Phase 3).

**How to verify:** Hit ~10 drivers with the marked ball. Confirm most report **modeled** spin (low measured confidence), and any that report measured are physically plausible (~2,000–3,200 rpm), never absurd.

**Pass:** Driver shots fall back to modeled when unsure; no wildly wrong measured driver spin is shown.

| Metric | Result |
|---|---|
| Driver shots → modeled | / 10 |
| Any implausible measured driver spin? (should be none) | |

---

## Check 4: Blank ball always falls back to modeled

**Goal:** A ball with no visible marking never fabricates measured spin (spec §3.3, §8.5).

**How to verify:** Hit 5 shots with a **blank** (unmarked) ball. Confirm every result card shows **modeled** spin.

**Pass:** 5 of 5 blank-ball shots report modeled spin.

| Blank-ball shots → modeled | / 5 |
|---|---|
| | |

---

## Check 5: Carry accuracy improves with measured spin (irons)

**Goal:** With measured spin, iron carry error narrows toward **±5–8 yards** (spec §13 Phase 3).

**How to verify:** For the measured-spin iron shots (Check 1–2), compare app carry to the reference.

**Pass:** Iron carry mean absolute error within **±5–8 yards** across the measured-spin shots.

| Iron carry mean abs error (yd) | |
|---|---|
| | |

---

## Field Tuning Notes

Record for tuning the `ClassicalMarkingEstimator` / `SpinRateEstimator` / `SpinCore` defaults in later passes.

| Parameter | Value / Observation | Notes |
|---|---|---|
| `darkThreshold` | | default 90 (lower if marking not detected in bright light) |
| `innerRadiusRatio` | | default 0.85 (lower to exclude ball rim/shadow) |
| `minMarkingStrength` | | default 0.30 (raise to reject weak/noisy marks) |
| `minFrames` | | default 3 usable frames |
| Plausible rpm bounds | | default 300–14000 |
| Marking type used (Pro V1 stamp / drawn dot / line) | | solid off-center mark works best |
| Measured-spin hit rate (irons) | | Check 1 |
| Mean spin error (%) | | ≤ 10% |
| Median usable marking frames per shot | | more = more reliable |

---

## Known Limitations (deliberate Plan-7 boundaries)

- **Single-camera axis tilt is not resolved.** SpinCore emits `axisTiltDeg = 0` (backspin-dominant). A single face-on camera cannot reliably separate back- vs side-spin (spec §8.4, §15). Carry depends on backspin magnitude, which *is* measured; side/curve is not.
- **Aliasing at high rpm.** Between 240 fps frames a fast ball can turn > half a revolution; SpinCore uses the club's modeled spin as a prior to resolve the revolution count and rejects physically implausible rpm. Wedge spin (highest rpm) is the most aliasing-prone; trust the confidence gate.
- **Classical marking estimator only.** A `MarkingAngleEstimator` protocol slot is open for a future Vision/Core ML estimator (spec §8) — not in this plan.
- **Below the confidence threshold (0.5) measured spin is ignored** and modeled spin is used — by design.

---

## Sign-off

| Criterion | Status |
|---|---|
| Measured spin engages on marked irons/wedges | PASS / FAIL |
| Measured spin within ±10% of reference | PASS / FAIL |
| Driver flags low-confidence & falls back cleanly | PASS / FAIL |
| Blank ball always falls back to modeled | PASS / FAIL |
| Iron carry error ±5–8 yd with measured spin | PASS / FAIL |
| No implausible measured spin ever shown | PASS / FAIL |
| **Overall Phase 3** | **PASS / FAIL** |

Tester: ___________________________  Date: _______________  Device: ___________________________
