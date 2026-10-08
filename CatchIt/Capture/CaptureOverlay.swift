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
    private var panels: [CapturePanel] = []
    private let logger = Logger(subsystem: "com.tarudesu.CatchIt", category: "Overlay")

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
    }

    private func finishCapture(rect: CGRect, screen: NSScreen, displayID: CGDirectDisplayID, toggles: CaptureToggles) {
        let clipped = rect.intersection(screen.frame)
        dismissPanels()
        guard clipped.width >= 3, clipped.height >= 3 else { return }
        let selection = CaptureSelection(
            globalRect: clipped,
            screenFrame: screen.frame,
            displayID: displayID,
            backingScale: screen.backingScaleFactor,
            toggles: toggles
        )
        onSelection?(selection)
    }

    private func cancelCapture() {
        dismissPanels()
    }

    private func dismissPanels() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        NSCursor.pop()
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
            defer: false,
            screen: screen
        )
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
        NSColor.black.withAlphaComponent(0.43).setFill()
        bounds.fill()

        drawInstruction()
        drawToggleChips()
        guard let selectionRect else { return }
        NSColor.white.withAlphaComponent(0.07).setFill()
        selectionRect.fill()
        let border = NSBezierPath(roundedRect: selectionRect, xRadius: 5, yRadius: 5)
        border.lineWidth = 2
        NSColor.systemTeal.setStroke()
        border.stroke()
        drawSizeLabel(for: selectionRect)
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

    private func drawInstruction() {
        let text = AppText.localized("Drag to select · L Lines · A Add · S Speak · Esc Cancel")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.5)
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(x: (bounds.width - size.width) / 2, y: bounds.height - size.height - 28, width: size.width, height: size.height)
        (text as NSString).draw(in: rect.insetBy(dx: -10, dy: -7), withAttributes: attributes)
    }

    private func drawToggleChips() {
        let items = [
            (AppText.localized("Line breaks"), toggles.keepLineBreaks),
            (AppText.localized("Additive"), toggles.additiveMode),
            (AppText.localized("Speak"), toggles.speakAfterCapture)
        ]
        var x: CGFloat = 18
        let y: CGFloat = 18
        for (title, active) in items {
            let label = "\(title)  \(AppText.localized(active ? "On" : "Off"))"
            let font = NSFont.systemFont(ofSize: 11, weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white
            ]
            let size = (label as NSString).size(withAttributes: attributes)
            let chip = CGRect(x: x, y: y, width: size.width + 18, height: 27)
            (active ? NSColor.systemTeal.withAlphaComponent(0.95) : NSColor.black.withAlphaComponent(0.68)).setFill()
            NSBezierPath(roundedRect: chip, xRadius: 13, yRadius: 13).fill()
            (label as NSString).draw(at: CGPoint(x: x + 9, y: y + 7), withAttributes: attributes)
            x = chip.maxX + 7
        }
    }

    private func drawSizeLabel(for rect: CGRect) {
        let text = "\(Int(rect.width.rounded())) × \(Int(rect.height.rounded())) pt"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let labelRect = CGRect(x: rect.minX, y: max(8, rect.minY - textSize.height - 13), width: textSize.width + 16, height: textSize.height + 8)
        NSColor.black.withAlphaComponent(0.82).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 5, yRadius: 5).fill()
        (text as NSString).draw(at: CGPoint(x: labelRect.minX + 8, y: labelRect.minY + 4), withAttributes: attributes)
    }
}
