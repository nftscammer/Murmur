import Foundation
import AppKit

@MainActor
final class DictationController {
    static let shared = DictationController()

    private let recorder = AudioRecorder.shared
    private let router = BackendRouter.shared
    private let injector = TextInjector.shared
    private let store = SessionStore.shared
    private var sessionStartTime: Date?
    private var activeAppleBackend: AppleBackend?
    private var activeHybridBackend: HybridBackend?

    private init() {}

    func beginRecording() async {
        guard !AppState.shared.isRecording else { return }

        // Prompt permissions if missing — but don't block recording attempt
        if !PermissionsManager.shared.microphoneGranted {
            await PermissionsManager.shared.requestMicrophone()
        }
        if !PermissionsManager.shared.speechGranted {
            await PermissionsManager.shared.requestSpeech()
        }

        SoundPlayer.playStart()
        AppState.shared.startRecording()
        sessionStartTime = Date()
        activeAppleBackend = nil
        activeHybridBackend = nil

        let backend = router.selectBackend()

        // Capture cursor position for live partial injection
        injector.beginPartialSession()

        // Wire up streaming for Apple / Hybrid
        if let hybrid = backend as? HybridBackend {
            activeHybridBackend = hybrid
            try? await hybrid.startStreaming(audioCallback: { _ in }) { [weak self] partial in
                guard let self else { return }
                DispatchQueue.main.async { self.injector.injectPartial(partial) }
            }
            recorder.onAudioChunk = { [weak hybrid] samples in
                hybrid?.appendStreamingAudio(samples)
            }
        } else if let appleB = backend as? AppleBackend {
            activeAppleBackend = appleB
            try? await appleB.startStreaming(audioCallback: { _ in }) { [weak self] partial in
                guard let self else { return }
                DispatchQueue.main.async { self.injector.injectPartial(partial) }
            }
            recorder.onAudioChunk = { [weak appleB] samples in
                appleB?.appendStreamingAudio(samples)
            }
        }
        // Whisper: no live feed needed, just accumulates in recorder.audioBuffer

        do {
            try recorder.startRecording()
        } catch {
            AppState.shared.stopRecording()
            SoundPlayer.playStop()
            return
        }

        RecordingHUDController.shared.show()
    }

    func endRecording() async {
        guard AppState.shared.isRecording else { return }
        SoundPlayer.playStop()

        let startTime = sessionStartTime ?? Date()
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        let audio = recorder.stopRecording()
        AppState.shared.stopRecording()
        RecordingHUDController.shared.hide()

        let backendName = router.activeBackendName
        let transcribeStart = Date()

        do {
            let text: String

            if let hybrid = activeHybridBackend {
                activeHybridBackend = nil
                text = try await hybrid.stopStreaming()
            } else if let appleB = activeAppleBackend {
                activeAppleBackend = nil
                text = try await appleB.stopStreaming()
            } else {
                // Whisper batch
                guard let backend = router.activeBackend else { return }
                text = try await backend.transcribe(audio: audio)
            }

            let latencyMs = Int(Date().timeIntervalSince(transcribeStart) * 1000)
            let wordCount = text.split(separator: " ").count

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("Empty transcription — nothing to inject")
                return
            }

            injector.commitFinal(text)
            SoundPlayer.playReady()
            AppState.shared.addTranscription(text)

            var session = Session(
                id: nil,
                timestamp: startTime,
                backend: backendName,
                durationMs: durationMs,
                latencyMs: latencyMs,
                wordCount: wordCount,
                transcript: text,
                rating: nil
            )
            try store.save(&session)

            if UserDefaults.standard.bool(forKey: "abTestMode"), let id = session.id {
                RatingToastController.shared.show(sessionId: id)
            }
        } catch {
            print("Transcription error: \(error)")
        }
    }
}

// MARK: - Sound Player

final class SoundPlayer {
    static func playStart() { play("Tink") }
    static func playStop()  { play("Morse") }
    static func playReady() { play("Glass") }

    private static func play(_ name: String) {
        NSSound(named: name)?.play()
    }
}
