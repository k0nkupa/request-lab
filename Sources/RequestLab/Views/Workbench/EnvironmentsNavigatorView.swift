import RequestLabCore
import SwiftUI

struct EnvironmentsNavigatorView: View {
    @Bindable var store: AppStore
    let searchText: String

    var body: some View {
        List(selection: selection) {
            if filteredGlobalEnvironments.isEmpty && filteredCollections.isEmpty {
                emptyState
            } else {
                Section("Global Environments") {
                    ForEach(filteredGlobalEnvironments) { environment in
                        environmentRow(
                            environment,
                            scope: nil,
                            isActive: environment.id == store.selectedGlobalEnvironmentID
                        )
                        .tag(CenterPaneSelection.globalEnvironment(environment.id))
                    }
                }

                ForEach(filteredCollections) { item in
                    Section(item.collection.name) {
                        ForEach(item.environments) { environment in
                            environmentRow(
                                environment,
                                scope: item.collection.name,
                                isActive: store.selectedCollectionEnvironmentIDByCollectionID[item.collection.id] == environment.id
                            )
                            .tag(
                                CenterPaneSelection.collectionEnvironment(
                                    collectionID: item.collection.id,
                                    environmentID: environment.id
                                )
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var emptyState: some View {
        if isFiltering {
            ContentUnavailableView.search
        } else {
            ContentUnavailableView(
                "No environments",
                systemImage: "server.rack",
                description: Text("Create an environment to manage shared variables.")
            )
        }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFiltering: Bool {
        !normalizedSearchText.isEmpty
    }

    private var filteredGlobalEnvironments: [APIEnvironment] {
        guard isFiltering else {
            return store.workspace.environments
        }

        return store.workspace.environments.filter(environmentMatchesSearch)
    }

    private var filteredCollections: [FilteredEnvironmentCollection] {
        store.workspace.collections.compactMap { collection in
            guard isFiltering else {
                guard !collection.environments.isEmpty else {
                    return nil
                }

                return FilteredEnvironmentCollection(collection: collection, environments: collection.environments)
            }

            if matchesSearch(collection.name) {
                return FilteredEnvironmentCollection(collection: collection, environments: collection.environments)
            }

            let environments = collection.environments.filter(environmentMatchesSearch)
            guard !environments.isEmpty else {
                return nil
            }

            return FilteredEnvironmentCollection(collection: collection, environments: environments)
        }
    }

    private func environmentRow(
        _ environment: APIEnvironment,
        scope: String?,
        isActive: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "server.rack")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isActive ? RequestLabTheme.environment : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(environment.name)
                    .fontWeight(isActive ? .semibold : .regular)
                    .lineLimit(1)

                if let scope {
                    Text(scope)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)
        }
    }

    private func environmentMatchesSearch(_ environment: APIEnvironment) -> Bool {
        matchesSearch(environment.name)
    }

    private func matchesSearch(_ value: String) -> Bool {
        value.localizedCaseInsensitiveContains(normalizedSearchText)
    }

    private var selection: Binding<CenterPaneSelection?> {
        Binding(
            get: { store.selectedCenterPane },
            set: { store.selectCenterPane($0) }
        )
    }
}

private struct FilteredEnvironmentCollection: Identifiable {
    let collection: APICollection
    let environments: [APIEnvironment]

    var id: String {
        collection.id
    }
}
