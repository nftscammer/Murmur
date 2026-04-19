import SwiftUI
import KeyboardShortcuts

struct HotkeyTab: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Start / Stop Dictation:", name: .toggleDictation)
                Text("Default: ⌥Space. Works in any app — global hotkey.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Global Hotkey")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
