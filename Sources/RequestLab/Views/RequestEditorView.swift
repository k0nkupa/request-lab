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
            HStack(spacing: 10) {
                Image(systemName: request?.kind == .graphQL ? "curlybraces" : "doc.text")
                    .foregroundStyle(request?.kind == .graphQL ? RequestLabTheme.graphQL : RequestLabTheme.selection)
                    .help(request?.kind == .graphQL ? "GraphQL request" : "HTTP request")

                Text(store.editorTitle)
                    .font(.title.bold())
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)

            requestBar
                .padding()
                .requestLabSurface(tint: request?.kind == .graphQL ? RequestLabTheme.graphQL : RequestLabTheme.selection)
                .padding(.horizontal)
                .padding(.bottom, 12)

            Divider()

            requestTabPanel
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            responsePanel
                .padding([.horizontal, .top, .bottom])
        }
    }

    private var requestBar: some View {
        HStack(spacing: 8) {
            Picker("Type", selection: requestKindBinding) {
                ForEach(APIRequestKind.allCases, id: \.self) { kind in
                    Label(kind.displayName, systemImage: kind.systemImage)
                        .tag(kind)
                }
            }
            .labelsHidden()
            .labelStyle(.titleAndIcon)
            .frame(width: 145)

            Picker("Method", selection: requestMethodBinding) {
                ForEach(HTTPMethod.allCases, id: \.self) { method in
                    methodBadge(method)
                        .tag(method)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            VariableTokenTextField("Request URL", text: requestURLBinding)

            Button("Send", systemImage: "paperplane.fill") {
                Task {
                    await store.sendSelectedRequest()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(RequestLabTheme.primaryAction)
            .disabled(request == nil || store.isSending)
        }
    }

    private var requestTabPanel: some View {
        VStack(spacing: 18) {
            Picker("Request editor section", selection: $selectedTab) {
                Text("Params").tag(RequestEditorTab.params)
                Text("Headers").tag(RequestEditorTab.headers)
                Text("Auth").tag(RequestEditorTab.auth)
                Text("Body").tag(RequestEditorTab.body)
                Text("GraphQL").tag(RequestEditorTab.graphQL)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 430)

            requestTabContent
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(RequestLabTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(RequestLabTheme.editorBorder, lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var requestTabContent: some View {
        switch selectedTab {
        case .params:
            KeyValueTableEditor(
                title: "Query parameters",
                emptyTitle: "No query parameters",
                emptyDescription: "Add a key and value to append query parameters to this request.",
                values: binding(
                    get: { request?.params ?? [:] },
                    set: { params in
                        store.updateSelectedRequest { $0.params = params }
                    }
                )
            )
        case .headers:
            KeyValueTableEditor(
                title: "Headers",
                emptyTitle: "No headers",
                emptyDescription: "Add request headers such as Accept, Content-Type, or X-Trace.",
                values: binding(
                    get: { request?.headers ?? [:] },
                    set: { headers in
                        store.updateSelectedRequest { $0.headers = headers }
                    }
                )
            )
        case .auth:
            authView
        case .body:
            bodyView
        case .graphQL:
            graphQLView
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
    }

    private var graphQLView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GraphQL")
                .font(.headline)

            if request?.kind == .graphQL {
                VariableTokenTextField("Operation name", text: graphQLOperationNameBinding)
                    .padding(.top, 6)

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
                KeyValueTableEditor(
                    title: "Form fields",
                    emptyTitle: "No form fields",
                    emptyDescription: "Add form fields to send an application/x-www-form-urlencoded body.",
                    values: formBodyBinding
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: bodyTextBinding)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .background(RequestLabTheme.elevatedSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(RequestLabTheme.editorBorder, lineWidth: 1)
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
    }

    private var responsePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Response")
                    .font(.headline)

                Spacer()

                if let response = store.latestResponse {
                    responseStatusBadge(response)
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
        .requestLabSurface(
            tint: store.latestResponse.map { RequestLabTheme.responseColor(statusCode: $0.statusCode) } ?? RequestLabTheme.info,
            cornerRadius: 12
        )
        .frame(minHeight: 220)
    }

    private func methodBadge(_ method: HTTPMethod) -> some View {
        let color = RequestLabTheme.methodColor(method)

        return Text(method.rawValue)
            .font(.caption.bold())
            .monospaced()
            .foregroundStyle(RequestLabTheme.badgeForeground(for: color))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(RequestLabTheme.softFill(color))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(RequestLabTheme.softStroke(color), lineWidth: 1)
            }
    }

    private func responseStatusBadge(_ response: APIExecutionResult) -> some View {
        let color = RequestLabTheme.responseColor(statusCode: response.statusCode)

        return Text("\(response.statusCode) - \(response.durationMilliseconds) ms")
            .font(.caption.bold())
            .monospacedDigit()
            .foregroundStyle(RequestLabTheme.badgeForeground(for: color))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(RequestLabTheme.softFill(color))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(RequestLabTheme.softStroke(color), lineWidth: 1)
            }
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

private extension APIRequestKind {
    var displayName: String {
        switch self {
        case .rest:
            "REST"
        case .graphQL:
            "GraphQL"
        }
    }

    var systemImage: String {
        switch self {
        case .rest:
            "arrow.left.arrow.right"
        case .graphQL:
            "curlybraces"
        }
    }
}
