import RequestLabCore
import SwiftUI

struct InspectorView: View {
    @Bindable var store: AppStore

    private var request: APIRequest? {
        store.selectedRequest
    }

    private var environment: APIEnvironment? {
        store.selectedEnvironment
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
                environmentSection
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

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Environment")
                .font(.headline)

            if let environment {
                LabeledContent("Name", value: environment.name)

                ForEach(environment.variables) { variable in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(variable.name, systemImage: variable.isSecret ? "key" : "textformat")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if variable.isSecret {
                            SecureField(
                                "Stored in Keychain",
                                text: secretBinding(environmentID: environment.id, variableID: variable.id)
                            )
                            .textFieldStyle(.roundedBorder)
                        } else {
                            TextField(
                                "Value",
                                text: variableBinding(environmentID: environment.id, variableID: variable.id)
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            } else {
                ContentUnavailableView("No environment selected", systemImage: "server.rack")
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

    private func variableBinding(environmentID: String, variableID: String) -> Binding<String> {
        Binding(
            get: {
                environment?.variables.first { $0.id == variableID }?.value ?? ""
            },
            set: { value in
                store.updateEnvironmentVariable(
                    environmentID: environmentID,
                    variableID: variableID,
                    value: value.isEmpty ? nil : value
                )
            }
        )
    }

    private func secretBinding(environmentID: String, variableID: String) -> Binding<String> {
        Binding(
            get: {
                store.readSecretValue(environmentID: environmentID, variableID: variableID)
            },
            set: { value in
                store.writeSecretValue(environmentID: environmentID, variableID: variableID, value: value)
            }
        )
    }
}
