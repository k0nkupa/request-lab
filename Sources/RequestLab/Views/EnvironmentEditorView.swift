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
                .padding(.horizontal, RequestLabSpacing.lg)
                .padding(.vertical, RequestLabSpacing.md)
                .workbenchSurface(.chrome, cornerRadius: 0)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: RequestLabSpacing.lg) {
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
                .padding(RequestLabSpacing.lg)
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
        VStack(alignment: .leading, spacing: RequestLabSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.headline)

                TextField(
                    "Environment name",
                    text: environmentNameBinding(environmentID: environment.id)
                )
                .textFieldStyle(.roundedBorder)
            }
            .padding(RequestLabSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .workbenchSurface(.elevated, cornerRadius: 8, tint: RequestLabTheme.environment)

            VStack(alignment: .leading, spacing: RequestLabSpacing.md) {
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
                    let duplicateNames = duplicateVariableNames(in: environment)

                    if !duplicateNames.isEmpty {
                        Label(
                            "Duplicate variable names: \(duplicateNames.sorted().joined(separator: ", "))",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RequestLabTheme.warning)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(environment.variables) { variable in
                            variableRow(
                                environmentID: environment.id,
                                variable: variable,
                                hasDuplicateName: duplicateNames.contains(variable.name)
                            )
                        }
                    }
                }
            }
            .padding(RequestLabSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .workbenchSurface(.elevated, cornerRadius: 8, tint: RequestLabTheme.environment)

            Spacer()
        }
    }

    private func variableRow(environmentID: String, variable: APIVariable, hasDuplicateName: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        "Keychain value",
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

            if variable.isSecret {
                Text("Secret values are stored in macOS Keychain and are not written to shared YAML.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if hasDuplicateName {
                Label("This name is duplicated in the selected environment.", systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RequestLabTheme.warning)
            }
        }
        .padding(RequestLabSpacing.md)
        .workbenchSurface(
            .elevated,
            cornerRadius: 8,
            tint: variable.isSecret ? RequestLabTheme.warning : RequestLabTheme.environment
        )
    }

    private func duplicateVariableNames(in environment: APIEnvironment) -> Set<String> {
        let names = environment.variables
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let groupedNames = Dictionary(grouping: names, by: { $0 })

        return Set(groupedNames.compactMap { name, values in
            values.count > 1 ? name : nil
        })
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
