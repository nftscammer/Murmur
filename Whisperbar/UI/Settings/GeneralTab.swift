import SwiftUI
import ServiceManagement

struct GeneralTab: View {
    @AppStorage("abTestMode") private var abTestMode = false
    @AppStorage("triggerMode") private var triggerMode = "toggle"
    @AppStorage("playSounds") private var playSounds = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Recording") {
                Picker("Trigger mode", selection: $triggerMode) {
                    ForEach(TriggerMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: triggerMode) { _, _ in
                    NotificationCenter.default.post(name: .triggerModeChanged, object: nil)
                }
            }

            Section("A/B Testing") {
                Toggle("Blind A/B test mode", isOn: $abTestMode)
                if abTestMode {
                    Text("Each dictation randomly picks Apple, Whisper, or Hybrid. Rate results to find your winner.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Login item error: \(error)")
                        }
                    }

                Toggle("Play interface sounds", isOn: $playSounds)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
