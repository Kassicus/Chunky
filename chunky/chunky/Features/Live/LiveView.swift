// chunky/chunky/Features/Live/LiveView.swift
//
// Live / Range capture screen.
// Full-bleed camera + tee-box overlay, club selector, calibrate sheet,
// lens toggle, status banners, arm/disarm, and auto-displayed result card.
//
// Build + #Preview verified. On-device camera, ROI accuracy, and
// shot-trigger behavior are validated by the Task 15 on-device checklist.

import AVFoundation
import CoreVideo
import SwiftData
import SwiftUI

// MARK: - LiveView

struct LiveView: View {

    // MARK: - Input
    let controller: LiveSessionController

    // MARK: - Environment
    @Environment(AppSettings.self) private var settings
    @Environment(\.shotStore) private var store

    // MARK: - SwiftData
    @Query(sort: \Club.order) private var allClubs: [Club]

    // MARK: - Local state
    @State private var teeBoxRect = CGRect(x: 0.3, y: 0.35, width: 0.4, height: 0.3)
    @State private var showCalibrate = false
    @State private var showDebug = false
    @State private var hasAttached = false

    // MARK: - Derived
    private var clubs: [Club] { allClubs.filter { !$0.isArchived } }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── 1. Full-bleed camera preview ─────────────────────────────────
            CameraPreviewView(session: controller.previewSession)
                .ignoresSafeArea()

            // ── 2. Tee-box ROI overlay (draggable/resizable) ─────────────────
            TeeBoxOverlay(roi: $teeBoxRect)

            // ── 3. Top chrome: status banners + lens toggle ───────────────────
            VStack(spacing: 0) {
                topChrome
                    .padding(.horizontal, 16)
                    .padding(.top, 56)
                Spacer()
            }

            // ── 4. Bottom chrome: result card or empty state + controls ───────
            VStack(spacing: 0) {
                Spacer()
                if let result = controller.latestResult {
                    resultSection(result: result)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                } else {
                    emptyState
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }
                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
            }
        }
        // Attach store + settings once
        .task {
            guard !hasAttached, let store else { return }
            controller.attach(store: store, settings: settings)
            hasAttached = true
        }
        // Calibration sheet
        .sheet(isPresented: $showCalibrate) {
            CalibrateView(controller: controller) { scale in
                controller.activeCalibration = scale
                showCalibrate = false
            }
        }
        // Debug overlay sheet
        .sheet(isPresented: $showDebug) {
            if let r = controller.latestResult {
                DebugOverlayView(
                    track: ShotTrackCodec.decode(controller.latestTrackJSON ?? "") ?? [],
                    result: r,
                    calibration: controller.activeCalibration
                        ?? CalibrationScale(pixelsPerMeter: 1, imageUpUnit: Vec2(0, -1))
                )
            }
        }
    }

    // MARK: - Top chrome

    private var topChrome: some View {
        HStack(alignment: .top, spacing: 12) {
            statusBanner
            Spacer()
            lensToggleButton
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch controller.status {
        case .needsMoreLight:
            bannerPill("More light needed", color: Theme.amber)
        case .unauthorized:
            bannerPill("Camera or mic access needed", color: Theme.flag)
        case .failed(let msg):
            bannerPill("Capture failed: \(msg)", color: Theme.flag)
        default:
            EmptyView()
        }
    }

    private func bannerPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.eyebrow)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.45), lineWidth: 1))
    }

    private var lensToggleButton: some View {
        Button {
            Task { await controller.toggleLens() }
        } label: {
            let label = controller.currentLens == .telephoto ? "Tele" : "Wide"
            HStack(spacing: 4) {
                Image(systemName: "camera.aperture")
                    .font(.caption2)
                Text(label)
                    .font(Theme.eyebrow)
            }
            .foregroundStyle(Theme.chalk)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.rangeDusk.opacity(0.75))
            .clipShape(Capsule())
        }
    }

    // MARK: - Empty state (pre-shot)

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("RANGE READY")
                .font(Theme.eyebrow)
                .kerning(2)
                .foregroundStyle(Theme.mist)
            Text("Select a club, calibrate, then arm.")
                .font(Theme.body)
                .foregroundStyle(Theme.chalk.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Theme.rangeDusk.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Result section (post-shot)

    @ViewBuilder
    private func resultSection(result: ShotResult) -> some View {
        VStack(spacing: 8) {
            ResultCardView(
                result: result,
                shot: controller.latestShot,
                units: settings.units,
                onExclude: {
                    if let s = controller.latestShot {
                        store?.setExcluded(s, true)
                    }
                },
                onDelete: {
                    if let s = controller.latestShot {
                        store?.deleteShots([s])
                        controller.clearLatest()
                    }
                }
            )

            if settings.debugOverlayEnabled {
                Button {
                    showDebug = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption)
                        Text("Debug")
                            .font(Theme.eyebrow)
                    }
                    .foregroundStyle(Theme.mist)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.turf)
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Bottom controls panel

    private var bottomControls: some View {
        VStack(spacing: 10) {
            // Club selector
            clubSelector

            // Calibrate + Arm row
            HStack(spacing: 10) {
                calibrateButton
                armDisarmButton
            }
        }
        .padding(14)
        .background(Theme.rangeDusk.opacity(0.90))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // Club selector (Menu)
    private var clubSelector: some View {
        Menu {
            ForEach(clubs) { club in
                Button(club.name) {
                    controller.selectedClub = club
                }
            }
            if clubs.isEmpty {
                Text("No clubs — add one in the Clubs tab")
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bag.fill")
                    .font(.callout)
                    .foregroundStyle(
                        controller.selectedClub != nil ? Theme.optic : Theme.mist
                    )
                Text(controller.selectedClub?.name ?? "Select a club")
                    .font(Theme.number(17))
                    .foregroundStyle(
                        controller.selectedClub != nil ? Theme.chalk : Theme.mist
                    )
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Theme.turf)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // Calibrate button with optional SCALE LOCKED badge
    private var calibrateButton: some View {
        let locked = controller.activeCalibration != nil
        return Button {
            showCalibrate = true
        } label: {
            VStack(spacing: 3) {
                Text("Calibrate")
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.chalk)
                if locked {
                    Text("SCALE LOCKED")
                        .font(Theme.eyebrow)
                        .kerning(0.8)
                        .foregroundStyle(Theme.optic)
                } else {
                    Text("Required")
                        .font(Theme.eyebrow)
                        .foregroundStyle(Theme.mist)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(locked ? Theme.optic.opacity(0.14) : Theme.turf)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(locked ? Theme.optic.opacity(0.40) : Color.clear, lineWidth: 1)
            )
        }
    }

    // Arm / Disarm button
    private var armDisarmButton: some View {
        let armed = controller.status == .running
        // Disarm is always available while running. Arming is blocked from any
        // non-running state unless a club AND calibration are set (canArm) — so
        // .unauthorized/.needsMoreLight/.failed with no club/calibration cannot arm.
        let cannotArm = !armed && !controller.canArm

        return Button {
            if armed {
                controller.disarm()
            } else {
                Task {
                    await controller.arm()
                    if controller.status == .running {
                        createSessionIfNeeded()
                        setTeeBoxROI()
                    }
                }
            }
        } label: {
            Text(armed ? "Disarm" : "Arm")
                .font(Theme.number(17))
                .foregroundStyle(
                    armed   ? Theme.amber :
                    cannotArm ? Theme.mist : Theme.rangeDusk
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    armed   ? Theme.amber.opacity(0.20) :
                    cannotArm ? Theme.turf : Theme.optic
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(cannotArm)
    }

    // MARK: - Session creation (first arm only)

    private func createSessionIfNeeded() {
        guard controller.currentSession == nil, let store else { return }
        let session = Session(
            date: Date(),
            lens: settings.lens,
            temperatureC: settings.temperatureC,
            altitudeM: settings.altitudeM,
            humidity: settings.humidity
        )
        store.context.insert(session)
        try? store.context.save()
        controller.currentSession = session
    }

    // MARK: - Tee-box ROI conversion (normalized → image pixels)

    /// Converts the normalized `teeBoxRect` to image-pixel coordinates using
    /// the most-recent captured frame dimensions. Falls back to nil (audio-only
    /// departure detection) in the Simulator where no camera frames are available.
    /// NOTE: this is an on-device approximation — the preview layer uses
    /// resizeAspectFill, so fractional mapping is accurate only when preview
    /// fill matches frame dimensions. Tuned on-device per Task 15.
    private func setTeeBoxROI() {
        guard let frame = controller.latestFrame() else {
            controller.teeBoxROI = nil   // audio-only fallback
            return
        }
        let w = CVPixelBufferGetWidth(frame)
        let h = CVPixelBufferGetHeight(frame)
        controller.teeBoxROI = (
            x: Int(teeBoxRect.minX * Double(w)),
            y: Int(teeBoxRect.minY * Double(h)),
            w: Int(teeBoxRect.width  * Double(w)),
            h: Int(teeBoxRect.height * Double(h))
        )
    }
}

// MARK: - Preview

#Preview("Live — no camera") {
    let schema = Schema([Club.self, Shot.self, Session.self, CalibrationProfile.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let ctx = container.mainContext

    // Seed a couple of clubs
    let driver = Club(name: "Driver", type: .driver, order: 0, modeledSpinRPM: 2700)
    let iron7  = Club(name: "7 Iron", type: .iron,   order: 1, modeledSpinRPM: 7000)
    ctx.insert(driver)
    ctx.insert(iron7)
    try? ctx.save()

    return LiveView(controller: LiveSessionController())
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview-live")!))
        .environment(\.shotStore, ShotStore(context: ctx))
        .modelContainer(container)
}
