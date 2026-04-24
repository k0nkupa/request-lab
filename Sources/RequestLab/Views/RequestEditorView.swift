import RequestLabCore
import SwiftUI

struct RequestEditorView: View {
    let request: APIRequest?
    @State private var selectedTab = RequestEditorTab.params

    var body: some View {
        VStack(spacing: 0) {
            requestBar
                .padding()

            Divider()

            TabView(selection: $selectedTab) {
                keyValueTable(title: "Query parameters", values: request?.params ?? [:])
                    .tabItem { Text("Params") }
                    .tag(RequestEditorTab.params)

                keyValueTable(title: "Headers", values: request?.headers ?? [:])
                    .tabItem { Text("Headers") }
                    .tag(RequestEditorTab.headers)

                authView
                    .tabItem { Text("Auth") }
                    .tag(RequestEditorTab.auth)

                bodyView
                    .tabItem { Text("Body") }
                    .tag(RequestEditorTab.body)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            responsePlaceholder
        }
    }

    private var requestBar: some View {
        HStack(spacing: 8) {
            Picker("Method", selection: .constant(request?.method ?? .get)) {
                ForEach(HTTPMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            TextField("Request URL", text: .constant(request?.url ?? ""))
                .textFieldStyle(.roundedBorder)

            Button("Send", systemImage: "paperplane") {}
        }
    }

    private var authView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Authentication")
                .font(.headline)

            if let auth = request?.auth {
                LabeledContent("Type", value: auth.type.rawValue)

                if let tokenVariable = auth.tokenVariable {
                    LabeledContent("Token variable", value: tokenVariable)
                }

                if let usernameVariable = auth.usernameVariable {
                    LabeledContent("Username variable", value: usernameVariable)
                }

                if let keyName = auth.keyName {
                    LabeledContent("Key name", value: keyName)
                }
            } else {
                ContentUnavailableView("No auth configured", systemImage: "lock.open")
            }

            Spacer()
        }
        .padding(.vertical)
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Body")
                .font(.headline)

            Text(bodyDescription)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(.vertical)
    }

    private var bodyDescription: String {
        switch request?.body {
        case .some(.none), nil:
            return "No request body"
        case .raw(let value), .json(let value):
            return value
        case .form(let fields):
            return fields
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "\n")
        }
    }

    private var responsePlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response")
                .font(.headline)

            ContentUnavailableView(
                "No response yet",
                systemImage: "tray",
                description: Text("Request execution lands in a later task.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(minHeight: 220)
    }

    private func keyValueTable(title: String, values: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if values.isEmpty {
                ContentUnavailableView("No values", systemImage: "list.bullet.rectangle")
            } else {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    ForEach(values.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        GridRow {
                            Text(key)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Text(value)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical)
    }
}

private enum RequestEditorTab {
    case params
    case headers
    case auth
    case body
}
