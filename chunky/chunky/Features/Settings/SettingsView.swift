// chunky/chunky/Features/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var appSettings = settings

        Form {

            // MARK: — Units
            Section {
                Picker("Units", selection: $appSettings.units) {
                    ForEach(Units.allCases, id: \.self) { unit in
                        Text(unit == .yards ? "Yards" : "Meters").tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Theme.turf)
            } header: {
                sectionHeader("Units")
            }

            // MARK: — Environment
            Section {
                Stepper(value: $appSettings.temperatureC, in: -20...50, step: 1) {
                    rowLabel(
                        "Temperature (°C)",
                        value: "\(Int(appSettings.temperatureC.rounded()))°C"
                    )
                }
                .listRowBackground(Theme.turf)

                Stepper(value: $appSettings.altitudeM, in: 0...5000, step: 10) {
                    rowLabel(
                        "Altitude (m)",
                        value: "\(Int(appSettings.altitudeM.rounded())) m"
                    )
                }
                .listRowBackground(Theme.turf)

                Stepper(value: $appSettings.humidity, in: 0...100, step: 1) {
                    rowLabel(
                        "Humidity (%)",
                        value: "\(Int(appSettings.humidity.rounded()))%"
                    )
                }
                .listRowBackground(Theme.turf)
            } header: {
                sectionHeader("Environment")
            }

            // MARK: — Camera
            Section {
                Picker("Default lens", selection: $appSettings.lens) {
                    ForEach(CameraLens.allCases, id: \.self) { lens in
                        Text(lens == .telephoto ? "Telephoto" : "Wide").tag(lens)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Theme.turf)
            } header: {
                sectionHeader("Camera")
            }

            // MARK: — Developer
            Section {
                Toggle(isOn: $appSettings.debugOverlayEnabled) {
                    Text("Debug overlay")
                        .font(Theme.body)
                        .foregroundStyle(Theme.chalk)
                }
                .tint(Theme.optic)
                .listRowBackground(Theme.turf)
            } header: {
                sectionHeader("Developer")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.rangeDusk)
        .navigationTitle("Settings")
    }

    // MARK: — Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Theme.eyebrow)
            .kerning(1.2)
            .foregroundStyle(Theme.mist)
    }

    private func rowLabel(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.body)
                .foregroundStyle(Theme.chalk)
            Spacer()
            Text(value)
                .font(Theme.number(15))
                .foregroundStyle(Theme.mist)
        }
    }
}

// MARK: — Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppSettings(defaults: UserDefaults(suiteName: "preview-settings")!))
}
