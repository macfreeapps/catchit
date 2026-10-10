import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private enum Command: Int {
        case catchText = 1, catchBarcode, catchSameArea, openFile, toggleAdditive, clearCollection
        case undoClear, toggleReadAloud, captureAndSpeak, stopSpeaking, showHistory, settings, quit
    }

    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var additiveItem: NSMenuItem?
    private var readAloudItem: NSMenuItem?
    private var undoItem: NSMenuItem?
    private var historyItem: NSMenuItem?
    private var stopSpeakingItem: NSMenuItem?

    init(model: AppModel) {
        self.model = model
        super.init()
        configureButton()
        configureMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = Self.makeTemplateMark()
        button.image?.isTemplate = true
        button.toolTip = AppText.localized("Catch It — select screen text")
        button.setAccessibilityLabel("Catch It")
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureMenu() {
        menu.delegate = self
        menu.addItem(item("Catch Text", command: .catchText))
        menu.addItem(item("Catch Barcode", command: .catchBarcode))
        menu.addItem(item("Catch Same Area", command: .catchSameArea))
        menu.addItem(.separator())

        let imports = submenu("Import")
        let continuity = NSMenuItem(title: AppText.localized("Import from iPhone or iPad"), action: nil, keyEquivalent: "")
        continuity.identifier = NSMenuItem.importFromDeviceIdentifier
        imports.addItem(continuity)
        imports.addItem(item("Open Image or PDF…", command: .openFile))

        let clipboard = submenu("Clipboard")
        let additive = item("Additive Mode", command: .toggleAdditive)
        additiveItem = additive
        clipboard.addItem(additive)
        clipboard.addItem(.separator())
        let undo = item("Undo Clear Collection", command: .undoClear)
        undoItem = undo
        clipboard.addItem(undo)
        clipboard.addItem(item("Clear Collection", command: .clearCollection))

        let speech = submenu("Speech")
        let readAloud = item("Read Aloud After Capture", command: .toggleReadAloud)
        readAloudItem = readAloud
        speech.addItem(readAloud)
        speech.addItem(item("Capture and Speak", command: .captureAndSpeak))
        let stop = item("Stop Speaking", command: .stopSpeaking)
        stopSpeakingItem = stop
        speech.addItem(stop)
        let history = item("History…", command: .showHistory)
        historyItem = history
        menu.addItem(history)
        menu.addItem(.separator())
        menu.addItem(item("Settings…", command: .settings))
        menu.addItem(item("Quit Catch It", command: .quit, key: "q"))
        statusItem.menu = nil
    }

    func menuWillOpen(_ menu: NSMenu) {
        additiveItem?.state = model.preferences.general.additiveMode ? .on : .off
        readAloudItem?.state = model.preferences.speech.readAfterCapture ? .on : .off
        undoItem?.isHidden = !model.collection.canUndoClear
        historyItem?.isHidden = !model.preferences.general.showHistory
        stopSpeakingItem?.isHidden = !model.isSpeaking
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            model.startCapture(mode: .text)
        } else if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }

    @objc private func performCommand(_ sender: NSMenuItem) {
        guard let command = Command(rawValue: sender.tag) else { return }
        switch command {
        case .catchText: model.startCapture(mode: .text)
        case .catchBarcode: model.startCapture(mode: .barcode)
        case .catchSameArea: model.catchSameArea()
        case .openFile: model.openFile()
        case .toggleAdditive: model.toggleAdditiveMode()
        case .clearCollection: model.clearCollection()
        case .undoClear: model.undoClearCollection()
        case .toggleReadAloud: model.preferences.speech.readAfterCapture.toggle()
        case .captureAndSpeak: model.startCapture(mode: .speak)
        case .stopSpeaking: model.stopSpeaking()
        case .showHistory: model.showHistory()
        case .settings:
            DispatchQueue.main.async { [weak self] in
                self?.model.showSettings()
            }
        case .quit: NSApp.terminate(nil)
        }
    }

    private func submenu(_ title: String) -> NSMenu {
        let child = NSMenu(title: AppText.localized(title))
        child.delegate = self
        child.autoenablesItems = false
        let parent = NSMenuItem(title: AppText.localized(title), action: nil, keyEquivalent: "")
        parent.submenu = child
        menu.addItem(parent)
        return child
    }

    private func item(_ title: String, command: Command, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: AppText.localized(title), action: #selector(performCommand(_:)), keyEquivalent: key)
        item.target = self
        item.tag = command.rawValue
        return item
    }

    private static func makeTemplateMark() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let page = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 3, width: 9, height: 12), xRadius: 1.5, yRadius: 1.5)
            page.lineWidth = 1.35
            page.lineJoinStyle = .round
            NSColor.black.setStroke()
            page.stroke()

            let textLines = NSBezierPath()
            textLines.lineWidth = 1.15
            textLines.lineCapStyle = .round
            textLines.move(to: NSPoint(x: 4.5, y: 11.5)); textLines.line(to: NSPoint(x: 9.1, y: 11.5))
            textLines.move(to: NSPoint(x: 4.5, y: 9)); textLines.line(to: NSPoint(x: 8.2, y: 9))
            textLines.move(to: NSPoint(x: 4.5, y: 6.5)); textLines.line(to: NSPoint(x: 7.2, y: 6.5))
            textLines.stroke()

            let lens = NSBezierPath(ovalIn: NSRect(x: 8.3, y: 6.2, width: 6.4, height: 6.4))
            lens.lineWidth = 1.45
            lens.stroke()
            let handle = NSBezierPath()
            handle.lineWidth = 1.7
            handle.lineCapStyle = .round
            handle.move(to: NSPoint(x: 13.1, y: 7.5))
            handle.line(to: NSPoint(x: 16, y: 4.6))
            handle.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
