import Combine
import Foundation
import os

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let text: String

    init(date: Date = Date(), text: String) {
        id = UUID()
        self.date = date
        self.text = text
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    private let logger = Logger(subsystem: "com.tarudesu.CatchIt", category: "History")
    private let fileURL: URL
    private let limit: Int

    init(limit: Int = 100) {
        self.limit = limit
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("Catch It", isDirectory: true)
        fileURL = directory.appendingPathComponent("history.json")
        load()
    }

    func append(_ text: String) {
        guard !text.isEmpty else { return }
        entries.insert(HistoryEntry(text: text), at: 0)
        if entries.count > limit { entries = Array(entries.prefix(limit)) }
        save()
    }

    func clear() {
        entries = []
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            logger.error("Could not clear capture history: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            logger.error("Could not read saved capture history")
            return
        }
        entries = Array(decoded.prefix(limit))
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Could not save capture history: \(error.localizedDescription, privacy: .public)")
        }
    }
}
