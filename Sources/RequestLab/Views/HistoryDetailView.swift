import AppKit
import RequestLabCore
import SwiftUI

struct HistoryDetailView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let entry = store.selectedHistoryEntry {
                historyContent(entry)
            } else {
                ContentUnavailableView(
                    "No history entry selected",
                    systemImage: "clock",
                    description: Text("Select a run from history to inspect it.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func historyContent(_ entry: APIHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .foregroundStyle(RequestLabTheme.selection)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.requestName ?? "History Entry")
                        .font(.title.bold())
                        .lineLimit(1)

                    Text(entry.url)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }

                Spacer()
            }

            actionBar(entry)

            detailGrid(entry)
                .padding(18)
                .requestLabSurface(tint: RequestLabTheme.selection)

            if store.workspace.request(id: entry.requestId) == nil {
                ContentUnavailableView(
                    "Original request unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This history entry is still available, but its request was deleted or is not in this workspace.")
                )
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
    }

    private func actionBar(_ entry: APIHistoryEntry) -> some View {
        HStack(spacing: 10) {
            Button("Open Request", systemImage: "arrow.up.right.square") {
                _ = store.openRequestFromHistory(id: entry.id)
            }
            .disabled(store.workspace.request(id: entry.requestId) == nil)

            Button("Re-run", systemImage: "paperplane") {
                Task {
                    await store.rerunHistoryEntry(id: entry.id)
                }
            }
            .disabled(store.workspace.request(id: entry.requestId) == nil || store.isSending)

            Button("Copy URL", systemImage: "doc.on.doc") {
                copyToPasteboard(entry.url)
            }

            Spacer()

            if store.isSending {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func detailGrid(_ entry: APIHistoryEntry) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
            detailRow("Method", entry.method.rawValue)
            detailRow("URL", entry.url)
            detailRow("Request", entry.requestName ?? "Unknown")
            detailRow("Status", entry.statusCode.map(String.init) ?? "Unknown")
            detailRow("Duration", entry.durationMilliseconds.map { "\($0) ms" } ?? "Unknown")
            detailRow("Timestamp", formattedTimestamp(entry.createdAt))
            detailRow("Size", entry.responseSizeBytes.map(formatByteCount) ?? "Unknown")
            detailRow("Content Type", entry.contentType ?? "Unknown")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .textSelection(.enabled)
                .lineLimit(title == "URL" ? 3 : 1)
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        guard date.timeIntervalSince1970 > 0 else {
            return "Unknown"
        }

        return date.formatted(date: .abbreviated, time: .standard)
    }

    private func formatByteCount(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
