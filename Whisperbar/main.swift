import AppKit

// Strong reference held at module scope — survives the run loop.
let _appDelegate = AppDelegate.shared
NSApplication.shared.delegate = _appDelegate
NSApplication.shared.run()
