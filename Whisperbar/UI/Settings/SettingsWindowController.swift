import AppKit
import SwiftUI

enum SettingsTab: String {
    case general, hotkey, model, stats, about
}

final class SettingsWindowController: NSObject, NSWindowDelegate, ObservableObject {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    @Published var selectedTab: SettingsTab = .general

    private override init() {}

    func show() { showTab(.general) }

    func showTab(_ tab: SettingsTab) {
        selectedTab = tab
        if window == nil { buildWindow() }
        window?.center()
        window?.orderFrontRegardless()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
    }

    private func buildWindow() {
        let view = SettingsView()
            .environmentObject(AppState.shared)
            .environmentObject(self)
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.title = "Murmur Settings"
        w.styleMask = NSWindow.StyleMask([.titled, .closable, .miniaturizable, .resizable])
        w.setContentSize(NSSize(width: 520, height: 400))
        w.isReleasedWhenClosed = false
        w.delegate = self
        window = w
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
