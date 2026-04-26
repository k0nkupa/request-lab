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
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundStyle(RequestLabTheme.environment)
                .symbolRenderingMode(.hierarchical)
                .help("Environment")

            VStack(alignment: .leading, spacing: 6) {
                Text(store.selectedEnvironmentEditorTitle)
                    .font(.title.bold())

                Text(environment?.name ?? "No environment")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func environmentForm(_ environment: APIEnvironment) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.headline)

                TextField(
                    "Environment name",
                    text: environmentNameBinding(environmentID: environment.id)
                )
                .textFieldStyle(.roundedBorder)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Variables")
                        .font(.headline)

                    Spacer()

                    Button {
                        store.addEnvironmentVariable(environmentID: environment.id)
                    } label: {
                        Label("Add variable", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .tint(RequestLabTheme.environment)
                }

                if environment.variables.isEmpty {
                    ContentUnavailableView(
                        "No variables",
                        systemImage: "textformat",
                        description: Text("Add a key and value for this environment.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(environment.variables) { variable in
                            variableRow(environmentID: environment.id, variable: variable)
                        }
                    }
                }
            }

            Spacer()
        }
    }

    private func variableRow(environmentID: String, variable: APIVariable) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: variable.isSecret ? "key.horizontal.fill" : "textformat")
                .foregroundStyle(variable.isSecret ? RequestLabTheme.warning : RequestLabTheme.environment)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18)

            TextField(
                "Key",
                text: variableNameBinding(environmentID: environmentID, variableID: variable.id)
            )
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 160, idealWidth: 220, maxWidth: 280)

            if variable.isSecret {
                SecureField(
                    "Stored in Keychain",
                    text: secretBinding(environmentID: environmentID, variableID: variable.id)
                )
                .textFieldStyle(.roundedBorder)
            } else {
                TextField(
                    "Value",
                    text: variableBinding(environmentID: environmentID, variableID: variable.id)
                )
                .textFieldStyle(.roundedBorder)
            }

            Button(role: .destructive) {
                store.deleteEnvironmentVariable(environmentID: environmentID, variableID: variable.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete variable")
        }
        .padding(10)
        .requestLabSurface(tint: variable.isSecret ? RequestLabTheme.warning : RequestLabTheme.environment)
    }

    private func environmentNameBinding(environmentID: String) -> Binding<String> {
        Binding(
            get: {
                store.environmentName(environmentID: environmentID)
            },
            set: { name in
                store.updateEnvironmentName(environmentID: environmentID, name: name)
            }
        )
    }

    private func variableNameBinding(environmentID: String, variableID: String) -> Binding<String> {
        Binding(
            get: {
                store.variableName(environmentID: environmentID, variableID: variableID)
            },
            set: { name in
                store.updateEnvironmentVariableName(
                    environmentID: environmentID,
                    variableID: variableID,
                    name: name
                )
            }
        )
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
