import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isRecording = false
    @Published var audioLevel: Float = 0
    @Published var elapsedSeconds: Double = 0
    @Published var recentTranscriptions: [String] = []

    var recordingStartTime: Date?
    private var elapsedTimer: Timer?

    private init() {}

    func startRecording() {
        isRecording = true
        recordingStartTime = Date()
        elapsedSeconds = 0
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            Task { @MainActor in
                self.elapsedSeconds = Date().timeIntervalSince(start)
            }
        }
        NotificationCenter.default.post(name: .recordingStateChanged, object: nil)
    }

    func stopRecording() {
        isRecording = false
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        audioLevel = 0
        NotificationCenter.default.post(name: .recordingStateChanged, object: nil)
    }

    func addTranscription(_ text: String) {
        recentTranscriptions.insert(text, at: 0)
        if recentTranscriptions.count > 5 {
            recentTranscriptions = Array(recentTranscriptions.prefix(5))
        }
    }
}
