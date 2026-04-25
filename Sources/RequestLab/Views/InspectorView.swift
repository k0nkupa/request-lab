import RequestLabCore
import SwiftUI

struct InspectorView: View {
    @Bindable var store: AppStore

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
            VStack(alignment: .leading, spacing: 20) {
                requestSection
                Divider()
                globalEnvironmentSection
                Divider()
                collectionEnvironmentSection
                Divider()
                responseSection
            }
            .padding()
        }
    }

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Request")
                .font(.headline)

            if let request {
                LabeledContent("Name", value: request.name)
                LabeledContent("Type", value: request.kind == .graphQL ? "GraphQL" : "REST")
                LabeledContent("Method", value: request.method.rawValue)
                LabeledContent("URL", value: request.url)
                LabeledContent("Headers", value: "\(request.headers.count)")
                LabeledContent("Params", value: "\(request.params.count)")
            } else {
                ContentUnavailableView("No request selected", systemImage: "doc.text")
            }
        }
    }

    private var globalEnvironmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Global Environment")
                .font(.headline)

            if let globalEnvironment {
                environmentFields(globalEnvironment)
            } else {
                ContentUnavailableView("No global environment selected", systemImage: "server.rack")
            }
        }
    }

    private var collectionEnvironmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Collection Environment")
                .font(.headline)

            if let collectionEnvironment {
                environmentFields(collectionEnvironment)
            } else {
                ContentUnavailableView("No collection environment selected", systemImage: "server.rack")
            }
        }
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last Response")
                .font(.headline)

            if let response {
                LabeledContent("Status", value: "\(response.statusCode)")
                LabeledContent("Duration", value: "\(response.durationMilliseconds) ms")
                LabeledContent("URL", value: response.url)
                LabeledContent("Headers", value: "\(response.headers.count)")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else {
                ContentUnavailableView("No response", systemImage: "tray")
            }
        }
    }

    private func environmentFields(_ environment: APIEnvironment) -> some View {
        Group {
            LabeledContent("Name", value: environment.name)

            ForEach(environment.variables) { variable in
                VStack(alignment: .leading, spacing: 6) {
                    Label(variable.name, systemImage: variable.isSecret ? "key" : "textformat")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(displayValue(for: variable, in: environment))
                        .font(.caption)
                        .textSelection(.enabled)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private func displayValue(for variable: APIVariable, in environment: APIEnvironment) -> String {
        if variable.isSecret {
            return store.readSecretValue(environmentID: environment.id, variableID: variable.id).isEmpty
                ? "Stored in Keychain"
                : "••••••"
        }

        return variable.value ?? ""
    }
}
