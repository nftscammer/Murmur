import SwiftUI
import KeyboardShortcuts

struct MainPopoverView: View {
    let closePopover: () -> Void
    @EnvironmentObject var appState: AppState
    @AppStorage("abTestMode") private var abTestMode = true
    @AppStorage("defaultBackend") private var defaultBackend = "apple"
    @AppStorage("triggerMode") private var triggerMode = "toggle"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "waveform.badge.mic")
                    .foregroundStyle(.blue)
                Text("Murmur")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(abTestMode ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(abTestMode ? "A/B" : "Single")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    // Dictation button
                    Button {
                        closePopover()
                        Task {
                            if appState.isRecording {
                                await DictationController.shared.endRecording()
                            } else {
                                await DictationController.shared.beginRecording()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: appState.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .foregroundStyle(appState.isRecording ? .red : .blue)
                                .font(.title2)
                            Text(appState.isRecording ? "Stop Recording" : "Start Dictation")
                                .font(.body.weight(.medium))
                            Spacer()
                            Text("⌥Space")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.horizontal, 16)

                    // Settings rows
                    VStack(spacing: 0) {
                        SettingRow(icon: "shuffle", label: "Blind A/B Mode") {
                            Toggle("", isOn: $abTestMode).labelsHidden()
                        }

                        if !abTestMode {
                            SettingRow(icon: "cpu", label: "Backend") {
                                Picker("", selection: $defaultBackend) {
                                    Text("Apple").tag("apple")
                                    Text("Whisper").tag("whisper")
                                    Text("Hybrid").tag("hybrid")
                                }
                                .labelsHidden()
                                .frame(width: 90)
                            }
                        }

                        SettingRow(icon: "hand.tap", label: "Trigger") {
                            Picker("", selection: $triggerMode) {
                                Text("Toggle").tag("toggle")
                                Text("Hold").tag("hold")
                            }
                            .labelsHidden()
                            .frame(width: 90)
                            .onChange(of: triggerMode) { _, _ in
                                NotificationCenter.default.post(name: .triggerModeChanged, object: nil)
                            }
                        }

                        // Hotkey recorder — inline, no separate window needed
                        HStack {
                            Image(systemName: "keyboard")
                                .foregroundStyle(.blue)
                                .frame(width: 20)
                            Text("Hotkey")
                                .font(.callout)
                            Spacer()
                            KeyboardShortcuts.Recorder(for: .toggleDictation)
                                .controlSize(.small)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }

                    Divider().padding(.horizontal, 16)

                    // Recent transcriptions
                    if !appState.recentTranscriptions.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            ForEach(Array(appState.recentTranscriptions.prefix(3).enumerated()), id: \.offset) { _, text in
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(text, forType: .string)
                                } label: {
                                    HStack {
                                        Text(text.prefix(50) + (text.count > 50 ? "…" : ""))
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Divider().padding(.horizontal, 16)
                    }

                    // Compact A/B stats
                    if abTestMode {
                        StatsCompactRow()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        Divider().padding(.horizontal, 16)
                    }
                }
            }

            Divider()

            // Footer
            HStack(spacing: 0) {
                footerButton("Settings", icon: "gearshape") {
                    closePopover()
                    SettingsWindowController.shared.show()
                }
                Divider().frame(height: 32)
                footerButton("Updates", icon: "arrow.down.circle") {
                    closePopover()
                    AppDelegate.shared.checkForUpdates()
                }
                Divider().frame(height: 32)
                footerButton("Quit", icon: "power") {
                    NSApp.terminate(nil)
                }
            }
            .frame(height: 44)
        }
        .frame(width: 300)
    }

    private func footerButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}

struct SettingRow<Control: View>: View {
    let icon: String
    let label: String
    let control: () -> Control

    init(icon: String, label: String, @ViewBuilder control: @escaping () -> Control) {
        self.icon = icon; self.label = label; self.control = control
    }

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.blue).frame(width: 20)
            Text(label).font(.callout)
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

struct StatsCompactRow: View {
    @State private var stats: [SessionStore.BackendStats] = []
    @State private var totalRated = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("A/B Stats").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(totalRated) rated").font(.caption2).foregroundStyle(.tertiary)
            }
            if stats.isEmpty {
                Text("No sessions yet — start dictating!").font(.caption2).foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 8) {
                    ForEach(stats, id: \.backend) { s in
                        VStack(spacing: 1) {
                            Text("B\(backendLetter(s.backend))").font(.caption2.bold())
                            Text("\(Int(s.avgRatingScore * 100 / 3))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear { loadStats() }
    }

    private func loadStats() {
        stats = (try? SessionStore.shared.fetchStats()) ?? []
        totalRated = (try? SessionStore.shared.totalRatedSessions()) ?? 0
    }

    private func backendLetter(_ b: String) -> String {
        switch b { case "apple": return "A"; case "whisper": return "W"; default: return "H" }
    }
}
