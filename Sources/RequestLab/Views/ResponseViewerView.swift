import AppKit
import RequestLabCore
import SwiftUI

struct ResponseViewerView: View {
    let response: APIExecutionResult

    @State private var selectedTab: ResponseViewerTab = .pretty

    private let jsonFormatter = JSONFormattingService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Picker("Response view", selection: $selectedTab) {
                    ForEach(ResponseViewerTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 300)

                Spacer(minLength: 8)

                Button("Copy", systemImage: "doc.on.doc") {
                    copyToPasteboard(copyText)
                }
                .buttonStyle(.borderless)
                .help("Copy the selected response view")
            }

            viewerContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .workbenchSurface(.elevated, cornerRadius: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var viewerContent: some View {
        switch selectedTab {
        case .pretty:
            responseText(prettyBodyText)
        case .raw:
            responseText(rawBodyText)
        case .headers:
            responseText(headersText)
        }
    }

    private func responseText(_ value: String) -> some View {
        ScrollView {
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    private var prettyBodyText: String {
        response.body.isEmpty ? "Empty response body" : jsonFormatter.prettyPrintedIfJSON(response.body)
    }

    private var rawBodyText: String {
        response.body.isEmpty ? "Empty response body" : response.body
    }

    private var headersText: String {
        if response.headers.isEmpty {
            return "No response headers"
        }

        return response.headers
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    private var copyText: String {
        switch selectedTab {
        case .pretty:
            prettyBodyText
        case .raw:
            rawBodyText
        case .headers:
            headersText
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private enum ResponseViewerTab: CaseIterable, Identifiable {
    case pretty
    case raw
    case headers

    var id: Self { self }

    var title: String {
        switch self {
        case .pretty:
            "Pretty"
        case .raw:
            "Raw"
        case .headers:
            "Headers"
        }
    }
}
