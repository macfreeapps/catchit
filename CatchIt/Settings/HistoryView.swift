import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var history: HistoryStore
    @State private var searchText = ""

    init(model: AppModel) {
        self.model = model
        history = model.history
    }

    private var entries: [HistoryEntry] {
        guard !searchText.isEmpty else { return history.entries }
        return history.entries.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent Captures").font(.title2.weight(.semibold))
                Spacer()
                Button("Clear History") { history.clear() }
                    .disabled(history.entries.isEmpty)
            }
            .padding()
            List(entries) { entry in
                Button {
                    model.copyHistory(entry)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.text)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(entry.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppText.formatted("Copy capture: %@", String(entry.text.prefix(80))))
                .accessibilityHint("Copies this capture to the clipboard")
            }
            .searchable(text: $searchText, prompt: "Search history")
            if history.entries.isEmpty {
                ContentUnavailableView("No Saved Captures", systemImage: "text.magnifyingglass", description: Text("Turn on Save capture history in General settings to keep a local list."))
                    .padding()
            }
        }
    }
}
