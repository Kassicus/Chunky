// chunky/chunky/Features/Live/ResultCardView.swift
import SwiftUI
import SwiftData

struct ResultCardView: View {
    let result: ShotResult
    let shot: Shot?
    let units: Units
    let onExclude: () -> Void
    let onDelete: () -> Void

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            carryHeader
            if expanded {
                expandedMetrics
            }
            actionButtons
        }
        .background(Theme.turf)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Carry header (always visible)

    private var carryHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(units.formattedCarry(fromMeters: result.carryMeters))
                        .font(Theme.number(64))
                        .foregroundStyle(Theme.confidenceColor(result.confidence))
                    Text("CARRY")
                        .font(Theme.eyebrow)
                        .kerning(1.5)
                        .foregroundStyle(Theme.mist)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    confidenceChip
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            expanded.toggle()
                        }
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(Theme.eyebrow)
                            .foregroundStyle(Theme.mist)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }

    private var confidenceChip: some View {
        Text(result.confidence.rawValue)
            .font(Theme.eyebrow)
            .foregroundStyle(Theme.confidenceColor(result.confidence))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.confidenceColor(result.confidence).opacity(0.18))
            .clipShape(Capsule())
    }

    // MARK: - Expanded metrics

    private var expandedMetrics: some View {
        VStack(spacing: 0) {
            rowDivider
            metricRow(
                label: "Ball speed",
                value: String(format: "%.1f", result.ballSpeedMPH),
                unit: "mph"
            )
            rowDivider
            metricRow(
                label: "Launch angle",
                value: String(format: "%.1f°", result.launchAngleDeg),
                unit: ""
            )
            rowDivider
            metricRow(
                label: "Spin",
                value: "\(Int(result.spinRPM)) rpm",
                unit: "",
                badge: result.spinSource.rawValue
            )
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.turfLine)
            .frame(height: 1)
            .padding(.leading, 16)
    }

    @ViewBuilder
    private func metricRow(label: String, value: String, unit: String, badge: String? = nil) -> some View {
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
                .foregroundStyle(Theme.chalk)
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

    // MARK: - Action buttons (always visible, one tap each)

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onExclude) {
                Label("Exclude", systemImage: "flag.fill")
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.amber.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button(action: onDelete) {
                Label("Delete", systemImage: "trash.fill")
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.flag)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.flag.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview

#Preview {
    let result = ShotResult(
        ballSpeedMS: 66,
        launchAngleDeg: 14.5,
        azimuthDeg: 0,
        spinRPM: 6500,
        spinSource: .modeled,
        spinAxisTiltDeg: 0,
        carryMeters: 150,
        confidence: .high,
        fitRmsResidualMeters: 0.01,
        usedFrameCount: 8
    )
    ZStack {
        Theme.rangeDusk.ignoresSafeArea()
        ResultCardView(result: result, shot: nil, units: .yards, onExclude: {}, onDelete: {})
            .padding()
    }
}
