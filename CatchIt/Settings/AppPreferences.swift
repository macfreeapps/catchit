import Combine
import Foundation

@MainActor
final class AppPreferences {
    let general = GeneralPreferences()
    let recognition = RecognitionPreferences()
    let speech = SpeechPreferences()
    let shortcuts = ShortcutPreferences()
}

@MainActor
final class ShortcutPreferences: ObservableObject {
    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "shortcuts.enabled") }
    }
    @Published var bindings: [HotKeyAction: HotKeyBinding] {
        didSet {
            guard let data = try? JSONEncoder().encode(bindings) else { return }
            defaults.set(data, forKey: "shortcuts.bindings")
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.object(forKey: "shortcuts.enabled") as? Bool ?? true
        if let data = defaults.data(forKey: "shortcuts.bindings"),
           let decoded = try? JSONDecoder().decode([HotKeyAction: HotKeyBinding].self, from: data) {
            bindings = HotKeyBinding.defaults.merging(decoded) { _, updated in updated }
        } else {
            bindings = HotKeyBinding.defaults
        }
    }
}

@MainActor
final class GeneralPreferences: ObservableObject {
    @Published var showHUD: Bool {
        didSet { defaults.set(showHUD, forKey: "general.showHUD") }
    }
    @Published var captureSound: Bool {
        didSet { defaults.set(captureSound, forKey: "general.captureSound") }
    }
    @Published var keepLineBreaks: Bool {
        didSet { defaults.set(keepLineBreaks, forKey: "general.keepLineBreaks") }
    }
    @Published var additiveMode: Bool {
        didSet { defaults.set(additiveMode, forKey: "general.additiveMode") }
    }
    @Published var collectionSeparator: String {
        didSet { defaults.set(collectionSeparator, forKey: "general.collectionSeparator") }
    }
    @Published var showHistory: Bool {
        didSet { defaults.set(showHistory, forKey: "general.showHistory") }
    }
    @Published var openLinksAutomatically: Bool {
        didSet { defaults.set(openLinksAutomatically, forKey: "general.openLinksAutomatically") }
    }
    @Published var clearAfterPaste: Bool {
        didSet { defaults.set(clearAfterPaste, forKey: "general.clearAfterPaste") }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "general.launchAtLogin") }
    }
    @Published var onboardingComplete: Bool {
        didSet { defaults.set(onboardingComplete, forKey: "general.onboardingComplete") }
    }
    @Published var appearanceMode: String {
        didSet { defaults.set(appearanceMode, forKey: "general.appearanceMode") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showHUD = defaults.object(forKey: "general.showHUD") as? Bool ?? true
        captureSound = defaults.object(forKey: "general.captureSound") as? Bool ?? false
        keepLineBreaks = defaults.object(forKey: "general.keepLineBreaks") as? Bool ?? true
        additiveMode = defaults.object(forKey: "general.additiveMode") as? Bool ?? false
        collectionSeparator = defaults.string(forKey: "general.collectionSeparator") ?? "\n"
        showHistory = defaults.object(forKey: "general.showHistory") as? Bool ?? false
        openLinksAutomatically = defaults.object(forKey: "general.openLinksAutomatically") as? Bool ?? false
        clearAfterPaste = defaults.object(forKey: "general.clearAfterPaste") as? Bool ?? false
        launchAtLogin = defaults.object(forKey: "general.launchAtLogin") as? Bool ?? false
        onboardingComplete = defaults.object(forKey: "general.onboardingComplete") as? Bool ?? false
        appearanceMode = defaults.string(forKey: "general.appearanceMode") ?? "system"
    }
}

@MainActor
final class RecognitionPreferences: ObservableObject {
    @Published var primaryLanguage: String {
        didSet { defaults.set(primaryLanguage, forKey: "recognition.primaryLanguage") }
    }
    @Published var automaticallyDetectsLanguage: Bool {
        didSet { defaults.set(automaticallyDetectsLanguage, forKey: "recognition.automaticallyDetectsLanguage") }
    }
    @Published var codeSymbolsMode: Bool {
        didSet { defaults.set(codeSymbolsMode, forKey: "recognition.codeSymbolsMode") }
    }
    @Published var customWords: [String] {
        didSet { defaults.set(customWords, forKey: "recognition.customWords") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        primaryLanguage = defaults.string(forKey: "recognition.primaryLanguage") ?? Locale.preferredLanguages.first ?? "en-US"
        automaticallyDetectsLanguage = defaults.object(forKey: "recognition.automaticallyDetectsLanguage") as? Bool ?? true
        codeSymbolsMode = defaults.object(forKey: "recognition.codeSymbolsMode") as? Bool ?? false
        customWords = defaults.stringArray(forKey: "recognition.customWords") ?? []
    }
}

@MainActor
final class SpeechPreferences: ObservableObject {
    @Published var readAfterCapture: Bool {
        didSet { defaults.set(readAfterCapture, forKey: "speech.readAfterCapture") }
    }
    @Published var rate: Double {
        didSet { defaults.set(rate, forKey: "speech.rate") }
    }
    @Published var voiceIdentifier: String {
        didSet { defaults.set(voiceIdentifier, forKey: "speech.voiceIdentifier") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        readAfterCapture = defaults.object(forKey: "speech.readAfterCapture") as? Bool ?? false
        rate = defaults.object(forKey: "speech.rate") as? Double ?? 0.5
        voiceIdentifier = defaults.string(forKey: "speech.voiceIdentifier") ?? ""
    }
}
