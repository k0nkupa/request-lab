import RequestLabCore
import SwiftUI

struct HistoryNavigatorView: View {
    @Bindable var store: AppStore
    let searchText: String

    var body: some View {
        List(selection: selection) {
            if store.workspace.history.isEmpty {
                emptyState
            } else if filteredHistory.isEmpty {
                ContentUnavailableView.search
            } else {
                ForEach(filteredHistory) { entry in
                    historyRow(entry)
                        .tag(CenterPaneSelection.history(entry.id))
                        .contextMenu {
                            Button("Open Request") {
                                _ = store.openRequestFromHistory(id: entry.id)
                            }
                            .disabled(store.workspace.request(id: entry.requestId) == nil)

                            Button("Re-run") {
                                Task {
                                    await store.rerunHistoryEntry(id: entry.id)
                                }
                            }
                            .disabled(store.workspace.request(id: entry.requestId) == nil || store.isSending)
                        }
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var emptyState: some View {
        if normalizedSearchText.isEmpty {
            ContentUnavailableView(
                "No history",
                systemImage: "clock",
                description: Text("Responses will appear here after requests run.")
            )
        } else {
            ContentUnavailableView.search
        }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredHistory: [APIHistoryEntry] {
        guard !normalizedSearchText.isEmpty else {
            return store.workspace.history
        }

        return store.workspace.history.filter { entry in
            matchesSearch(entry.url)
                || matchesSearch(entry.requestName ?? "")
                || matchesSearch(entry.method.rawValue)
                || entry.statusCode.map { matchesSearch("\($0)") } == true
        }
    }

    private func historyRow(_ entry: APIHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(store.selectedCenterPane == .history(entry.id) ? RequestLabTheme.selection : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.requestName ?? entry.url)
                    .fontWeight(store.selectedCenterPane == .history(entry.id) ? .semibold : .regular)
                    .lineLimit(1)

                if entry.requestName != nil {
                    Text(entry.url)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(entry.method.rawValue)
                        .fontWeight(.semibold)
                        .foregroundStyle(RequestLabTheme.methodColor(entry.method))

                    if let statusCode = entry.statusCode {
                        Text("\(statusCode)")
                            .foregroundStyle(RequestLabTheme.responseColor(statusCode: statusCode))
                    }

                    if let durationMilliseconds = entry.durationMilliseconds {
                        Text("\(durationMilliseconds) ms")
                    }

                    if let responseSizeBytes = entry.responseSizeBytes {
                        Text(formatByteCount(responseSizeBytes))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }

    private func matchesSearch(_ value: String) -> Bool {
        value.localizedCaseInsensitiveContains(normalizedSearchText)
    }

    private func formatByteCount(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private var selection: Binding<CenterPaneSelection?> {
        Binding(
            get: { store.selectedCenterPane },
            set: { store.selectCenterPane($0) }
        )
    }
}
