// chunky/chunky/Features/History/HistoryView.swift
import SwiftUI
import SwiftData

// Enums without raw values need an explicit conformance declaration;
// Swift synthesises the implementation since all cases have no associated values.
extension ShotSort: Hashable {}

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Shot.timestamp, order: .reverse) private var shots: [Shot]
    @AppStorage("units") private var unitsRaw = Units.yards.rawValue

    @State private var filter = ShotFilter()
    @State private var sortOrder = ShotSort.newest
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<UUID>()

    private var units: Units { Units(rawValue: unitsRaw) ?? .yards }
    private var store: ShotStore { ShotStore(context: context) }

    // Required wiring: project shots → records, then filter + sort.
    private var displayedRecords: [ShotRecord] {
        let records = shots.map { store.record(from: $0) }
        return sortOrder.sort(filter.apply(to: records))
    }

    var body: some View {
        ZStack {
            Theme.rangeDusk.ignoresSafeArea()
            if shots.isEmpty {
                emptyState
            } else {
                shotList
                    .safeAreaInset(edge: .bottom) {
                        if editMode.isEditing && !selection.isEmpty {
                            bulkActionBar
                        }
                    }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton().tint(Theme.optic)
            }
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
        .environment(\.editMode, $editMode)
        .onChange(of: editMode) { _, newMode in
            if newMode == .inactive { selection.removeAll() }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.mist)
            Text("No shots yet. Tag a club and take a swing.")
                .font(Theme.number(17))
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - List

    private var shotList: some View {
        List(selection: $selection) {
            if displayedRecords.isEmpty {
                Text("No shots match your filters.")
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.mist)
                    .listRowBackground(Theme.turf)
            }
            ForEach(displayedRecords) { record in
                NavigationLink {
                    if let shot = shots.first(where: { $0.id == record.id }) {
                        ShotDetailView(shot: shot, store: store)
                    }
                } label: {
                    ShotRow(record: record, units: units)
                }
                .listRowBackground(Theme.turf)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.rangeDusk)
        .listStyle(.plain)
    }

    // MARK: - Filter / sort menu

    private var filterMenu: some View {
        Menu {
            Section("Sort") {
                ForEach([ShotSort.newest, .oldest, .longestCarry, .shortestCarry], id: \.self) { s in
                    Button {
                        sortOrder = s
                    } label: {
                        Label(s.historyLabel, systemImage: sortOrder == s ? "checkmark" : "")
                    }
                }
            }
            Section("Filter") {
                Toggle("Show excluded", isOn: $filter.includeExcluded)
                Button { filter.confidence = nil } label: {
                    Label("All confidence",
                          systemImage: filter.confidence == nil ? "checkmark" : "")
                }
                ForEach([ConfidenceLevel.high, .medium, .low], id: \.rawValue) { c in
                    Button { filter.confidence = c } label: {
                        Label(ConfidenceStyle.label(c) + " confidence",
                              systemImage: filter.confidence == c ? "checkmark" : "")
                    }
                }
            }
        } label: {
            Image(systemName: filterIsActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .foregroundStyle(filterIsActive ? Theme.optic : Theme.chalk)
        }
    }

    private var filterIsActive: Bool {
        filter.confidence != nil || !filter.includeExcluded
    }

    // MARK: - Bulk action bar (edit mode, non-empty selection)

    private var bulkActionBar: some View {
        HStack(spacing: 24) {
            Spacer()

            // Exclude — map selected UUIDs back to Shot objects and call store.setExcluded
            Button {
                let toExclude = shots.filter { selection.contains($0.id) }
                toExclude.forEach { store.setExcluded($0, true) }
                withAnimation { selection.removeAll(); editMode = .inactive }
            } label: {
                Text("Exclude")
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Theme.amber.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Delete — map selected UUIDs back to Shot objects and call store.deleteShots
            Button {
                let toDelete = shots.filter { selection.contains($0.id) }
                store.deleteShots(toDelete)
                withAnimation { selection.removeAll(); editMode = .inactive }
            } label: {
                Text("Delete")
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.flag)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Theme.flag.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Shot row

private struct ShotRow: View {
    let record: ShotRecord
    let units: Units

    var body: some View {
        HStack(spacing: 12) {
            // Confidence dot
            Circle()
                .fill(Theme.confidenceColor(record.confidence))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.clubName)
                    .font(Theme.number(17))
                    .foregroundStyle(Theme.chalk)
                Text(record.timestamp, style: .date)
                    .font(Theme.eyebrow)
                    .foregroundStyle(Theme.mist)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                // Tabular carry value in current units
                Text(units.formattedCarry(fromMeters: record.carryMeters))
                    .font(Theme.number(17))
                    .foregroundStyle(Theme.chalk)
                    .monospacedDigit()
                // Flag marker on excluded shots
                if record.isExcludedFromAverages {
                    Image(systemName: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.flag)
                }
            }
        }
        // Dim excluded rows
        .opacity(record.isExcludedFromAverages ? 0.5 : 1.0)
    }
}

// MARK: - ShotSort display label

private extension ShotSort {
    var historyLabel: String {
        switch self {
        case .newest: "Newest first"
        case .oldest: "Oldest first"
        case .longestCarry: "Longest carry"
        case .shortestCarry: "Shortest carry"
        }
    }
}

// MARK: - Preview (in-memory, seeded: two clubs, three shots including one excluded)

#Preview("History — seeded") {
    let schema = Schema([Club.self, Shot.self, Session.self, CalibrationProfile.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let ctx = container.mainContext

    let driver = Club(name: "Driver", type: .driver, order: 0, modeledSpinRPM: 2500)
    let iron = Club(name: "7-Iron", type: .iron, order: 1, modeledSpinRPM: 6500)
    ctx.insert(driver)
    ctx.insert(iron)

    // Shot 1: normal, high confidence
    let s1 = Shot(timestamp: .now, ballSpeedMS: 67.3, launchAngleDeg: 12.1,
                  azimuthDeg: 0, spinRPM: 6200, spinSource: .modeled,
                  spinAxisTiltDeg: 0, carryMeters: 150, confidence: .high)
    s1.club = iron
    ctx.insert(s1)

    // Shot 2: excluded (mishit), medium confidence — should appear dimmed + flagged
    let s2 = Shot(timestamp: .now.addingTimeInterval(-3600), ballSpeedMS: 61.5,
                  launchAngleDeg: 10.4, azimuthDeg: 2.1, spinRPM: 5800,
                  spinSource: .modeled, spinAxisTiltDeg: 0, carryMeters: 138,
                  confidence: .medium, isExcludedFromAverages: true)
    s2.club = iron
    ctx.insert(s2)

    // Shot 3: driver, measured spin, club speed + smash
    let s3 = Shot(timestamp: .now.addingTimeInterval(-7200), ballSpeedMS: 73.2,
                  launchAngleDeg: 11.0, azimuthDeg: -0.5, spinRPM: 2600,
                  spinSource: .measured, spinAxisTiltDeg: 0,
                  clubSpeedMS: 50.2, smashFactor: 1.46, carryMeters: 220,
                  confidence: .high)
    s3.club = driver
    ctx.insert(s3)

    try? ctx.save()

    return NavigationStack { HistoryView() }
        .modelContainer(container)
}
