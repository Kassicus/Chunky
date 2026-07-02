// chunky/chunky/Features/RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var appSettings
    @State private var live = LiveSessionController()

    var body: some View {
        TabView {
            NavigationStack {
                LiveView(controller: live)
                    .navigationDestination(for: Session.self) { SessionSummaryView(session: $0) }
                    .toolbar {
                        if let session = live.currentSession {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink(value: session) {
                                    Label("This Session", systemImage: "square.stack.3d.up")
                                }
                            }
                        }
                    }
            }
            .tabItem { Label("Live", systemImage: "camera.viewfinder") }

            NavigationStack { AveragesView() }
                .tabItem { Label("Averages", systemImage: "chart.bar.fill") }

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "list.bullet") }

            NavigationStack { ClubsView() }
                .tabItem { Label("Clubs", systemImage: "bag.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .environment(\.shotStore, ShotStore(context: modelContext))
        .tint(Theme.optic)
        .background(Theme.rangeDusk)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Club.self, Shot.self, Session.self, CalibrationProfile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    RootView()
        .modelContainer(container)
        .environment(AppSettings(defaults: UserDefaults(suiteName: "preview-root")!))
}
