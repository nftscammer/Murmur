import Foundation
import WhisperKit

final class WhisperBackend: Transcriber {
    let identifier = "whisper"

    private var whisperKit: WhisperKit?
    private var isLoading = false

    var isReady: Bool { whisperKit != nil }

    func prepare() async throws {
        guard whisperKit == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let pipe = try await WhisperKit(model: "base.en")
        await MainActor.run { self.whisperKit = pipe }
    }

    func transcribe(audio: [Float]) async throws -> String {
        guard let pipe = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }
        let results = try await pipe.transcribe(audioArray: audio)
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    func startStreaming(audioCallback: @escaping ([Float]) -> Void,
                        partialResultCallback: @escaping (String) -> Void) async throws {
        // Whisper doesn't support live streaming; see HybridBackend
    }

    func stopStreaming() async throws -> String {
        throw TranscriberError.recognitionFailed("Use transcribe(audio:) for WhisperBackend")
    }
}
