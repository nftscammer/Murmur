import SwiftUI
import AppKit

// MARK: - HUD Panel

final class RecordingHUDController {
    static let shared = RecordingHUDController()

    private var panel: NSPanel?

    private init() {}

    func show() {
        DispatchQueue.main.async {
            if self.panel == nil { self.createPanel() }
            self.positionNearFocusedElement()
            self.panel?.orderFrontRegardless()
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.panel?.orderOut(nil)
        }
    }

    private func createPanel() {
        let content = HUDContent().environmentObject(AppState.shared)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 280, height: 72)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.contentView = hosting
        self.panel = p
    }

    private func positionNearFocusedElement() {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        var origin = CGPoint(x: screenFrame.midX - 140, y: screenFrame.minY + 40)

        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
           let focusedAny = focused,
           CFGetTypeID(focusedAny) == AXUIElementGetTypeID() {
            let axEl = focusedAny as! AXUIElement
            var frameValue: AnyObject?
            if AXUIElementCopyAttributeValue(axEl, "AXFrame" as CFString, &frameValue) == .success,
               let val = frameValue,
               CFGetTypeID(val) == AXValueGetTypeID() {
                var frame = CGRect.zero
                AXValueGetValue(val as! AXValue, .cgRect, &frame)
                let screenH = NSScreen.main?.frame.height ?? 900
                let flippedY = screenH - frame.maxY - 80
                origin = CGPoint(x: frame.midX - 140, y: max(0, flippedY))
            }
        }
        panel?.setFrameOrigin(origin)
    }
}

// MARK: - HUD Content View

struct HUDContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 8)

            HStack(spacing: 12) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .symbolEffect(.pulse, isActive: appState.isRecording)

                WaveformView(level: appState.audioLevel)
                    .frame(maxWidth: .infinity)

                Text(formatTime(appState.elapsedSeconds))
                    .font(.system(.caption, design: .monospaced).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 280, height: 72)
        .preferredColorScheme(.dark)
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
