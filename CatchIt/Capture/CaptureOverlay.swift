import AppKit
import os

struct CaptureSelection {
    let globalRect: CGRect
    let screenFrame: CGRect
    let displayID: CGDirectDisplayID
    let backingScale: CGFloat
    let toggles: CaptureToggles
}

struct CaptureToggles {
    var keepLineBreaks: Bool
    var additiveMode: Bool
    var speakAfterCapture: Bool
}

@MainActor
final class CaptureOverlayCoordinator {
    var onSelection: ((CaptureSelection) -> Void)?
    var onInvalidSelection: ((CGPoint) -> Void)?
    private var panels: [CapturePanel] = []
    private let logger = Logger(subsystem: "com.tarudesu.CatchIt", category: "Overlay")
    private var cursorIsPushed = false
    var isCapturing: Bool { !panels.isEmpty }

    func beginCaptureAfterCurrentEvent(toggles: CaptureToggles) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                self?.beginCapture(toggles: toggles)
                continuation.resume()
            }
        }
    }

    func beginCapture(toggles: CaptureToggles) {
        guard panels.isEmpty else { return }
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        panels = screens.compactMap { screen in
            guard let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let panel = CapturePanel(screen: screen, displayID: displayNumber.uint32Value, toggles: toggles) { [weak self] rect, selectionScreen, displayID, toggles in
                self?.finishCapture(rect: rect, screen: selectionScreen, displayID: displayID, toggles: toggles)
            } onCancel: { [weak self] in
                self?.cancelCapture()
            }
            return panel
        }

        guard !panels.isEmpty else {
            logger.error("No display panels could be created")
            return
        }

        let cursorLocation = NSEvent.mouseLocation
        let activePanel = panels.first { $0.screenFrame.contains(cursorLocation) } ?? panels.first
        for panel in panels where panel !== activePanel {
            panel.orderFrontRegardless()
        }
        activePanel?.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.push()
        cursorIsPushed = true
    }

    private func finishCapture(rect: CGRect, screen: NSScreen, displayID: CGDirectDisplayID, toggles: CaptureToggles) {
        let clipped = rect.intersection(screen.frame)
        dismissPanels()
        guard clipped.width >= 3, clipped.height >= 3 else {
            onInvalidSelection?(NSEvent.mouseLocation)
            return
        }
        let selection = CaptureSelection(
            globalRect: clipped,
            screenFrame: screen.frame,
            displayID: displayID,
            backingScale: screen.backingScaleFactor,
            toggles: toggles
        )
        onSelection?(selection)
    }

    func cancelCapture() {
        dismissPanels()
    }

    private func dismissPanels() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        if cursorIsPushed {
            NSCursor.pop()
            cursorIsPushed = false
        }
    }
}

@MainActor
private final class CapturePanel: NSPanel {
    let screenFrame: CGRect

    init(
        screen: NSScreen,
        displayID: CGDirectDisplayID,
        toggles: CaptureToggles,
        onSelection: @escaping (CGRect, NSScreen, CGDirectDisplayID, CaptureToggles) -> Void,
        onCancel: @escaping () -> Void
    ) {
        screenFrame = screen.frame
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false

        let overlay = CaptureOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
        overlay.toggles = toggles
        overlay.onSelection = { rect, toggles in onSelection(rect, screen, displayID, toggles) }
        overlay.onCancel = onCancel
        overlay.setAccessibilityElement(true)
        overlay.setAccessibilityRole(.group)
        overlay.setAccessibilityLabel(AppText.localized("Screen selection"))
        overlay.setAccessibilityHelp(AppText.localized("Drag to choose an area. Press Escape to cancel. Press L to toggle line breaks, A to toggle additive mode, and S to toggle speaking."))
        contentView = overlay
        initialFirstResponder = overlay
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class CaptureOverlayView: NSView {
    var onSelection: ((CGRect, CaptureToggles) -> Void)?
    var onCancel: (() -> Void)?
    var toggles = CaptureToggles(keepLineBreaks: true, additiveMode: false, speakAfterCapture: false)

    private var anchor: CGPoint?
    private var selectionRect: CGRect?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let selectionRect else { return }
        NSColor(calibratedWhite: 0.5, alpha: 0.34).setFill()
        selectionRect.fill()
        let outlineRect = selectionRect.insetBy(dx: 0.75, dy: 0.75)
        let outline = NSBezierPath(rect: outlineRect)
        outline.lineWidth = 2.5
        NSColor.black.withAlphaComponent(0.7).setStroke()
        outline.stroke()
        outline.lineWidth = 1
        NSColor.white.withAlphaComponent(0.9).setStroke()
        outline.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        anchor = point
        selectionRect = CGRect(origin: point, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor else { return }
        let point = convert(event.locationInWindow, from: nil)
        selectionRect = CGRect(
            x: min(anchor.x, point.x),
            y: min(anchor.y, point.y),
            width: abs(point.x - anchor.x),
            height: abs(point.y - anchor.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let selectionRect else { return }
        guard let screenRect = window?.convertToScreen(selectionRect) else { return }
        self.selectionRect = nil
        anchor = nil
        onSelection?(screenRect, toggles)
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if event.keyCode == 53, modifiers.isEmpty {
            onCancel?()
        } else {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "l": toggles.keepLineBreaks.toggle()
            case "a": toggles.additiveMode.toggle()
            case "s": toggles.speakAfterCapture.toggle()
            default: super.keyDown(with: event); return
            }
            needsDisplay = true
        }
    }

}
