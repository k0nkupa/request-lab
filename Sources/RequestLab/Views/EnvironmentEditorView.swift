import RequestLabCore
import SwiftUI

struct EnvironmentEditorView: View {
    @Bindable var store: AppStore

    private var environment: APIEnvironment? {
        store.selectedEnvironmentForEditing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let environment {
                        environmentForm(environment)
                    } else {
                        ContentUnavailableView(
                            "No environment selected",
                            systemImage: "server.rack",
                            description: Text("Choose a global or collection environment from the sidebar.")
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.selectedEnvironmentEditorTitle)
                .font(.title.bold())

            Text(environment?.name ?? "No environment")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func environmentForm(_ environment: APIEnvironment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledContent("Name", value: environment.name)

            if environment.variables.isEmpty {
                ContentUnavailableView("No variables", systemImage: "textformat")
            } else {
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
            }

            Spacer()
        }
    }

    private func variableBinding(environmentID: String, variableID: String) -> Binding<String> {
        Binding(
            get: {
                store.variableValue(environmentID: environmentID, variableID: variableID)
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
