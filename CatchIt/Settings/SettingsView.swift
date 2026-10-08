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
            recognitionSettings.tabItem { Label("Recognition", systemImage: "text.viewfinder") }
            customWordsSettings.tabItem { Label("Custom Words", systemImage: "text.badge.plus") }
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
                Toggle("Keep line breaks", isOn: $general.keepLineBreaks)
                    .help("When off, lines are joined into paragraphs and line-end hyphenation is corrected.")
                Toggle("Open detected links automatically", isOn: $general.openLinksAutomatically)
            }
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

    private var recognitionSettings: some View {
        Form {
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
            Section("Shortcuts") {
                ForEach(HotKeyAction.allCases, id: \.self) { action in
                    HStack {
                        Text(action.title)
                        Spacer()
                        HotKeyRecorder(binding: binding(for: action), actionName: action.title)
                            .frame(width: 170, height: 30)
                    }
                }
            }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CatchItMenuBarMark().frame(width: 28, height: 28).accessibilityHidden(true)
                Text("Catch It").font(.title2.weight(.semibold))
            }
            Text("Select a part of your screen and copy its text or barcode contents. Recognition runs locally on this Mac with Apple Vision.")
                .foregroundStyle(.secondary)
            Text("Interface language follows macOS; English and Vietnamese are available.")
                .font(.callout)
            Text("No network access, analytics, or telemetry. Screen images are processed in memory and discarded.")
                .font(.callout)
            Divider()
            Text("Runtime frameworks: SwiftUI, AppKit, Carbon, ScreenCaptureKit, Vision, PDFKit, AVFoundation, ServiceManagement.")
                .font(.callout)
            Text("Third-party runtime packages: none. XcodeGen (MIT) is optional and used only to regenerate the Xcode project.")
                .font(.callout)
            Spacer()
            Text(AppText.formatted("Version %@", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"))
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
        .accessibilityElement(children: .contain)
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
    @Binding var binding: HotKeyBinding
    var actionName: String

    func makeNSView(context: Context) -> HotKeyRecorderView {
        let view = HotKeyRecorderView()
        view.onChange = { binding = $0 }
        view.binding = binding
        view.actionName = actionName
        return view
    }

    func updateNSView(_ view: HotKeyRecorderView, context: Context) {
        view.binding = binding
        view.actionName = actionName
        view.onChange = { binding = $0 }
    }
}

private final class HotKeyRecorderView: NSView {
    var binding = HotKeyBinding(keyCode: 49, modifiers: 6144) { didSet { needsDisplay = true } }
    var onChange: ((HotKeyBinding) -> Void)?
    var actionName = ""
    private var isRecording = false

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityPerformPress() -> Bool {
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
            .foregroundColor: NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording.toggle()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
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

    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { AppText.formatted("%@: %@", actionName, isRecording ? AppText.localized("Type a shortcut…") : binding.displayName) }
    override func accessibilityHelp() -> String? { AppText.localized("Press to record a shortcut, then type a modifier and key. Escape cancels.") }
}
