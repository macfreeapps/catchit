import AppKit
import ApplicationServices
import os

@MainActor
final class AccessibilityPasteMonitor {
    private let logger = Logger(subsystem: "com.tarudesu.CatchIt", category: "Permissions")
    private var monitor: Any?
    var onPaste: (() -> Void)?

    var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    func requestAccess() -> Bool {
        let option = CFStringCreateWithCString(nil, "AXTrustedCheckOptionPrompt", CFStringBuiltInEncodings.UTF8.rawValue)
        guard let option else { return false }
        return AXIsProcessTrustedWithOptions([option: true] as CFDictionary)
    }

    func start() -> Bool {
        stop()
        guard isTrusted else {
            _ = requestAccess()
            return false
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers?.lowercased() == "v" else { return }
            Task { @MainActor in self?.onPaste?() }
        }
        guard monitor != nil else {
            logger.error("Could not install the paste monitor")
            return false
        }
        return true
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
