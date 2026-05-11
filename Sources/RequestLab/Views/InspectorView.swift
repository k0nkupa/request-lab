import RequestLabCore
import SwiftUI

struct InspectorView: View {
    @Bindable var store: AppStore

    @State private var selectedMode: InspectorMode = .details

    private var request: APIRequest? {
        store.selectedRequest
    }

    private var globalEnvironment: APIEnvironment? {
        store.selectedGlobalEnvironment
    }

    private var collectionEnvironment: APIEnvironment? {
        store.selectedCollectionEnvironment
    }

    private var response: APIExecutionResult? {
        store.latestResponse
    }

    private var errorMessage: String? {
        store.executionErrorMessage
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                modeSelector
                selectedSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var modeSelector: some View {
        Picker("Inspector mode", selection: $selectedMode) {
            ForEach(InspectorMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder
    private var selectedSection: some View {
        switch selectedMode {
        case .details:
            detailsSection
        case .variables:
            variablesSection
        case .resolved:
            resolvedSection
        case .response:
            responseSection
        }
    }

    private func inspectorSection<Content: View>(
        _ title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .requestLabSurface(tint: tint)
    }

    private var detailsSection: some View {
        inspectorSection("Details", systemImage: "doc.text", tint: RequestLabTheme.selection) {
            if let request {
                LabeledContent("Name", value: request.name)
                LabeledContent("Collection", value: store.selectedCollection?.name ?? "No collection")
                LabeledContent("Type", value: request.kind == .graphQL ? "GraphQL" : "REST")
                LabeledContent("Method", value: request.method.rawValue)
                LabeledContent("URL", value: request.url)
                LabeledContent("Headers", value: "\(request.headers.count)")
                LabeledContent("Params", value: "\(request.params.count)")
                LabeledContent("Auth", value: authSummary(for: request.auth))
                LabeledContent("Body", value: bodySummary(for: request))
            } else {
                ContentUnavailableView("No request selected", systemImage: "doc.text")
            }
        }
    }

    private var variablesSection: some View {
        inspectorSection("Variables", systemImage: "server.rack", tint: RequestLabTheme.environment) {
            LabeledContent("Global", value: globalEnvironment?.name ?? "None")
            LabeledContent("Collection", value: collectionEnvironment?.name ?? "None")

            let rows = effectiveVariableRows()

            if rows.isEmpty {
                ContentUnavailableView("No effective variables", systemImage: "server.rack")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rows) { row in
                        variableRow(row)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var resolvedSection: some View {
        inspectorSection("Resolved", systemImage: "wand.and.stars", tint: RequestLabTheme.graphQL) {
            if let request {
                switch resolvedPreview(for: request) {
                case .success(let resolved):
                    LabeledContent("URL", value: redactedSecrets(in: resolved.url.absoluteString))
                    LabeledContent("Headers", value: "\(resolved.headers.count)")
                    LabeledContent("Body", value: resolved.bodyData == nil ? "None" : "Present")
                case .failure(let error):
                    ContentUnavailableView(
                        "Unable to resolve request",
                        systemImage: "exclamationmark.triangle",
                        description: Text(redactedSecrets(in: errorMessage(for: error)))
                    )
                }
            } else {
                ContentUnavailableView("No request selected", systemImage: "doc.text")
            }
        }
    }

    private var responseSection: some View {
        inspectorSection(
            "Response",
            systemImage: "tray.full",
            tint: response.map { RequestLabTheme.responseColor(statusCode: $0.statusCode) } ?? RequestLabTheme.info
        ) {
            if store.isSending {
                ProgressView("Sending request...")
            } else if let response {
                LabeledContent("Status", value: "\(response.statusCode)")
                LabeledContent("Duration", value: "\(response.durationMilliseconds) ms")
                LabeledContent("Method", value: response.method.rawValue)
                LabeledContent("URL", value: response.url)
                LabeledContent("Headers", value: "\(response.headers.count)")
                LabeledContent("Body", value: response.body.isEmpty ? "Empty" : "Present")
            } else if let errorMessage {
                ContentUnavailableView(
                    "Request failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ContentUnavailableView(
                    "No response yet",
                    systemImage: "tray",
                    description: Text("Send a request to inspect the response.")
                )
            }
        }
    }

    private func variableRow(_ row: EffectiveVariableRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(row.variable.name, systemImage: row.variable.isSecret ? "key" : "textformat")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(row.source.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(row.source.tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(RequestLabTheme.softFill(row.source.tint))
                    )
            }

            Text(displayValue(for: row))
                .font(.caption)
                .textSelection(.enabled)
                .foregroundStyle(.primary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.45))
        )
    }

    private func displayValue(for row: EffectiveVariableRow) -> String {
        if row.variable.isSecret {
            return store.readSecretValue(environmentID: row.environmentID, variableID: row.variable.id).isEmpty
                ? "Not set"
                : "••••••"
        }

        guard let value = row.variable.value, !value.isEmpty else {
            return "Empty"
        }

        return value
    }

    private func resolvedPreview(for request: APIRequest) -> Result<ResolvedAPIRequest, Error> {
        do {
            let resolved = try VariableResolver().resolve(request, environment: effectiveEnvironmentWithSecrets())
            return .success(resolved)
        } catch {
            return .failure(error)
        }
    }

    private func effectiveEnvironmentWithSecrets() -> APIEnvironment? {
        let globalEnvironment = environmentWithSecrets(globalEnvironment)
        let collectionEnvironment = environmentWithSecrets(collectionEnvironment)

        return APIEnvironment.merged(global: globalEnvironment, collection: collectionEnvironment)
    }

    private func environmentWithSecrets(_ environment: APIEnvironment?) -> APIEnvironment? {
        guard var resolvedEnvironment = environment else {
            return nil
        }

        resolvedEnvironment.variables = resolvedEnvironment.variables.map { variable in
            guard variable.isSecret else {
                return variable
            }

            var resolvedVariable = variable
            resolvedVariable.value = store.readSecretValue(environmentID: resolvedEnvironment.id, variableID: variable.id)
            return resolvedVariable
        }

        return resolvedEnvironment
    }

    private func effectiveVariableRows() -> [EffectiveVariableRow] {
        var rows: [EffectiveVariableRow] = []
        var indexesByName: [String: Int] = [:]

        for variable in globalEnvironment?.variables ?? [] {
            indexesByName[variable.name] = rows.count
            rows.append(
                EffectiveVariableRow(
                    variable: variable,
                    environmentID: globalEnvironment?.id ?? "",
                    source: .global
                )
            )
        }

        for variable in collectionEnvironment?.variables ?? [] {
            let row = EffectiveVariableRow(
                variable: variable,
                environmentID: collectionEnvironment?.id ?? "",
                source: indexesByName[variable.name] == nil ? .collection : .collectionOverride
            )

            if let index = indexesByName[variable.name] {
                rows[index] = row
            } else {
                indexesByName[variable.name] = rows.count
                rows.append(row)
            }
        }

        return rows
    }

    private func authSummary(for auth: APIAuth?) -> String {
        guard let auth, auth.type != .none else {
            return "None"
        }

        switch auth.type {
        case .none:
            return "None"
        case .bearer:
            return "Bearer token"
        case .basic:
            return "Basic"
        case .apiKey:
            return "API key"
        }
    }

    private func bodySummary(for request: APIRequest) -> String {
        if request.kind == .graphQL {
            return request.graphQL == nil ? "Missing GraphQL payload" : "GraphQL payload"
        }

        switch request.body {
        case .none:
            return "None"
        case .raw:
            return "Raw"
        case .json:
            return "JSON"
        case .form(let fields):
            return "Form (\(fields.count))"
        }
    }

    private func errorMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func redactedSecrets(in value: String) -> String {
        secretValuesForRedaction().reduce(value) { output, secret in
            output.replacingOccurrences(of: secret, with: "••••••")
        }
    }

    private func secretValuesForRedaction() -> [String] {
        let environments = [globalEnvironment, collectionEnvironment].compactMap(\.self)
        var values = Set<String>()

        for environment in environments {
            for variable in environment.variables where variable.isSecret {
                let value = store.readSecretValue(environmentID: environment.id, variableID: variable.id)

                guard !value.isEmpty else {
                    continue
                }

                values.insert(value)

                if let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    values.insert(encodedValue)
                }
            }
        }

        return values.sorted { $0.count > $1.count }
    }
}

private enum InspectorMode: String, CaseIterable, Identifiable {
    case details
    case variables
    case resolved
    case response

    var id: String { rawValue }

    var title: String {
        switch self {
        case .details:
            return "Details"
        case .variables:
            return "Variables"
        case .resolved:
            return "Resolved"
        case .response:
            return "Response"
        }
    }
}

private struct EffectiveVariableRow: Identifiable {
    var variable: APIVariable
    var environmentID: String
    var source: EffectiveVariableSource

    var id: String {
        "\(environmentID):\(variable.id):\(variable.name)"
    }
}

private enum EffectiveVariableSource {
    case global
    case collection
    case collectionOverride

    var label: String {
        switch self {
        case .global:
            return "Global"
        case .collection:
            return "Collection"
        case .collectionOverride:
            return "Collection override"
        }
    }

    var tint: Color {
        switch self {
        case .global:
            return RequestLabTheme.environment
        case .collection, .collectionOverride:
            return RequestLabTheme.collection
        }
    }
}
