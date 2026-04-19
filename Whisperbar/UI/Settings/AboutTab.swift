import SwiftUI

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("Murmur")
                .font(.largeTitle.bold())

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                credit("Speech Engine", "Apple SFSpeechRecognizer (on-device)")
                credit("Whisper Engine", "WhisperKit by Argmax (wraps whisper.cpp)")
                credit("Hotkeys", "KeyboardShortcuts by Sindre Sorhus")
                credit("Database", "GRDB.swift by Gwendal Roué")
            }

            Spacer()
        }
        .padding(32)
    }

    private func credit(_ role: String, _ name: String) -> some View {
        HStack {
            Text(role + ":").font(.caption).foregroundStyle(.secondary).frame(width: 120, alignment: .trailing)
            Text(name).font(.caption)
        }
    }
}
