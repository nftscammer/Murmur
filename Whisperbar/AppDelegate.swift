import AppKit
import SwiftUI
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {

    static let shared = AppDelegate()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private(set) var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        UserDefaults.standard.register(defaults: [
            "abTestMode": true,
            "triggerMode": "toggle",
            "defaultBackend": "apple",
        ])

        // Sparkle updater — manual only until SUFeedURL is configured
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController.updater.automaticallyChecksForUpdates = true

        setupStatusItem()

        NotificationCenter.default.addObserver(self, selector: #selector(recordingStateChanged),
                                               name: .recordingStateChanged, object: nil)

        if !UserDefaults.standard.bool(forKey: "onboardingComplete") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                OnboardingWindowController.shared.show()
            }
        }

        HotkeyManager.shared.setup()

        Task.detached(priority: .background) {
            await ModelDownloader.shared.loadIfAvailable()
        }
    }

    // MARK: - Status item + popover

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(recording: false)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MainPopoverView(closePopover: { [weak self] in self?.closePopover() })
                .environmentObject(AppState.shared)
        )

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp])
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func updateIcon(recording: Bool) {
        guard let button = statusItem?.button else { return }
        let symbolName = recording ? "waveform.badge.mic" : "waveform"
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        button.image?.isTemplate = !recording
        button.contentTintColor = recording ? .systemRed : nil
    }

    @objc private func recordingStateChanged() {
        DispatchQueue.main.async {
            self.updateIcon(recording: AppState.shared.isRecording)
        }
    }

    @objc func checkForUpdates() {
        updaterController.checkForUpdates(self)
    }
}

extension Notification.Name {
    static let recordingStateChanged = Notification.Name("recordingStateChanged")
}
