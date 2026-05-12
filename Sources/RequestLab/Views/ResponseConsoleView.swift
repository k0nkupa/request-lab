import RequestLabCore
import SwiftUI

struct ResponseConsoleView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: RequestLabSpacing.md) {
            header

            if store.isSending {
                sendingContent
            } else if let errorMessage = store.executionErrorMessage {
                failureContent(errorMessage)
            } else if let response = store.latestResponse {
                responseSummary(response)
                ResponseViewerView(response: response)
            } else {
                emptyContent
            }
        }
        .padding(RequestLabSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RequestLabTheme.surface)
    }

    private var header: some View {
        HStack(spacing: RequestLabSpacing.sm) {
            Label("Response Console", systemImage: "terminal")
                .font(RequestLabTextStyle.paneTitle)
                .symbolRenderingMode(.hierarchical)

            Spacer(minLength: RequestLabSpacing.md)
        }
    }

    private var sendingContent: some View {
        HStack(spacing: RequestLabSpacing.sm) {
            ProgressView()
                .controlSize(.small)

            Text("Sending")
                .font(RequestLabTextStyle.rowLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func responseSummary(_ response: APIExecutionResult) -> some View {
        HStack(spacing: RequestLabSpacing.sm) {
            responseBadge("\(response.statusCode)", color: RequestLabTheme.responseColor(statusCode: response.statusCode))
            responseBadge(response.method.rawValue, color: RequestLabTheme.methodColor(response.method))
            responseBadge("\(response.durationMilliseconds) ms", color: RequestLabTheme.info)
            responseBadge(formatByteCount(response.bodySizeBytes), color: RequestLabTheme.selection)
            responseBadge(contentTypeLabel(for: response), color: RequestLabTheme.info)

            Spacer(minLength: RequestLabSpacing.sm)
        }
    }

    private func responseBadge(_ value: String, color: Color) -> some View {
        Text(value)
            .font(RequestLabTextStyle.sectionLabel)
            .monospacedDigit()
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(RequestLabTheme.badgeForeground(for: color))
            .padding(.horizontal, RequestLabSpacing.sm)
            .padding(.vertical, RequestLabSpacing.xs)
            .frame(maxWidth: 180)
            .background(
                Capsule(style: .continuous)
                    .fill(RequestLabTheme.softFill(color))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(RequestLabTheme.softStroke(color), lineWidth: 1)
            }
    }

    private func failureContent(_ message: String) -> some View {
        ContentUnavailableView(
            "Request failed",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .workbenchSurface(.elevated, cornerRadius: 8, tint: RequestLabTheme.error)
    }

    private var emptyContent: some View {
        ContentUnavailableView(
            "No response yet",
            systemImage: "terminal",
            description: Text("Send a request to inspect the response.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .workbenchSurface(.elevated, cornerRadius: 8)
    }

    private func formatByteCount(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func contentTypeLabel(for response: APIExecutionResult) -> String {
        guard let contentType = response.contentType, !contentType.isEmpty else {
            return "Unknown type"
        }

        return contentType
    }
}
