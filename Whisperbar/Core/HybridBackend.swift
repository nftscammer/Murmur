import Foundation

final class HybridBackend: Transcriber {
    let identifier = "hybrid"

    private let apple = AppleBackend()
    private let whisper = WhisperBackend()
    private var bufferedAudio: [Float] = []
    private var partialCB: ((String) -> Void)?

    func transcribe(audio: [Float]) async throws -> String {
        // Run Apple for speed, Whisper for accuracy; return Whisper if available
        async let appleResult = apple.transcribe(audio: audio)
        async let whisperResult: String? = {
            guard self.whisper.isReady else { return nil }
            return try? await self.whisper.transcribe(audio: audio)
        }()

        let apple = try await appleResult
        let whisperFinal = await whisperResult
        return whisperFinal ?? apple
    }

    func startStreaming(audioCallback: @escaping ([Float]) -> Void,
                        partialResultCallback: @escaping (String) -> Void) async throws {
        partialCB = partialResultCallback
        bufferedAudio = []

        // Start Apple for live feedback
        try await apple.startStreaming(audioCallback: { _ in }) { [weak self] partial in
            self?.partialCB?(partial)
        }
    }

    func appendStreamingAudio(_ samples: [Float]) {
        apple.appendStreamingAudio(samples)
        bufferedAudio.append(contentsOf: samples)
    }

    func stopStreaming() async throws -> String {
        let appleResult = (try? await apple.stopStreaming()) ?? ""

        // Show Apple result immediately via callback, then replace with Whisper
        partialCB?(appleResult)

        guard whisper.isReady, !bufferedAudio.isEmpty else { return appleResult }

        let audio = bufferedAudio
        bufferedAudio = []

        do {
            let whisperResult = try await whisper.transcribe(audio: audio)
            return whisperResult
        } catch {
            return appleResult
        }
    }
}
