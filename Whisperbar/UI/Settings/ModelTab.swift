import SwiftUI

struct ModelTab: View {
    @AppStorage("defaultBackend") private var defaultBackend = "apple"
    @AppStorage("abTestMode") private var abTestMode = false
    @StateObject private var downloader = ModelDownloader.shared

    var body: some View {
        Form {
            Section("Default Backend") {
                if abTestMode {
                    Text("A/B test mode is active — backend is chosen randomly per session.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    Picker("Backend", selection: $defaultBackend) {
                        Text("Apple (on-device)").tag("apple")
                        Text("Whisper (base.en)").tag("whisper")
                        Text("Hybrid (Apple live + Whisper final)").tag("hybrid")
                    }
                    .pickerStyle(.radioGroup)
                }
            }

            Section("Whisper Model") {
                if downloader.isReady {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("ggml-base.en loaded")
                        Spacer()
                        EmptyView()
                    }
                    Button("Unload Model") {
                        Task { await ModelDownloader.shared.downloadModel() }
                    }
                    .buttonStyle(.bordered)
                } else if downloader.isDownloading {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Downloading ggml-base.en.bin…")
                        ProgressView(value: downloader.downloadProgress)
                        Text("\(Int(downloader.downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Model not downloaded (~140 MB)")
                        .foregroundStyle(.secondary)
                    Button("Download Whisper Model") {
                        Task { await downloader.downloadModel() }
                    }
                    .buttonStyle(.borderedProminent)
                    if let err = downloader.errorMessage {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
