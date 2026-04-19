import Speech
import AVFoundation

final class AppleBackend: Transcriber {
    let identifier = "apple"

    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var partialCallback: ((String) -> Void)?
    private var finalResult = ""
    private var resultContinuation: CheckedContinuation<String, Error>?
    private var settled = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        ?? SFSpeechRecognizer()!

    private let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: 16000, channels: 1, interleaved: false)!

    // MARK: - Streaming (primary path)

    func startStreaming(audioCallback: @escaping ([Float]) -> Void,
                        partialResultCallback: @escaping (String) -> Void) async throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        resultContinuation = nil
        finalResult = ""
        settled = false
        partialCallback = partialResultCallback

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Don't require on-device — let macOS decide; server fallback ensures it works
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                self.finalResult = text
                self.partialCallback?(text)
                if result.isFinal {
                    self.settle(text)
                }
            }
            if let error {
                // If we have partial text, return it; otherwise propagate
                let text = self.finalResult
                if text.isEmpty {
                    self.settleError(error)
                } else {
                    self.settle(text)
                }
            }
        }
    }

    func appendStreamingAudio(_ samples: [Float]) {
        guard let request = recognitionRequest, !samples.isEmpty else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
                                            frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { ptr in
            buffer.floatChannelData![0].update(from: ptr.baseAddress!, count: samples.count)
        }
        request.append(buffer)
    }

    func stopStreaming() async throws -> String {
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // If already settled (isFinal fired before stop), return immediately
        if settled { return finalResult }

        return try await withCheckedThrowingContinuation { [weak self] cont in
            guard let self else { cont.resume(returning: ""); return }
            // Double-check race: might have settled between the `if settled` check and here
            if self.settled {
                cont.resume(returning: self.finalResult)
                return
            }
            self.resultContinuation = cont
            // 5-second hard timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self, let cont = self.resultContinuation else { return }
                self.resultContinuation = nil
                self.recognitionTask?.cancel()
                cont.resume(returning: self.finalResult)
            }
        }
    }

    // MARK: - Batch (non-streaming)

    func transcribe(audio: [Float]) async throws -> String {
        try await startStreaming(audioCallback: { _ in }, partialResultCallback: { _ in })
        appendStreamingAudio(audio)
        return try await stopStreaming()
    }

    // MARK: - Helpers

    private func settle(_ text: String) {
        guard !settled else { return }
        settled = true
        finalResult = text
        if let cont = resultContinuation {
            resultContinuation = nil
            cont.resume(returning: text)
        }
    }

    private func settleError(_ error: Error) {
        guard !settled else { return }
        settled = true
        if let cont = resultContinuation {
            resultContinuation = nil
            cont.resume(throwing: TranscriberError.recognitionFailed(error.localizedDescription))
        }
    }
}
