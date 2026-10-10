import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers
import os

enum CaptureMode: Equatable {
    case text
    case barcode
    case speak
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let preferences = AppPreferences()
    let collection = ClipboardCollection()
    let history = HistoryStore()
    @Published private(set) var isSpeaking = false
    @Published var showOnboarding = false

    private let logger = Logger(subsystem: "com.tarudesu.CatchIt", category: "AppModel")
    private let hotKeys = GlobalHotKey()
    private let overlayCoordinator = CaptureOverlayCoordinator()
    private let captureService = ScreenCaptureService()
    private let recognizer = TextRecognizer()
    private let barcodeRecognizer = BarcodeRecognizer()
    private let fileRecognition = FileRecognitionService()
    private let speechController = SpeechController()
    private let pasteMonitor = AccessibilityPasteMonitor()
    private let hudController = ResultHUDController()
    private let continuityCamera = ContinuityCameraImport()
    private var cancellables = Set<AnyCancellable>()
    private var pendingMode: CaptureMode = .text
    private var historyWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var speechStateTask: Task<Void, Never>?

    private struct StoredArea: Codable {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let displayID: UInt32
    }

    private init() {
        overlayCoordinator.onSelection = { [weak self] selection in
            guard let self else { return }
            self.remember(selection)
            self.process(selection, mode: self.pendingMode)
        }
        overlayCoordinator.onInvalidSelection = { [weak self] point in
            self?.showMessage(AppText.localized("Select a larger area"), near: point)
        }
        pasteMonitor.onPaste = { [weak self] in self?.clearCollectionAfterPaste() }
        continuityCamera.onImage = { [weak self] image in self?.recognizeImportedImage(image) }
        NSApp.servicesProvider = continuityCamera
        preferences.shortcuts.$bindings
            .sink { [weak self] _ in self?.refreshHotKeys() }
            .store(in: &cancellables)
        preferences.shortcuts.$enabled
            .dropFirst()
            .sink { [weak self] _ in self?.refreshHotKeys() }
            .store(in: &cancellables)
        preferences.general.$clearAfterPaste
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    if !self.pasteMonitor.start() { self.preferences.general.clearAfterPaste = false }
                } else {
                    self.pasteMonitor.stop()
                }
            }
            .store(in: &cancellables)
    }

    func installHotKeys() {
        refreshHotKeys()
        preferences.general.launchAtLogin = SMAppService.mainApp.status == .enabled
        if preferences.general.clearAfterPaste, !pasteMonitor.start() {
            preferences.general.clearAfterPaste = false
        }
    }

    func refreshHotKeys() {
        guard preferences.shortcuts.enabled else {
            hotKeys.unregister()
            return
        }
        hotKeys.onPress = { [weak self] action in self?.perform(action) }
        hotKeys.register(preferences.shortcuts.bindings)
    }

    func perform(_ action: HotKeyAction) {
        switch action {
        case .catchText: startCapture(mode: .text)
        case .catchBarcode: startCapture(mode: .barcode)
        case .catchSameArea: catchSameArea()
        case .toggleAdditive: preferences.general.additiveMode.toggle()
        case .clearCollection: clearCollection()
        case .captureAndSpeak: startCapture(mode: .speak)
        case .stopSpeaking: stopSpeaking()
        }
    }

    func startCapture(mode: CaptureMode = .text) {
        pendingMode = mode
        let toggles = CaptureToggles(
            keepLineBreaks: preferences.general.keepLineBreaks,
            additiveMode: preferences.general.additiveMode,
            speakAfterCapture: preferences.speech.readAfterCapture || mode == .speak
        )
        // AppKit can still be unwinding the status menu's dismissal callback here.
        // Defer NSWindow initialization until that event has fully returned.
        Task { @MainActor [weak self] in
            await self?.overlayCoordinator.beginCaptureAfterCurrentEvent(toggles: toggles)
        }
    }

    func catchSameArea() {
        guard let data = UserDefaults.standard.data(forKey: "capture.lastArea"),
              let area = try? JSONDecoder().decode(StoredArea.self, from: data),
              let screen = NSScreen.screens.first(where: {
                  ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == area.displayID
              }) else {
            showMessage(AppText.localized("Select an area first"), near: NSEvent.mouseLocation)
            return
        }
        let selection = CaptureSelection(
            globalRect: CGRect(x: area.x, y: area.y, width: area.width, height: area.height),
            screenFrame: screen.frame,
            displayID: area.displayID,
            backingScale: screen.backingScaleFactor,
            toggles: CaptureToggles(
                keepLineBreaks: preferences.general.keepLineBreaks,
                additiveMode: preferences.general.additiveMode,
                speakAfterCapture: preferences.speech.readAfterCapture
            )
        )
        process(selection, mode: .text)
    }

    func toggleAdditiveMode() { preferences.general.additiveMode.toggle() }
    func clearCollection() { collection.clear() }
    func undoClearCollection() { _ = collection.undoClear() }

    func stopSpeaking() {
        speechController.stop()
        speechStateTask?.cancel()
        speechStateTask = nil
        isSpeaking = false
    }

    func setClearAfterPaste(_ enabled: Bool) {
        if enabled {
            guard pasteMonitor.start() else {
                preferences.general.clearAfterPaste = false
                showPermissionAlert(title: AppText.localized("Allow Accessibility Access"), message: AppText.localized("Automatic clearing watches for Command–V so the collection can be cleared after it is pasted. Catch It needs Accessibility access only for this optional feature."), settingsPane: "Privacy_Accessibility")
                return
            }
            preferences.general.clearAfterPaste = true
        } else {
            preferences.general.clearAfterPaste = false
            pasteMonitor.stop()
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            preferences.general.launchAtLogin = enabled
        } catch {
            logger.error("Could not update launch at login: \(error.localizedDescription, privacy: .public)")
            preferences.general.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = AppText.localized("Recognize Text")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let images = try fileRecognition.images(from: url)
                let textParts = try await recognize(images: images, toggles: CaptureToggles(keepLineBreaks: preferences.general.keepLineBreaks, additiveMode: preferences.general.additiveMode, speakAfterCapture: preferences.speech.readAfterCapture))
                let text = textParts.filter { !$0.isEmpty }.joined(separator: "\n\n")
                if text.isEmpty { showMessage(AppText.localized("No text found"), near: NSEvent.mouseLocation) }
                else { deliver(text, additive: preferences.general.additiveMode, near: CGRect(origin: NSEvent.mouseLocation, size: .zero)) }
            } catch {
                logger.error("File recognition failed: \(error.localizedDescription, privacy: .public)")
                showMessage(error.localizedDescription, near: NSEvent.mouseLocation)
            }
        }
    }

    func showHistory() {
        if let historyWindow {
            historyWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = HistoryView(model: self)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = AppText.localized("Catch It History")
        let hostingView = NSHostingView(rootView: root)
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.contentMinSize = NSSize(width: 420, height: 360)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        historyWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 680, height: 520), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = AppText.localized("Catch It Settings")
        let hostingView = NSHostingView(rootView: SettingsView(model: self))
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.contentMinSize = NSSize(width: 640, height: 480)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func presentOnboardingIfNeeded() {
        guard !preferences.general.onboardingComplete else { return }
        showOnboarding = true
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 440), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = AppText.localized("Welcome to Catch It")
        let hostingView = NSHostingView(rootView: OnboardingView(model: self))
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func finishOnboarding() {
        preferences.general.onboardingComplete = true
        onboardingWindow?.close()
        onboardingWindow = nil
        showOnboarding = false
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    func copyHistory(_ entry: HistoryEntry) {
        collection.copyDirectly(entry.text)
        showMessage(AppText.localized("Copied to clipboard"), near: NSEvent.mouseLocation)
    }

    private func process(_ selection: CaptureSelection, mode: CaptureMode) {
        Task {
            do {
                let image = try await captureService.capture(selection)
                if mode == .barcode {
                    let payloads = try await barcodeRecognizer.recognize(in: image)
                    if !payloads.isEmpty {
                        let text = payloads.joined(separator: "\n")
                        deliver(text, additive: selection.toggles.additiveMode, near: selection.globalRect, barcode: true, speak: selection.toggles.speakAfterCapture)
                        return
                    }
                    guard preferences.general.showHUD else {
                        recognizeText(image, selection: selection)
                        return
                    }
                    let model = self
                    hudController.show(message: AppText.localized("No barcode found"), near: selection.globalRect, enabled: preferences.general.showHUD, actions: [
                        HUDAction(title: AppText.localized("Read text instead")) { [weak model] in model?.recognizeText(image, selection: selection) }
                    ])
                    return
                }
                recognizeText(image, selection: selection)
            } catch ScreenCaptureError.permissionDenied {
                logger.error("Screen Recording permission is missing")
                showPermissionAlert(title: AppText.localized("Allow Screen Recording for Catch It"), message: AppText.localized("macOS needs Screen Recording permission so Catch It can read the area you select. After enabling it, quit and reopen Catch It."), settingsPane: "Privacy_ScreenCapture")
            } catch {
                logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
                hudController.show(message: AppText.localized("Capture failed"), near: selection.globalRect, enabled: preferences.general.showHUD)
            }
        }
    }

    private func recognizeText(_ image: CGImage, selection: CaptureSelection) {
        Task {
            do {
                let text = try await recognizer.recognize(in: image, preferences: ocrPreferences(keepLineBreaks: selection.toggles.keepLineBreaks))
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    hudController.show(message: AppText.localized("No text found"), near: selection.globalRect, enabled: preferences.general.showHUD)
                    return
                }
                deliver(text, additive: selection.toggles.additiveMode, near: selection.globalRect, speak: selection.toggles.speakAfterCapture)
            } catch {
                logger.error("Text recognition failed: \(error.localizedDescription, privacy: .public)")
                hudController.show(message: AppText.localized("Recognition failed"), near: selection.globalRect, enabled: preferences.general.showHUD)
            }
        }
    }

    private func recognize(images: [CGImage], toggles: CaptureToggles) async throws -> [String] {
        var recognized: [String] = []
        for image in images {
            recognized.append(try await recognizer.recognize(in: image, preferences: ocrPreferences(keepLineBreaks: toggles.keepLineBreaks)))
        }
        return recognized
    }

    private func recognizeImportedImage(_ image: CGImage) {
        Task {
            do {
                let text = try await recognizer.recognize(in: image, preferences: ocrPreferences(keepLineBreaks: preferences.general.keepLineBreaks))
                guard !text.isEmpty else { showMessage(AppText.localized("No text found"), near: NSEvent.mouseLocation); return }
                deliver(text, additive: preferences.general.additiveMode, near: CGRect(origin: NSEvent.mouseLocation, size: .zero))
            } catch {
                logger.error("Continuity Camera recognition failed: \(error.localizedDescription, privacy: .public)")
                showMessage(AppText.localized("Recognition failed"), near: NSEvent.mouseLocation)
            }
        }
    }

    private func deliver(_ text: String, additive: Bool, near rect: CGRect, barcode: Bool = false, speak: Bool? = nil) {
        collection.copy(text, additive: additive, separator: preferences.general.collectionSeparator)
        if preferences.general.captureSound { NSSound.beep() }
        if preferences.general.showHistory { history.append(text) }

        let detected = SmartActionDetector.detect(in: text)
        let urls = detected.filter { $0.kind == .url }
        if preferences.general.openLinksAutomatically {
            urls.forEach(SmartActionDetector.open)
        }
        if speak ?? preferences.speech.readAfterCapture {
            speechController.speak(text, voiceIdentifier: preferences.speech.voiceIdentifier, rate: preferences.speech.rate)
            isSpeaking = true
            speechStateTask?.cancel()
            speechStateTask = Task { [weak self] in
                guard let self else { return }
                while self.speechController.isSpeaking, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                }
                if !Task.isCancelled { self.isSpeaking = false }
            }
        }

        let message: String
        if barcode {
            message = text.count > 90 ? String(text.prefix(87)) + "…" : text
        } else {
            let wordCount = text.split(whereSeparator: \.isWhitespace).count
            message = wordCount == 1
                ? AppText.localized("Caught one word")
                : AppText.formatted("%lld words caught", wordCount)
        }
        let actions: [HUDAction] = (!preferences.general.openLinksAutomatically && !urls.isEmpty)
            ? [HUDAction(title: AppText.localized("Open link")) { SmartActionDetector.open(urls[0]) }]
            : []
        hudController.show(message: message, near: rect, enabled: preferences.general.showHUD, actions: actions)
    }

    private func showMessage(_ message: String, near point: CGPoint) {
        hudController.show(message: message, near: CGRect(origin: point, size: .zero), enabled: preferences.general.showHUD)
    }

    private func ocrPreferences(keepLineBreaks: Bool) -> OCRPreferences {
        OCRPreferences(
            primaryLanguage: preferences.recognition.primaryLanguage,
            automaticallyDetectsLanguage: preferences.recognition.automaticallyDetectsLanguage,
            codeSymbolsMode: preferences.recognition.codeSymbolsMode,
            customWords: preferences.recognition.customWords,
            keepLineBreaks: keepLineBreaks
        )
    }

    private func remember(_ selection: CaptureSelection) {
        let rect = selection.globalRect
        let area = StoredArea(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height, displayID: selection.displayID)
        guard let data = try? JSONEncoder().encode(area) else { return }
        UserDefaults.standard.set(data, forKey: "capture.lastArea")
    }

    private func clearCollectionAfterPaste() {
        guard preferences.general.clearAfterPaste else { return }
        let pasteboardChangeCount = NSPasteboard.general.changeCount
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled, let self else { return }
            guard NSPasteboard.general.changeCount == pasteboardChangeCount else { return }
            self.collection.clear()
        }
    }

    private func showPermissionAlert(title: String, message: String, settingsPane: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: AppText.localized("Open System Settings"))
        alert.addButton(withTitle: AppText.localized("Later"))
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(settingsPane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
