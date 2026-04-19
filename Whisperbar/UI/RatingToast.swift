import SwiftUI
import AppKit

final class RatingToastController {
    static let shared = RatingToastController()
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    func show(sessionId: Int64) {
        DispatchQueue.main.async {
            self.dismissWorkItem?.cancel()
            self.panel?.orderOut(nil)
            self.panel = nil

            let content = RatingToastView(sessionId: sessionId) {
                self.dismiss()
            }
            let hosting = NSHostingView(rootView: content)
            hosting.frame = NSRect(x: 0, y: 0, width: 260, height: 56)

            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 260, height: 56),
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
            self.position()
            p.alphaValue = 0
            p.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                p.animator().alphaValue = 1
            }

            let workItem = DispatchWorkItem { self.dismiss() }
            self.dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
        }
    }

    private func position() {
        guard let screen = NSScreen.main, let panel = panel else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(CGPoint(x: frame.maxX - 280, y: frame.maxY - 80))
    }

    func dismiss() {
        guard let p = panel else { return }
        panel = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            p.animator().alphaValue = 0
        }, completionHandler: {
            p.orderOut(nil)
        })
    }
}

struct RatingToastView: View {
    let sessionId: Int64
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(radius: 6)

            HStack(spacing: 8) {
                Text("Rate:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ratingButton("👍", rating: "good")
                ratingButton("👌", rating: "ok")
                ratingButton("👎", rating: "bad")
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 260, height: 56)
        .preferredColorScheme(.dark)
    }

    private func ratingButton(_ emoji: String, rating: String) -> some View {
        Button(emoji) {
            try? SessionStore.shared.updateRating(id: sessionId, rating: rating)
            onDismiss()
        }
        .buttonStyle(.plain)
        .font(.title3)
    }
}
