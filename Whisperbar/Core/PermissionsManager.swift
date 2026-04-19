import AVFoundation
import Speech
import AppKit
import Combine

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var microphoneGranted = false
    @Published var speechGranted = false
    @Published var accessibilityGranted = false

    var allGranted: Bool { microphoneGranted && speechGranted && accessibilityGranted }

    private var accessibilityPollTimer: Timer?

    private init() {
        checkAll()
    }

    func checkAll() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestMicrophone() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.microphoneGranted = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func requestSpeech() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.speechGranted = status == .authorized
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        startPollingAccessibility()
    }

    func startPollingAccessibility() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if AXIsProcessTrusted() {
                    self.accessibilityGranted = true
                    self.accessibilityPollTimer?.invalidate()
                    self.accessibilityPollTimer = nil
                }
            }
        }
    }
}
