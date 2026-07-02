// chunky/chunky/Features/Calibrate/CalibrateView.swift
//
// Calibration sheet: establishes the pixels-per-meter scale (and gravity
// up-vector) for a range session via marker auto-detection or manual
// two-point measurement.
//
// Build + #Preview verified. On-device camera and manual geometry accuracy
// are validated by the human checklist in Task 15 / live-ondevice-acceptance.md.

import AVFoundation
import CoreVideo
import SwiftData
import SwiftUI

// MARK: - Mode

private enum CalibrationMode: String, CaseIterable, Identifiable {
    case marker = "Marker"
    case manual = "Manual"
    var id: String { rawValue }
}

// MARK: - Tap point (view coords + pre-converted pixel coords)

/// Stores a manual tap: the view-space point for drawing markers, and the
/// image-pixel coordinate for CalibrationMath.
private struct TapPoint {
    let viewPoint: CGPoint
    let pixelPoint: Vec2
}

// MARK: - CalibrateView

struct CalibrateView: View {

    // MARK: - Inputs
    let controller: LiveSessionController
    let onCalibrated: (CalibrationScale) -> Void

    // MARK: - Environment
    @Environment(AppSettings.self) private var settings
    @Environment(\.shotStore) private var store
    @Environment(\.dismiss) private var dismiss

    // MARK: - Device attitude
    @State private var attitude = DeviceAttitude()

    // MARK: - Mode
    @State private var mode: CalibrationMode = .marker

    // MARK: - Shared scale result
    @State private var computedScale: CalibrationScale?

    // MARK: - Marker mode
    @State private var markerSideMM: Double = 150
    @State private var markerSideMMText: String = "150"
    @State private var isDetecting = false
    @State private var detectionError: String?

    // MARK: - Manual mode
    @State private var knownLengthMeters: Double = 1.0
    @State private var knownLengthText: String = "1.0"
    @State private var manualTapPoints: [TapPoint] = []

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Background: live camera preview ──────────────────────────────
            CameraPreviewView(session: controller.previewSession)
                .ignoresSafeArea()

            // ── Dim overlay ──────────────────────────────────────────────────
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            // ── Chrome ───────────────────────────────────────────────────────
            VStack(spacing: 0) {
                modePicker

                // Middle region: tap-capture in manual mode, spacer otherwise
                if mode == .manual && computedScale == nil {
                    manualTapArea
                } else {
                    Spacer()
                }

                bottomCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
        }
        .onAppear { attitude.start() }
        .onDisappear { attitude.stop() }
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        Picker("Calibration Mode", selection: $mode) {
            ForEach(CalibrationMode.allCases) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .onChange(of: mode) { _, _ in resetState() }
    }

    // MARK: - Manual tap area (invisible tap catcher + point markers)

    private var manualTapArea: some View {
        GeometryReader { geo in
            ZStack {
                // Transparent tap catcher
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { tapLoc in
                        handleManualTap(tapLoc, geoSize: geo.size)
                    }

                // Tap point markers
                ForEach(manualTapPoints.indices, id: \.self) { i in
                    tapMarker(at: manualTapPoints[i].viewPoint, index: i)
                }

                // Hint text when no points yet
                if manualTapPoints.isEmpty {
                    Text("Tap two points on the preview above")
                        .font(Theme.eyebrow)
                        .foregroundStyle(Theme.chalk.opacity(0.72))
                }
            }
        }
    }

    private func tapMarker(at pt: CGPoint, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(Theme.optic.opacity(0.22))
                .frame(width: 44, height: 44)
            Circle()
                .stroke(Theme.optic, lineWidth: 2)
                .frame(width: 44, height: 44)
            Text("\(index + 1)")
                .font(Theme.eyebrow)
                .foregroundStyle(Theme.optic)
        }
        .position(pt)
    }

    // MARK: - Bottom card

    private var bottomCard: some View {
        VStack(spacing: 20) {
            if let scale = computedScale {
                scaleLockedView(scale: scale)
            } else {
                switch mode {
                case .marker: markerModeContent
                case .manual: manualModeContent
                }
            }

            // Confirm / Cancel
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .font(Theme.number(17))
                    .foregroundStyle(Theme.mist)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.turf)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Use Scale") { confirmCalibration() }
                    .font(Theme.number(17))
                    .foregroundStyle(computedScale != nil ? Theme.rangeDusk : Theme.mist)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(computedScale != nil ? Theme.optic : Theme.turf)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(computedScale == nil)
            }
        }
        .padding(20)
        .background(Theme.rangeDusk.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Scale locked (signature element)

    private func scaleLockedView(scale: CalibrationScale) -> some View {
        VStack(spacing: 8) {
            Text("SCALE LOCKED")
                .font(Theme.eyebrow)
                .kerning(2.5)
                .foregroundStyle(Theme.optic)

            Text(String(format: "%.0f px/m", scale.pixelsPerMeter))
                .font(Theme.number(52))
                .foregroundStyle(Theme.optic)

            Text("Tap 'Use Scale' to confirm and continue.")
                .font(Theme.body)
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)

            Button(mode == .marker ? "Re-detect" : "Re-measure") {
                withAnimation { resetState() }
            }
            .font(Theme.eyebrow)
            .foregroundStyle(Theme.mist)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: - Marker mode content

    @ViewBuilder
    private var markerModeContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MARKER AUTO-DETECT")
                .font(Theme.eyebrow)
                .kerning(1.5)
                .foregroundStyle(Theme.mist)

            Text("Point at the target and tap Detect.")
                .font(Theme.body)
                .foregroundStyle(Theme.chalk)

            // Marker side length
            VStack(alignment: .leading, spacing: 6) {
                Text("MARKER SIDE (MM)")
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.mist)

                HStack(spacing: 10) {
                    TextField("150", text: $markerSideMMText)
                        .keyboardType(.decimalPad)
                        .font(Theme.number(17))
                        .foregroundStyle(Theme.chalk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.turf)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onChange(of: markerSideMMText) { _, v in
                            if let d = Double(v), d > 0, d != markerSideMM {
                                markerSideMM = d
                            }
                        }

                    Stepper("", value: $markerSideMM, in: 10.0...1000.0, step: 10.0)
                        .labelsHidden()
                        .onChange(of: markerSideMM) { _, v in
                            let fmt = String(format: "%.0f", v)
                            if fmt != markerSideMMText { markerSideMMText = fmt }
                        }
                }
            }

            // Detection error
            if let err = detectionError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.flag)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(err)
                        .font(Theme.body)
                        .foregroundStyle(Theme.flag)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Detect button
            Button { runDetection() } label: {
                HStack(spacing: 8) {
                    if isDetecting {
                        ProgressView().tint(Theme.rangeDusk).scaleEffect(0.85)
                    } else {
                        Image(systemName: "viewfinder")
                    }
                    Text(isDetecting ? "Detecting…" : "Detect")
                }
                .font(Theme.number(17))
                .foregroundStyle(Theme.rangeDusk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isDetecting ? Theme.optic.opacity(0.7) : Theme.optic)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isDetecting)
        }
    }

    // MARK: - Manual mode content

    @ViewBuilder
    private var manualModeContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MANUAL TWO-POINT")
                .font(Theme.eyebrow)
                .kerning(1.5)
                .foregroundStyle(Theme.mist)

            Text("Enter the known length, then tap two points on the preview above.")
                .font(Theme.body)
                .foregroundStyle(Theme.chalk)
                .fixedSize(horizontal: false, vertical: true)

            // Known length field
            VStack(alignment: .leading, spacing: 6) {
                Text("KNOWN LENGTH (METERS)")
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.mist)

                TextField("1.0", text: $knownLengthText)
                    .keyboardType(.decimalPad)
                    .font(Theme.number(17))
                    .foregroundStyle(Theme.chalk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.turf)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: knownLengthText) { _, v in
                        if let d = Double(v), d > 0, d != knownLengthMeters {
                            knownLengthMeters = d
                        }
                    }
            }

            // Tap point status pills
            HStack(spacing: 16) {
                ForEach(0..<2, id: \.self) { i in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(i < manualTapPoints.count ? Theme.optic : Theme.turfLine)
                            .frame(width: 9, height: 9)
                        Text(i < manualTapPoints.count ? "Point \(i + 1) set" : "Point \(i + 1)")
                            .font(Theme.eyebrow)
                            .foregroundStyle(
                                i < manualTapPoints.count ? Theme.optic : Theme.mist
                            )
                    }
                }

                Spacer()

                if !manualTapPoints.isEmpty {
                    Button("Clear") {
                        manualTapPoints = []
                        computedScale = nil
                    }
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.mist)
                }
            }
        }
    }

    // MARK: - Logic: reset

    private func resetState() {
        computedScale = nil
        detectionError = nil
        isDetecting = false
        manualTapPoints = []
    }

    // MARK: - Logic: marker detection

    private func runDetection() {
        isDetecting = true
        detectionError = nil
        Task {
            guard let frame = controller.latestFrame() else {
                isDetecting = false
                detectionError = "No frame available — make sure the camera is running."
                return
            }
            let corners = await MarkerDetector().detectCorners(in: frame)
            isDetecting = false
            guard let corners, corners.count == 4 else {
                detectionError = "No target found — fill the frame and hold steady."
                return
            }
            let g = attitude.imagePlaneGravity ?? Vec2(0, 1)
            guard let scale = CalibrationMath.calibrationScale(
                markerCornersPx: corners,
                markerSideMeters: markerSideMM / 1000,
                imagePlaneGravity: g
            ) else {
                detectionError = "Detection failed — check the marker size and try again."
                return
            }
            withAnimation { computedScale = scale }
        }
    }

    // MARK: - Logic: manual tap

    private func handleManualTap(_ viewPoint: CGPoint, geoSize: CGSize) {
        // Determine image pixel dimensions.
        // TODO(on-device): preview is resizeAspectFill — for precise manual scale
        // use previewLayer.captureDevicePointConverted(fromLayerPoint:); fractional
        // mapping is a build-verified approximation tuned on-device
        // (see live-ondevice-acceptance.md).
        let imageW: Double
        let imageH: Double
        if let frame = controller.latestFrame() {
            imageW = Double(CVPixelBufferGetWidth(frame))
            imageH = Double(CVPixelBufferGetHeight(frame))
        } else {
            // Simulator / no frame: use nominal 4K landscape as stand-in so
            // the preview chrome (tap markers, point status) can still be exercised.
            imageW = 3840
            imageH = 2160
        }

        let fracX = Double(viewPoint.x) / Double(geoSize.width)
        let fracY = Double(viewPoint.y) / Double(geoSize.height)
        let pixelPoint = Vec2(fracX * imageW, fracY * imageH)
        let tap = TapPoint(viewPoint: viewPoint, pixelPoint: pixelPoint)

        if manualTapPoints.count >= 2 {
            // Third tap restarts the sequence.
            manualTapPoints = [tap]
            computedScale = nil
            return
        }

        manualTapPoints.append(tap)

        guard manualTapPoints.count == 2 else { return }

        let g = attitude.imagePlaneGravity ?? Vec2(0, 1)
        if let scale = CalibrationMath.calibrationScale(
            pointA: manualTapPoints[0].pixelPoint,
            pointB: manualTapPoints[1].pixelPoint,
            knownLengthMeters: knownLengthMeters,
            imagePlaneGravity: g
        ) {
            withAnimation { computedScale = scale }
        }
    }

    // MARK: - Logic: confirm

    private func confirmCalibration() {
        guard let scale = computedScale else { return }
        let profile = CalibrationProfileMapping.profile(
            from: scale,
            lens: settings.lens,
            createdAt: Date()
        )
        store?.context.insert(profile)
        try? store?.context.save()
        onCalibrated(scale)
        dismiss()
    }
}

// MARK: - Preview

#Preview("Calibrate — no camera") {
    let schema = Schema([Club.self, Shot.self, Session.self, CalibrationProfile.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let ctx = container.mainContext
    let previewStore = ShotStore(context: ctx)

    CalibrateView(
        controller: LiveSessionController(),
        onCalibrated: { _ in }
    )
    .environment(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
    .environment(\.shotStore, previewStore)
    .modelContainer(container)
}
