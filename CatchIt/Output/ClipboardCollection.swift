import AppKit
import Combine
import Foundation

enum CollectionText {
    static func appending(_ value: String, to collection: String, separator: String) -> String {
        guard !collection.isEmpty else { return value }
        return collection + separator + value
    }
}

@MainActor
final class ClipboardCollection: ObservableObject {
    @Published private(set) var text: String
    @Published private(set) var canUndoClear = false
    private var undoText: String?
    private var undoDate: Date?
    private var undoExpiryTask: Task<Void, Never>?
    private var shouldRestorePasteboardOnUndo = false
    private let defaults: UserDefaults
    private let storageKey = "output.collection"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        text = defaults.string(forKey: storageKey) ?? ""
    }

    func copy(_ newText: String, additive: Bool, separator: String) {
        let result: String
        if additive {
            result = CollectionText.appending(newText, to: text, separator: separator)
        } else {
            result = newText
        }
        text = result
        defaults.set(result, forKey: storageKey)
        undoText = nil
        undoDate = nil
        shouldRestorePasteboardOnUndo = false
        canUndoClear = false
        undoExpiryTask?.cancel()
        setPasteboard(result)
    }

    func clear() {
        guard !text.isEmpty else { return }
        undoText = text
        undoDate = Date()
        shouldRestorePasteboardOnUndo = NSPasteboard.general.string(forType: .string) == text
        canUndoClear = true
        undoExpiryTask?.cancel()
        undoExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self?.undoText = nil
            self?.undoDate = nil
            self?.shouldRestorePasteboardOnUndo = false
            self?.canUndoClear = false
        }
        text = ""
        defaults.set("", forKey: storageKey)
        if shouldRestorePasteboardOnUndo {
            NSPasteboard.general.clearContents()
        }
    }

    @discardableResult
    func undoClear(now: Date = Date()) -> Bool {
        guard let previous = undoText, let clearedAt = undoDate,
              now.timeIntervalSince(clearedAt) <= 30 else {
            undoText = nil
            undoDate = nil
            shouldRestorePasteboardOnUndo = false
            canUndoClear = false
            undoExpiryTask?.cancel()
            return false
        }
        text = previous
        defaults.set(previous, forKey: storageKey)
        undoText = nil
        undoDate = nil
        canUndoClear = false
        undoExpiryTask?.cancel()
        if shouldRestorePasteboardOnUndo { setPasteboard(previous) }
        shouldRestorePasteboardOnUndo = false
        return true
    }

    private func setPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    func copyDirectly(_ value: String) {
        setPasteboard(value)
    }
}
