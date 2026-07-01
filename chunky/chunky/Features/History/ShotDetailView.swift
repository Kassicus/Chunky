// chunky/chunky/Features/History/ShotDetailView.swift
import SwiftUI
import SwiftData

struct ShotDetailView: View {
    @Bindable var shot: Shot
    let store: ShotStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("units") private var unitsRaw = Units.yards.rawValue

    private var units: Units { Units(rawValue: unitsRaw) ?? .yards }
    private var carryValue: Int { Int(units.carry(fromMeters: shot.carryMeters).rounded()) }
    private var hasRawTrack: Bool { shot.rawTrackJSON != nil }

    // Custom binding routes through store.setExcluded so save() is called.
    private var excludedBinding: Binding<Bool> {
        Binding(
            get: { shot.isExcludedFromAverages },
            set: { store.setExcluded(shot, $0) }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.rangeDusk.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    carryHero
                    metricsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    actionsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 48)
                }
            }
        }
        .navigationTitle(shot.club?.name ?? "Shot detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text(shot.timestamp, style: .date)
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.mist)
            }
        }
    }

    // MARK: - Carry hero (largest element per design spec)

    private var carryHero: some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(carryValue)")
                    .font(Theme.display(44))
                    .foregroundStyle(shot.isExcludedFromAverages ? Theme.mist : Theme.optic)
                    .monospacedDigit()
                Text(units.abbreviation)
                    .font(Theme.number(22))
                    .foregroundStyle(Theme.mist)
            }
            Text("CARRY")
                .font(Theme.eyebrow)
                .kerning(1.5)
                .foregroundStyle(Theme.mist)
            if shot.isExcludedFromAverages {
                Label("Excluded from averages", systemImage: "flag.fill")
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.flag)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Theme.turf)
    }

    // MARK: - Metrics card

    private var metricsCard: some View {
        VStack(spacing: 0) {
            metricRow(
                label: "Ball speed",
                value: String(format: "%.1f", Conversions.msToMPH(shot.ballSpeedMS)),
                unit: "mph"
            )
            rowDivider
            metricRow(
                label: "Launch angle",
                value: String(format: "%.1f", shot.launchAngleDeg),
                unit: "°"
            )
            rowDivider
            metricRow(
                label: "Spin",
                value: "\(Int(shot.spinRPM.rounded()))",
                unit: "rpm",
                badge: shot.spinSource == .measured ? "measured" : "modeled"
            )
            rowDivider
            metricRow(
                label: "Confidence",
                value: ConfidenceStyle.label(shot.confidence),
                unit: "",
                accent: Theme.confidenceColor(shot.confidence)
            )
            if let clubSpeed = shot.clubSpeedMS {
                rowDivider
                metricRow(
                    label: "Club speed",
                    value: String(format: "%.1f", Conversions.msToMPH(clubSpeed)),
                    unit: "mph"
                )
            }
            if let smash = shot.smashFactor {
                rowDivider
                metricRow(
                    label: "Smash factor",
                    value: String(format: "%.2f", smash),
                    unit: ""
                )
            }
            rowDivider
            rawTrackRow
        }
        .background(Theme.turf)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var rawTrackRow: some View {
        HStack(spacing: 8) {
            Text("Raw track data")
                .font(Theme.number(15))
                .foregroundStyle(Theme.mist)
            Spacer()
            Image(systemName: hasRawTrack ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(hasRawTrack ? Theme.optic : Theme.mist)
            Text(hasRawTrack ? "Present" : "None")
                .font(Theme.number(13))
                .foregroundStyle(hasRawTrack ? Theme.optic : Theme.mist)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.turfLine)
            .frame(height: 1)
            .padding(.leading, 16)
    }

    @ViewBuilder
    private func metricRow(label: String, value: String, unit: String,
                            badge: String? = nil, accent: Color? = nil) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.number(15))
                .foregroundStyle(Theme.mist)
            Spacer()
            if let badge {
                Text(badge)
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.mist)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.turfLine)
                    .clipShape(Capsule())
            }
            Text(value)
                .font(Theme.number(15))
                .foregroundStyle(accent ?? Theme.chalk)
                .monospacedDigit()
            if !unit.isEmpty {
                Text(unit)
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.mist)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Per-shot actions

    private var actionsCard: some View {
        VStack(spacing: 12) {
            // Exclude (mishit) toggle — one tap
            Toggle(isOn: excludedBinding) {
                Label("Exclude (mishit)", systemImage: "flag.fill")
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.amber)
            }
            .tint(Theme.amber)
            .padding()
            .background(Theme.turf)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Delete — one tap, no confirmation (per spec §11)
            Button {
                store.deleteShots([shot])
                dismiss()
            } label: {
                Label("Delete shot", systemImage: "trash.fill")
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.flag)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.flag.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Preview

#Preview("Shot detail — driver with raw track") {
    let schema = Schema([Club.self, Shot.self, Session.self, CalibrationProfile.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let ctx = container.mainContext

    let driver = Club(name: "Driver", type: .driver, order: 0, modeledSpinRPM: 2500)
    ctx.insert(driver)

    let shot = Shot(timestamp: .now, ballSpeedMS: 73.2, launchAngleDeg: 11.0,
                    azimuthDeg: -0.5, spinRPM: 2600, spinSource: .measured,
                    spinAxisTiltDeg: 0, clubSpeedMS: 50.2, smashFactor: 1.46,
                    carryMeters: 220, confidence: .high,
                    rawTrackJSON: "{\"frames\":42}")
    shot.club = driver
    ctx.insert(shot)
    try? ctx.save()

    return NavigationStack {
        ShotDetailView(shot: shot, store: ShotStore(context: ctx))
    }
    .modelContainer(container)
}

#Preview("Shot detail — excluded mishit") {
    let schema = Schema([Club.self, Shot.self, Session.self, CalibrationProfile.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let ctx = container.mainContext

    let iron = Club(name: "7-Iron", type: .iron, order: 0, modeledSpinRPM: 6500)
    ctx.insert(iron)

    let shot = Shot(timestamp: .now.addingTimeInterval(-3600), ballSpeedMS: 61.5,
                    launchAngleDeg: 10.4, azimuthDeg: 2.1, spinRPM: 5800,
                    spinSource: .modeled, spinAxisTiltDeg: 0, carryMeters: 138,
                    confidence: .low, isExcludedFromAverages: true)
    shot.club = iron
    ctx.insert(shot)
    try? ctx.save()

    return NavigationStack {
        ShotDetailView(shot: shot, store: ShotStore(context: ctx))
    }
    .modelContainer(container)
}
