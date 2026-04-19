import SwiftUI
import AppKit

final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            let content = OnboardingView {
                self.complete()
            }
            let hosting = NSHostingController(rootView: content.environmentObject(PermissionsManager.shared))
            let w = NSWindow(contentViewController: hosting)
            w.title = "Welcome to Murmur"
            w.setContentSize(NSSize(width: 520, height: 440))
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.center()
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        window?.orderOut(nil)
    }
}

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentStep = 0
    @EnvironmentObject var permissions: PermissionsManager

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<6) { i in
                    Circle()
                        .fill(i <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 24)

            OnboardingStepView(step: currentStep, onNext: {
                if currentStep < 5 {
                    withAnimation(.smooth(duration: 0.25)) { currentStep += 1 }
                } else {
                    onComplete()
                }
            }, onComplete: onComplete)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 440)
    }
}
