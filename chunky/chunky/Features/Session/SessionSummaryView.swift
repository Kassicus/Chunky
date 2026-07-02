// chunky/chunky/Features/Session/SessionSummaryView.swift
import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    let session: Session
    @Environment(\.shotStore) private var store
    @Environment(AppSettings.self) private var settings
    @State private var csvURL: URL? = nil

    // MARK: — Computed projections

    private var records: [ShotRecord] {
        guard let store else { return [] }
        return session.shots.map { store.record(from: $0) }
    }

    private var aggregates: ClubAggregates? {
        ClubAggregates.compute(from: records)
    }

    // MARK: — Body

    var body: some View {
        ZStack {
            Theme.rangeDusk.ignoresSafeArea()
            if records.isEmpty {
                emptyState
            } else {
                summaryList
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .shortened))
        .toolbar {
            if let url = csvURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .tint(Theme.optic)
                }
            }
        }
        .onAppear { buildCSV() }
        .onChange(of: settings.units) { _, _ in buildCSV() }
    }

    // MARK: — Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.mist)
            Text("No shots in this session yet.")
                .font(Theme.body)
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: — Summary list

    private var summaryList: some View {
        List {
            // Stats section — only when there are non-excluded shots to aggregate
            if let agg = aggregates {
                Section {
                    statsRow("Shots", value: "\(agg.shotCount)")
                    statsRow(
                        "Mean carry",
                        value: settings.units.formattedCarry(fromMeters: agg.meanCarryMeters)
                    )
                    statsRow(
                        "Median carry",
                        value: settings.units.formattedCarry(fromMeters: agg.medianCarryMeters)
                    )
                } header: {
                    sectionHeader("Session Stats")
                }
            }

            // Individual shots
            Section {
                ForEach(records) { record in
                    shotRow(record)
                }
            } header: {
                sectionHeader("Shots (\(records.count))")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.rangeDusk)
        .listStyle(.plain)
    }

    // MARK: — Row helpers

    private func statsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.body)
                .foregroundStyle(Theme.chalk)
            Spacer()
            Text(value)
                .font(Theme.number(17))
                .foregroundStyle(Theme.optic)
        }
        .listRowBackground(Theme.turf)
    }

    private func shotRow(_ record: ShotRecord) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.confidenceColor(record.confidence))
                .frame(width: 8, height: 8)
                .opacity(record.isExcludedFromAverages ? 0.4 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.clubName)
                    .font(Theme.number(17))
                    .foregroundStyle(Theme.chalk)
                Text(ConfidenceStyle.label(record.confidence) + " confidence")
                    .font(Theme.eyebrow)
                    .kerning(0.8)
                    .foregroundStyle(Theme.confidenceColor(record.confidence))
            }
            .opacity(record.isExcludedFromAverages ? 0.5 : 1.0)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(settings.units.formattedCarry(fromMeters: record.carryMeters))
                    .font(Theme.number(17))
                    .foregroundStyle(Theme.chalk)
                    .opacity(record.isExcludedFromAverages ? 0.5 : 1.0)
                if record.isExcludedFromAverages {
                    Image(systemName: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.flag)
                }
            }
        }
        .listRowBackground(Theme.turf)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Theme.eyebrow)
            .kerning(1.2)
            .foregroundStyle(Theme.mist)
    }

    // MARK: — CSV export

    private func buildCSV() {
        guard let store else { csvURL = nil; return }
        let recs = session.shots.map { store.record(from: $0) }
        let csv = CSVExport.shots(recs, units: settings.units)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-\(session.id.uuidString).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            csvURL = url
        } catch {
            csvURL = nil
        }
    }
}

// MARK: — Preview

#Preview("Session Summary — seeded") {
    let schema = Schema([Club.self, Shot.self, Session.self, CalibrationProfile.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let ctx = container.mainContext

    let session = Session(
        date: .now, location: "Range A", lens: .telephoto,
        temperatureC: 15, altitudeM: 0, humidity: 50
    )
    ctx.insert(session)

    let iron = Club(name: "7-Iron", type: .iron, order: 0, modeledSpinRPM: 6500)
    ctx.insert(iron)

    let s1 = Shot(
        timestamp: .now, ballSpeedMS: 67.3, launchAngleDeg: 12.1,
        azimuthDeg: 0, spinRPM: 6200, spinSource: .modeled,
        spinAxisTiltDeg: 0, carryMeters: 150, confidence: .high
    )
    s1.club = iron
    s1.session = session
    ctx.insert(s1)

    let s2 = Shot(
        timestamp: .now.addingTimeInterval(-600), ballSpeedMS: 61.5,
        launchAngleDeg: 10.4, azimuthDeg: 2.1, spinRPM: 5800,
        spinSource: .modeled, spinAxisTiltDeg: 0, carryMeters: 138,
        confidence: .medium, isExcludedFromAverages: true
    )
    s2.club = iron
    s2.session = session
    ctx.insert(s2)

    try? ctx.save()

    return NavigationStack {
        SessionSummaryView(session: session)
    }
    .modelContainer(container)
    .environment(\.shotStore, ShotStore(context: ctx))
    .environment(AppSettings(defaults: UserDefaults(suiteName: "preview-session")!))
}
