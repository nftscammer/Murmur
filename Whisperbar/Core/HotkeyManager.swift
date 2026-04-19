import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    static let toggleDictation = Self("toggleDictation", default: .init(.space, modifiers: .option))
}

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var isHolding = false

    private init() {}

    func setup() {
        updateBindings()
        NotificationCenter.default.addObserver(
            forName: .triggerModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateBindings() }
        }
    }

    private func updateBindings() {
        let mode = TriggerMode(rawValue: UserDefaults.standard.string(forKey: "triggerMode") ?? "") ?? .toggle

        KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                switch mode {
                case .hold:
                    if !self.isHolding {
                        self.isHolding = true
                        await DictationController.shared.beginRecording()
                    }
                case .toggle:
                    if AppState.shared.isRecording {
                        await DictationController.shared.endRecording()
                    } else {
                        await DictationController.shared.beginRecording()
                    }
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .toggleDictation) { [weak self] in
            guard let self else { return }
            if mode == .hold && self.isHolding {
                self.isHolding = false
                Task { @MainActor in
                    await DictationController.shared.endRecording()
                }
            }
        }
    }
}

enum TriggerMode: String, CaseIterable {
    case hold
    case toggle

    var displayName: String {
        switch self {
        case .hold: return "Hold to record"
        case .toggle: return "Toggle on/off"
        }
    }
}

extension Notification.Name {
    static let triggerModeChanged = Notification.Name("triggerModeChanged")
}
