import RequestLabCore
import SwiftUI

struct RequestsNavigatorView: View {
    @Bindable var store: AppStore
    let searchText: String
    let confirmDeleteRequest: (String) -> Void

    var body: some View {
        List(selection: selection) {
            if filteredCollections.isEmpty {
                emptyState
            } else {
                ForEach(filteredCollections) { item in
                    Section {
                        ForEach(item.requests) { request in
                            requestRow(request)
                                .tag(CenterPaneSelection.request(request.id))
                                .contextMenu {
                                    Button("Duplicate") {
                                        store.duplicateRequest(id: request.id)
                                    }

                                    Button("Delete", role: .destructive) {
                                        confirmDeleteRequest(request.id)
                                    }
                                }
                        }
                    } header: {
                        Label {
                            Text(item.collection.name)
                        } icon: {
                            Image(systemName: "folder")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(RequestLabTheme.collectionColor(item.collection.color))
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
                "No requests",
                systemImage: "arrow.left.arrow.right",
                description: Text("Create or import a request to start building this workspace.")
            )
        }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFiltering: Bool {
        !normalizedSearchText.isEmpty
    }

    private var filteredCollections: [FilteredRequestCollection] {
        store.workspace.collections.compactMap { collection in
            guard isFiltering else {
                return FilteredRequestCollection(collection: collection, requests: collection.requests)
            }

            if matchesSearch(collection.name) {
                return FilteredRequestCollection(collection: collection, requests: collection.requests)
            }

            let requests = collection.requests.filter(requestMatchesSearch)
            guard !requests.isEmpty else {
                return nil
            }

            return FilteredRequestCollection(collection: collection, requests: requests)
        }
    }

    private func requestRow(_ request: APIRequest) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(request.method.rawValue)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(RequestLabTheme.methodColor(request.method))
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.name)
                    .fontWeight(store.selectedCenterPane == .request(request.id) ? .semibold : .regular)
                    .lineLimit(1)

                Text(request.url)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func requestMatchesSearch(_ request: APIRequest) -> Bool {
        matchesSearch(request.name)
            || matchesSearch(request.url)
            || matchesSearch(request.method.rawValue)
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

private struct FilteredRequestCollection: Identifiable {
    let collection: APICollection
    let requests: [APIRequest]

    var id: String {
        collection.id
    }
}
