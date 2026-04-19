import AppKit
import CoreGraphics

final class TextInjector {
    static let shared = TextInjector()
    private init() {}

    // State for live partial injection
    private var partialTarget: AXUIElement?
    private var partialInsertionOffset: Int = 0  // character offset where partial text starts
    private var partialLength: Int = 0            // length of currently-injected partial text

    func inject(_ text: String) {
        if let focused = focusedTextElement(), insertViaAX(focused, text: text) { return }
        pasteViaClipboard(text)
    }

    // Call at start of recording to capture focused element + cursor position
    func beginPartialSession() {
        partialTarget = focusedTextElement()
        partialLength = 0
        partialInsertionOffset = cursorOffset(in: partialTarget)
    }

    // Inject/replace partial streaming text in-place
    func injectPartial(_ text: String) {
        guard let el = partialTarget else { return }
        selectRange(CFRangeMake(partialInsertionOffset, partialLength), in: el)
        AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, text as CFString)
        partialLength = text.count
    }

    // Commit final text, replacing any partial text, and clear session state
    func commitFinal(_ text: String) {
        guard let el = partialTarget else {
            inject(text)
            return
        }
        selectRange(CFRangeMake(partialInsertionOffset, partialLength), in: el)
        if AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, text as CFString) != .success {
            inject(text)
        }
        partialTarget = nil
        partialLength = 0
    }

    private func selectRange(_ range: CFRange, in el: AXUIElement) {
        var r = range
        if let axVal = AXValueCreate(.cfRange, &r) {
            AXUIElementSetAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, axVal)
        }
    }

    private func cursorOffset(in el: AXUIElement?) -> Int {
        guard let el else { return 0 }
        var val: AnyObject?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &val) == .success,
              let axVal = val else { return 0 }
        var range = CFRange(location: 0, length: 0)
        AXValueGetValue(axVal as! AXValue, .cfRange, &range)
        return range.location
    }

    func focusedTextElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              CFGetTypeID(focused as AnyObject) == AXUIElementGetTypeID() else { return nil }
        return (focused as! AXUIElement)
    }

    private func insertViaAX(_ el: AXUIElement, text: String) -> Bool {
        if AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, text as CFString) == .success {
            return true
        }
        var current: AnyObject?
        guard AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &current) == .success,
              let str = current as? String else { return false }
        return AXUIElementSetAttributeValue(el, kAXValueAttribute as CFString, (str + text) as CFString) == .success
    }

    private func pasteViaClipboard(_ text: String) {
        let pb = NSPasteboard.general
        let savedItems = pb.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }

        pb.clearContents()
        pb.setString(text, forType: .string)

        let src = CGEventSource(stateID: .combinedSessionState)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pb.clearContents()
            if let saved = savedItems { pb.writeObjects(saved) }
        }
    }
}
