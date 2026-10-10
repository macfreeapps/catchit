import AppKit
import AVFoundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var general: GeneralPreferences
    @ObservedObject private var recognition: RecognitionPreferences
    @ObservedObject private var speech: SpeechPreferences
    @ObservedObject private var shortcuts: ShortcutPreferences
    @State private var availableLanguages = TextRecognizer.supportedLanguages().sorted()
    private struct WordDraft: Identifiable, Equatable {
        let id = UUID()
        var text: String
    }
    @State private var customWords: [WordDraft]
    @FocusState private var focusedWord: UUID?
    @State private var pendingWordFocus: UUID?

    init(model: AppModel) {
        self.model = model
        general = model.preferences.general
        recognition = model.preferences.recognition
        speech = model.preferences.speech
        shortcuts = model.preferences.shortcuts
        _customWords = State(initialValue: model.preferences.recognition.customWords.map { WordDraft(text: $0) })
    }

    var body: some View {
        TabView {
            generalSettings.tabItem { Label("General", systemImage: "slider.horizontal.3") }
            recognitionSettings.tabItem { Label("Text", systemImage: "text.viewfinder") }
            clipboardSettings.tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
            shortcutSettings.tabItem { Label("Shortcuts", systemImage: "keyboard") }
            speechSettings.tabItem { Label("Speech", systemImage: "waveform") }
            aboutSettings.tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(20)
        .preferredColorScheme(general.appearanceMode == "light" ? .light : general.appearanceMode == "dark" ? .dark : nil)
        .onChange(of: customWords) { _, words in
            recognition.customWords = words.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    private var generalSettings: some View {
        Form {
            Section("Capture") {
                Toggle("Show capture results", isOn: $general.showHUD)
                Toggle("Play a sound after a successful capture", isOn: $general.captureSound)
            }
            Section("System") {
                Toggle("Launch Catch It at login", isOn: Binding(get: { general.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                Picker("Appearance", selection: $general.appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var clipboardSettings: some View {
        Form {
            Section("Clipboard collection") {
                Toggle("Add new captures to a collection", isOn: $general.additiveMode)
                Picker("Separator", selection: $general.collectionSeparator) {
                    Text("New line").tag("\n")
                    Text("Blank line").tag("\n\n")
                    Text("Space").tag(" ")
                }
                .disabled(!general.additiveMode)
            }
            Section("Privacy") {
                Toggle("Save capture history", isOn: $general.showHistory)
                Toggle("Clear collection after I paste", isOn: Binding(get: { general.clearAfterPaste }, set: { model.setClearAfterPaste($0) }))
                Text("Auto-clear watches for Command–V and requires Accessibility access. Catch It asks for this permission only when you turn this option on.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if general.showHistory {
                    HStack {
                        Button("Open History…") { model.showHistory() }
                        Button("Clear History") { model.history.clear() }
                    }
                }
            }
            Section("Links") {
                Toggle("Open detected links automatically", isOn: $general.openLinksAutomatically)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var recognitionSettings: some View {
        Form {
            Section("Text format") {
                Picker("Copy text as", selection: $general.keepLineBreaks) {
                    Text("Original rows").tag(true)
                    Text("One line").tag(false)
                }
                .pickerStyle(.segmented)
                Text(general.keepLineBreaks
                     ? LocalizedStringKey("Preserves recognized rows and paragraph breaks. Copies plain text, without fonts or colors.")
                     : LocalizedStringKey("Joins all rows and paragraphs into one line and repairs words split by a line-end hyphen."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Language") {
                Picker("Primary language (auto-detect off)", selection: $recognition.primaryLanguage) {
                    ForEach(languageChoices, id: \.self) { language in
                        Text(Locale.current.localizedString(forIdentifier: language) ?? language).tag(language)
                    }
                }
                Toggle("Automatically detect language", isOn: $recognition.automaticallyDetectsLanguage)
                Text("Vertical Chinese, Japanese, and Korean text is recognized when the matching primary language is selected.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Recognition behavior") {
                Toggle("Code / symbols mode", isOn: $recognition.codeSymbolsMode)
                Text("Turns off language correction to help preserve source code, URLs, and identifiers.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section {
                DisclosureGroup("Custom Words") {
                    customWordsSettings
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .task {
            availableLanguages = TextRecognizer.supportedLanguages().sorted()
            if !availableLanguages.contains(recognition.primaryLanguage) {
                recognition.primaryLanguage = TextRecognizer.preferredSupportedLanguage(recognition.primaryLanguage, supported: availableLanguages)
            }
        }
    }

    private var customWordsSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add names and specialist terms that Apple Vision should prefer during recognition.")
                .foregroundStyle(.secondary)
            List {
                ForEach(customWords) { word in
                    let index = customWords.firstIndex(where: { $0.id == word.id }) ?? 0
                    HStack {
                        TextField("Custom word", text: wordBinding(for: word.id))
                            .accessibilityLabel(AppText.formatted("Custom word %lld", index + 1))
                            .focused($focusedWord, equals: word.id)
                            .onAppear {
                                if pendingWordFocus == word.id {
                                    focusedWord = word.id
                                    pendingWordFocus = nil
                                }
                            }
                        Button {
                            focusedWord = nil
                            customWords.removeAll { $0.id == word.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(AppText.formatted("Remove custom word %lld", index + 1))
                        .help("Remove word")
                    }
                }
                .onDelete { offsets in customWords.remove(atOffsets: offsets) }
            }
            .frame(height: 160)
            HStack {
                Button {
                    let word = WordDraft(text: "")
                    pendingWordFocus = word.id
                    customWords.append(word)
                } label: {
                    Label("Add Word", systemImage: "plus")
                }
                .accessibilityHint("Adds a new custom recognition word")
                Spacer()
                Text(AppText.formatted("%lld words", recognition.customWords.count))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .padding(.top, 8)
    }

    private var shortcutSettings: some View {
        Form {
            Toggle("Enable global shortcuts", isOn: $shortcuts.enabled)
            Section("Capture shortcut") {
                shortcutRow(.catchText)
                Text("Start selecting screen text from any app. Click the shortcut field and press your preferred key combination.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .disabled(!shortcuts.enabled)
            Section {
                DisclosureGroup("More shortcuts") {
                    ForEach(HotKeyAction.allCases.filter { $0 != .catchText }, id: \.self) { action in
                        shortcutRow(action)
                    }
                }
            }
            .disabled(!shortcuts.enabled)
            Text("Select a shortcut, then press a modifier and a key. Press Escape to cancel. Control–Option combinations are the defaults.")
                .font(.callout)
                .foregroundStyle(.secondary)
            if hasDuplicateShortcuts {
                Text("Each action needs its own shortcut. Resolve duplicates before using the conflicting actions.")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var speechSettings: some View {
        Form {
            Toggle("Read text after capture", isOn: $speech.readAfterCapture)
            Picker("Voice", selection: $speech.voiceIdentifier) {
                Text("System default").tag("")
                ForEach(voiceChoices, id: \.identifier) { voice in
                    Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                }
            }
            .accessibilityLabel("Speech voice")
            VStack(alignment: .leading, spacing: 5) {
                Slider(value: $speech.rate, in: 0...1)
                    .accessibilityLabel("Speech rate")
                HStack {
                    Text("Slower")
                    Spacer()
                    Text("Faster")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Button("Stop Speaking") { model.stopSpeaking() }
                .disabled(!model.isSpeaking)
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var aboutSettings: some View {
        ScrollView {
            VStack(spacing: 16) {
                CatchItMenuBarMark().frame(width: 56, height: 56).accessibilityHidden(true)
                VStack(spacing: 6) {
                    Text("Catch It").font(.title.weight(.semibold))
                    Text(AppText.formatted("Version %@", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"))
                        .foregroundStyle(.secondary)
                    Text("Made by @tarudesu").font(.headline)
                }
                Text("Select a part of your screen and copy its text or barcode contents. Recognition runs locally on this Mac with Apple Vision.")
                    .multilineTextAlignment(.center)
                Text("No network access, analytics, or telemetry. Screen images are processed in memory and discarded.")
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Divider()
                Text("Interface language follows macOS; English and Vietnamese are available.")
                    .font(.callout).foregroundStyle(.secondary)
                DisclosureGroup("Credits and licenses") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Runtime frameworks: SwiftUI, AppKit, Carbon, ScreenCaptureKit, Vision, PDFKit, AVFoundation, ServiceManagement.")
                        Text("Third-party runtime packages: none. XcodeGen (MIT) is optional and used only to regenerate the Xcode project.")
                    }
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .accessibilityElement(children: .contain)
    }

    private func shortcutRow(_ action: HotKeyAction) -> some View {
        HStack {
            Text(action.title)
            Spacer()
            HotKeyRecorder(binding: binding(for: action), actionName: action.title)
                .frame(width: 170, height: 30)
        }
    }

    private var languageChoices: [String] {
        availableLanguages
    }

    private var voiceChoices: [AVSpeechSynthesisVoice] {
        let voices = SpeechController.availableVoices
        let languagePrefix = recognition.primaryLanguage.split(separator: "-").first.map(String.init)?.lowercased() ?? ""
        let matching = voices.filter { $0.language.lowercased().hasPrefix(languagePrefix) }
        var choices = matching.isEmpty ? voices : matching
        if let selected = voices.first(where: { $0.identifier == speech.voiceIdentifier }), !choices.contains(where: { $0.identifier == selected.identifier }) {
            choices.append(selected)
        }
        return choices
    }

    private var hasDuplicateShortcuts: Bool {
        let values = Array(shortcuts.bindings.values)
        return Set(values).count < values.count
    }

    private func wordBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { customWords.first(where: { $0.id == id })?.text ?? "" },
            set: { text in
                guard let index = customWords.firstIndex(where: { $0.id == id }) else { return }
                customWords[index].text = text
            }
        )
    }

    private func binding(for action: HotKeyAction) -> Binding<HotKeyBinding> {
        Binding(
            get: { shortcuts.bindings[action] ?? HotKeyBinding.defaults[action] ?? HotKeyBinding(keyCode: 49, modifiers: 6144) },
            set: { shortcuts.bindings[action] = $0 }
        )
    }
}

private struct HotKeyRecorder: NSViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var binding: HotKeyBinding
    var actionName: String

    func makeNSView(context: Context) -> HotKeyRecorderView {
        let view = HotKeyRecorderView()
        view.onChange = { binding = $0 }
        view.binding = binding
        view.actionName = actionName
        view.isEnabled = isEnabled
        return view
    }

    func updateNSView(_ view: HotKeyRecorderView, context: Context) {
        view.binding = binding
        view.actionName = actionName
        view.isEnabled = isEnabled
        view.onChange = { binding = $0 }
    }
}

private final class HotKeyRecorderView: NSView {
    var binding = HotKeyBinding(keyCode: 49, modifiers: 6144) { didSet { needsDisplay = true } }
    var onChange: ((HotKeyBinding) -> Void)?
    var actionName = ""
    var isEnabled = true {
        didSet {
            if !isEnabled { isRecording = false }
            needsDisplay = true
        }
    }
    private var isRecording = false

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        window?.makeFirstResponder(self)
        isRecording.toggle()
        needsDisplay = true
        return true
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return true
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let fill = isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.16) : NSColor.controlBackgroundColor
        fill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        border.lineWidth = 1
        border.stroke()
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 6, yRadius: 6)
            focus.lineWidth = 3
            focus.stroke()
        }
        let text = isRecording ? AppText.localized("Type a shortcut…") : binding.displayName
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: isEnabled ? NSColor.labelColor : NSColor.disabledControlTextColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        window?.makeFirstResponder(self)
        isRecording.toggle()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { super.keyDown(with: event); return }
        guard isRecording else {
            if event.keyCode == 36 || event.keyCode == 49 {
                _ = accessibilityPerformPress()
            } else {
                super.keyDown(with: event)
            }
            return
        }
        if event.keyCode == 53 {
            isRecording = false
            needsDisplay = true
            return
        }
        guard let binding = HotKeyBinding.from(event: event) else { NSSound.beep(); return }
        self.binding = binding
        isRecording = false
        needsDisplay = true
        onChange?(binding)
    }

    override func isAccessibilityEnabled() -> Bool { isEnabled }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { AppText.formatted("%@: %@", actionName, isRecording ? AppText.localized("Type a shortcut…") : binding.displayName) }
    override func accessibilityHelp() -> String? { AppText.localized("Press to record a shortcut, then type a modifier and key. Escape cancels.") }
}
