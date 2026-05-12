import RequestLabCore
@preconcurrency import SwiftUI

struct RequestWorkbenchView: View {
    @Bindable var store: AppStore
    @State private var selectedSection: RequestWorkbenchSection = .params
    private let jsonFormatter = JSONFormattingService()

    private var request: APIRequest? {
        store.selectedRequest
    }

    var body: some View {
        VStack(spacing: 0) {
            workbenchHeader

            RequestCommandStrip(store: store)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RequestLabTheme.surface)

            unresolvedVariablesWarning
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider()

            VSplitView {
                builderPanel
                    .frame(minHeight: 300)

                ResponseConsoleView(store: store)
                    .frame(minHeight: 240)
            }
        }
        .background(RequestLabTheme.background)
        .onChange(of: request?.kind) {
            normalizeSelectedSection()
        }
        .onChange(of: request?.id) {
            normalizeSelectedSection()
        }
    }

    private var workbenchHeader: some View {
        HStack(spacing: 10) {
            Label {
                Text(store.editorTitle)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
            } icon: {
                Image(systemName: request?.kind == .graphQL ? "curlybraces" : "arrow.left.arrow.right")
                    .foregroundStyle(request?.kind == .graphQL ? RequestLabTheme.graphQL : RequestLabTheme.selection)
                    .symbolRenderingMode(.hierarchical)
            }

            Spacer(minLength: 12)

            Text(store.environmentPairTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(RequestLabTheme.environment)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(RequestLabTheme.softFill(RequestLabTheme.environment))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private var unresolvedVariablesWarning: some View {
        let references = store.unresolvedVariableReferences

        if !references.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Missing variables before send", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(RequestLabTheme.warning)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(references) { reference in
                        Text("\(reference.name) - \(reference.location)")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(RequestLabTheme.softFill(RequestLabTheme.warning))
                            )
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(RequestLabTheme.softStroke(RequestLabTheme.warning), lineWidth: 1)
                            }
                    }
                }
            }
            .padding(12)
            .requestLabSurface(tint: RequestLabTheme.warning)
        }
    }

    private var builderPanel: some View {
        HStack(spacing: 0) {
            RequestSectionRail(
                selectedSection: $selectedSection,
                isGraphQLRequest: request?.kind == .graphQL
            )

            Divider()

            requestSectionContent
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(RequestLabTheme.elevatedSurface.opacity(0.55))
        }
    }

    @ViewBuilder
    private var requestSectionContent: some View {
        switch selectedSection {
        case .params:
            KeyValueTableEditor(
                title: "Query parameters",
                emptyTitle: "No query parameters",
                emptyDescription: "Add a key and value to append query parameters to this request.",
                unresolvedNames: store.unresolvedVariableNames,
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
                unresolvedNames: store.unresolvedVariableNames,
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
                    unresolvedNames: store.unresolvedVariableNames,
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

    private func normalizeSelectedSection() {
        if selectedSection == .graphQL && request?.kind != .graphQL {
            selectedSection = .params
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
