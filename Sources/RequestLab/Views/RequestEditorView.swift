import RequestLabCore
@preconcurrency import SwiftUI

struct RequestEditorView: View {
    @Bindable var store: AppStore
    @State private var selectedTab = RequestEditorTab.params
    @State private var selectedResponseTab = ResponseTab.body
    private let jsonFormatter = JSONFormattingService()

    private var request: APIRequest? {
        store.selectedRequest
    }

    var body: some View {
        VStack(spacing: 0) {
            requestBar
                .padding()

            Divider()

            TabView(selection: $selectedTab) {
                keyValueEditor(
                    title: "Query parameters",
                    placeholder: "limit=50\nstatus=open",
                    values: binding(
                        get: { request?.params ?? [:] },
                        set: { params in
                            store.updateSelectedRequest { $0.params = params }
                        }
                    )
                )
                .tabItem { Text("Params") }
                .tag(RequestEditorTab.params)

                keyValueEditor(
                    title: "Headers",
                    placeholder: "Accept=application/json\nX-Trace={{traceId}}",
                    values: binding(
                        get: { request?.headers ?? [:] },
                        set: { headers in
                            store.updateSelectedRequest { $0.headers = headers }
                        }
                    )
                )
                .tabItem { Text("Headers") }
                .tag(RequestEditorTab.headers)

                authView
                    .tabItem { Text("Auth") }
                    .tag(RequestEditorTab.auth)

                bodyView
                    .tabItem { Text("Body") }
                    .tag(RequestEditorTab.body)

                graphQLView
                    .tabItem { Text("GraphQL") }
                    .tag(RequestEditorTab.graphQL)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            responsePanel
        }
    }

    private var requestBar: some View {
        HStack(spacing: 8) {
            Picker("Type", selection: requestKindBinding) {
                ForEach(APIRequestKind.allCases, id: \.self) { kind in
                    Text(kind == .graphQL ? "GraphQL" : "REST").tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 115)

            Picker("Method", selection: requestMethodBinding) {
                ForEach(HTTPMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            TextField("Request URL", text: requestURLBinding)
                .textFieldStyle(.roundedBorder)

            Button("Send", systemImage: "paperplane") {
                Task {
                    await store.sendSelectedRequest()
                }
            }
            .disabled(request == nil || store.isSending)
        }
    }

    private var authView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Authentication")
                .font(.headline)

            Picker("Type", selection: authTypeBinding) {
                ForEach(APIAuthType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            switch request?.auth?.type ?? .none {
            case .none:
                ContentUnavailableView("No auth configured", systemImage: "lock.open")
            case .bearer:
                TextField("Token variable", text: authTokenVariableBinding)
                    .textFieldStyle(.roundedBorder)
            case .basic:
                TextField("Username variable", text: authUsernameVariableBinding)
                    .textFieldStyle(.roundedBorder)

                TextField("Password variable", text: authPasswordVariableBinding)
                    .textFieldStyle(.roundedBorder)
            case .apiKey:
                TextField("Header name", text: authKeyNameBinding)
                    .textFieldStyle(.roundedBorder)

                TextField("Value variable", text: authKeyValueVariableBinding)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()
        }
        .padding(.vertical)
    }

    private var graphQLView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GraphQL")
                .font(.headline)

            if request?.kind == .graphQL {
                TextField("Operation name", text: graphQLOperationNameBinding)
                    .textFieldStyle(.roundedBorder)

                GroupBox("Query") {
                    TextEditor(text: graphQLQueryBinding)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150)
                }

                GroupBox("Variables JSON") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: graphQLVariablesBinding)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 90)

                        Button("Format JSON", systemImage: "text.alignleft") {
                            formatGraphQLVariables()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } else {
                ContentUnavailableView(
                    "REST request",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Switch the request type to GraphQL to edit query fields.")
                )
            }

            Spacer()
        }
        .padding(.vertical)
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Body")
                .font(.headline)

            Picker("Body type", selection: bodyTypeBinding) {
                ForEach(RequestBodyEditorType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .disabled(request?.kind == .graphQL)

            if request?.kind == .graphQL {
                ContentUnavailableView(
                    "GraphQL owns the body",
                    systemImage: "curlybraces",
                    description: Text("GraphQL requests send the query and variables as JSON.")
                )
            } else if bodyTypeBinding.wrappedValue == .none {
                ContentUnavailableView("No request body", systemImage: "doc")
            } else if bodyTypeBinding.wrappedValue == .form {
                keyValueEditor(
                    title: "Form fields",
                    placeholder: "email=tony@example.test\nscope=orders",
                    values: formBodyBinding
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: bodyTextBinding)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.separator, lineWidth: 1)
                        }

                    if bodyTypeBinding.wrappedValue == .json {
                        Button("Format JSON", systemImage: "text.alignleft") {
                            formatJSONBody()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical)
    }

    private var responsePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Response")
                    .font(.headline)

                Spacer()

                if let response = store.latestResponse {
                    Text("\(response.statusCode) - \(response.durationMilliseconds) ms")
                        .font(.caption)
                        .foregroundStyle(response.statusCode < 400 ? .green : .orange)
                }
            }

            if store.isSending {
                ProgressView("Sending request...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = store.executionErrorMessage {
                ContentUnavailableView(
                    "Request failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let response = store.latestResponse {
                TabView(selection: $selectedResponseTab) {
                    ScrollView {
                        Text(responseBodyText(response.body))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tabItem { Text("Body") }
                    .tag(ResponseTab.body)

                    ScrollView {
                        Text(Self.formatKeyValues(response.headers))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tabItem { Text("Headers") }
                    .tag(ResponseTab.headers)
                }
            } else {
                ContentUnavailableView(
                    "No response yet",
                    systemImage: "tray",
                    description: Text("Send a request to inspect the response.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .frame(minHeight: 220)
    }

    private func keyValueEditor(
        title: String,
        placeholder: String,
        values: Binding<[String: String]>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            TextEditor(text: keyValueTextBinding(values))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 160)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator, lineWidth: 1)
                }

            Text(placeholder)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.vertical)
    }

    private var requestKindBinding: Binding<APIRequestKind> {
        binding(
            get: { request?.kind ?? .rest },
            set: { kind in
                store.updateSelectedRequest { request in
                    request.kind = kind

                    if kind == .graphQL {
                        request.method = .post
                        request.graphQL = request.graphQL ?? APIGraphQLPayload(query: "", variables: "{}")
                        request.body = .none
                    } else {
                        request.graphQL = nil
                    }
                }
            }
        )
    }

    private var requestMethodBinding: Binding<HTTPMethod> {
        binding(
            get: { request?.method ?? .get },
            set: { method in
                store.updateSelectedRequest { $0.method = method }
            }
        )
    }

    private var requestURLBinding: Binding<String> {
        binding(
            get: { request?.url ?? "" },
            set: { url in
                store.updateSelectedRequest { $0.url = url }
            }
        )
    }

    private var authTypeBinding: Binding<APIAuthType> {
        binding(
            get: { request?.auth?.type ?? .none },
            set: { type in
                store.updateSelectedRequest { request in
                    request.auth = type == .none ? nil : APIAuth(type: type)
                }
            }
        )
    }

    private var authTokenVariableBinding: Binding<String> {
        authStringBinding(\.tokenVariable)
    }

    private var authUsernameVariableBinding: Binding<String> {
        authStringBinding(\.usernameVariable)
    }

    private var authPasswordVariableBinding: Binding<String> {
        authStringBinding(\.passwordVariable)
    }

    private var authKeyNameBinding: Binding<String> {
        authStringBinding(\.keyName)
    }

    private var authKeyValueVariableBinding: Binding<String> {
        authStringBinding(\.keyValueVariable)
    }

    private var graphQLQueryBinding: Binding<String> {
        binding(
            get: { request?.graphQL?.query ?? "" },
            set: { value in
                store.updateSelectedRequest { request in
                    var payload = request.graphQL ?? APIGraphQLPayload(query: "")
                    payload.query = value
                    request.graphQL = payload
                }
            }
        )
    }

    private var graphQLOperationNameBinding: Binding<String> {
        binding(
            get: { request?.graphQL?.operationName ?? "" },
            set: { value in
                store.updateSelectedRequest { request in
                    var payload = request.graphQL ?? APIGraphQLPayload(query: "")
                    payload.operationName = value.isEmpty ? nil : value
                    request.graphQL = payload
                }
            }
        )
    }

    private var graphQLVariablesBinding: Binding<String> {
        binding(
            get: { request?.graphQL?.variables ?? "{}" },
            set: { value in
                store.updateSelectedRequest { request in
                    var payload = request.graphQL ?? APIGraphQLPayload(query: "")
                    payload.variables = value
                    request.graphQL = payload
                }
            }
        )
    }

    private var bodyTypeBinding: Binding<RequestBodyEditorType> {
        binding(
            get: { RequestBodyEditorType(body: request?.body ?? .none) },
            set: { type in
                store.updateSelectedRequest { request in
                    request.body = type.defaultBody
                }
            }
        )
    }

    private var bodyTextBinding: Binding<String> {
        binding(
            get: {
                switch request?.body {
                case .some(.raw(let value)), .some(.json(let value)):
                    value
                case .some(.form(let fields)):
                    Self.formatKeyValues(fields)
                case .some(.none), nil:
                    ""
                }
            },
            set: { value in
                store.updateSelectedRequest { request in
                    switch request.body {
                    case .json:
                        request.body = .json(value)
                    default:
                        request.body = .raw(value)
                    }
                }
            }
        )
    }

    private var formBodyBinding: Binding<[String: String]> {
        binding(
            get: {
                guard case .form(let fields) = request?.body else {
                    return [:]
                }

                return fields
            },
            set: { fields in
                store.updateSelectedRequest { $0.body = .form(fields) }
            }
        )
    }

    private func authStringBinding(_ keyPath: WritableKeyPath<APIAuth, String?>) -> Binding<String> {
        binding(
            get: { request?.auth?[keyPath: keyPath] ?? "" },
            set: { value in
                store.updateSelectedRequest { request in
                    guard var auth = request.auth else {
                        return
                    }

                    auth[keyPath: keyPath] = value.isEmpty ? nil : value
                    request.auth = auth
                }
            }
        )
    }

    private func keyValueTextBinding(_ values: Binding<[String: String]>) -> Binding<String> {
        Binding(
            get: { Self.formatKeyValues(values.wrappedValue) },
            set: { values.wrappedValue = Self.parseKeyValues($0) }
        )
    }

    private func responseBodyText(_ body: String) -> String {
        body.isEmpty ? "Empty response body" : jsonFormatter.prettyPrintedIfJSON(body)
    }

    private func formatJSONBody() {
        do {
            let formatted = try jsonFormatter.prettyPrinted(bodyTextBinding.wrappedValue)
            bodyTextBinding.wrappedValue = formatted
        } catch {
            store.executionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func formatGraphQLVariables() {
        do {
            let formatted = try jsonFormatter.prettyPrinted(graphQLVariablesBinding.wrappedValue)
            graphQLVariablesBinding.wrappedValue = formatted
        } catch {
            store.executionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @preconcurrency private func binding<Value>(
        get: @escaping () -> Value,
        set: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { @MainActor in
                get()
            },
            set: { @MainActor value in
                set(value)
            }
        )
    }

    private static func formatKeyValues(_ values: [String: String]) -> String {
        values
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")
    }

    private static func parseKeyValues(_ text: String) -> [String: String] {
        text
            .split(whereSeparator: \.isNewline)
            .reduce(into: [:]) { values, line in
                let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard let key = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !key.isEmpty
                else {
                    return
                }

                values[key] = parts.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
    }
}

private enum RequestEditorTab {
    case params
    case headers
    case auth
    case body
    case graphQL
}

private enum ResponseTab {
    case body
    case headers
}

private enum RequestBodyEditorType: CaseIterable {
    case none
    case raw
    case json
    case form

    init(body: APIBody) {
        switch body {
        case .none:
            self = .none
        case .raw:
            self = .raw
        case .json:
            self = .json
        case .form:
            self = .form
        }
    }

    var displayName: String {
        switch self {
        case .none:
            "None"
        case .raw:
            "Raw"
        case .json:
            "JSON"
        case .form:
            "Form"
        }
    }

    var defaultBody: APIBody {
        switch self {
        case .none:
            .none
        case .raw:
            .raw("")
        case .json:
            .json("{}")
        case .form:
            .form([:])
        }
    }
}

private extension APIAuthType {
    var displayName: String {
        switch self {
        case .none:
            "None"
        case .bearer:
            "Bearer"
        case .basic:
            "Basic"
        case .apiKey:
            "API Key"
        }
    }
}
