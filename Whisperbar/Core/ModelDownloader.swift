import Foundation
import WhisperKit

@MainActor
final class ModelDownloader: ObservableObject {
    static let shared = ModelDownloader()

    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var isReady = false
    @Published var errorMessage: String?

    private let modelName = "base.en"
    private(set) var whisperBackend = WhisperBackend()

    private init() {}

    func loadIfAvailable() async {
        do {
            try await whisperBackend.prepare()
            isReady = whisperBackend.isReady
        } catch {
            // Model not cached yet — user must download manually
        }
    }

    func downloadModel() async {
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        errorMessage = nil

        do {
            // WhisperKit downloads and caches the model on first init
            let config = WhisperKitConfig(model: modelName, verbose: false, prewarm: true)
            _ = try await WhisperKit(config)
            try await whisperBackend.prepare()
            isReady = whisperBackend.isReady
            downloadProgress = 1.0
        } catch {
            errorMessage = error.localizedDescription
        }

        isDownloading = false
    }
}
