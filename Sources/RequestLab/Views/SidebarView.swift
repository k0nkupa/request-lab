import RequestLabCore
import SwiftUI

struct SidebarView: View {
    @Bindable var store: AppStore
    @State private var renamingCollectionID: String?
    @State private var collectionNameDraft = ""
    @FocusState private var isCollectionNameFieldFocused: Bool

    var body: some View {
        List(selection: selection) {
            Section("Collections") {
                ForEach(store.workspace.collections) { collection in
                    DisclosureGroup {
                        ForEach(collection.environments) { environment in
                            let rowSelection = CenterPaneSelection.collectionEnvironment(
                                collectionID: collection.id,
                                environmentID: environment.id
                            )

                            environmentLabel(
                                environment,
                                isSelected: rowSelection == store.selectedCenterPane,
                                isActive: store.selectedCollectionEnvironmentIDByCollectionID[collection.id] == environment.id
                            )
                                .tag(rowSelection)
                                .contextMenu {
                                    Button("Use Environment") {
                                        store.selectCenterPane(
                                            .collectionEnvironment(
                                                collectionID: collection.id,
                                                environmentID: environment.id
                                            )
                                        )
                                    }

                                    Button("Delete Environment", role: .destructive) {
                                        store.deleteCollectionEnvironment(id: environment.id, fromCollectionID: collection.id)
                                    }
                                }
                        }

                        ForEach(collection.requests) { request in
                            let rowSelection = CenterPaneSelection.request(request.id)

                            requestLabel(request, isSelected: rowSelection == store.selectedCenterPane)
                                .tag(rowSelection)
                                .contextMenu {
                                    Button("Delete Request", role: .destructive) {
                                        store.deleteRequest(id: request.id)
                                    }
                                }
                        }
                    } label: {
                        collectionLabel(collection)
                            .id(collection.id)
                    }
                    .contextMenu {
                        Button("Rename Collection") {
                            startRenamingCollection(collection)
                        }

                        Divider()

                        Button("New Request") {
                            store.createRequest(in: collection.id)
                        }

                        Button("New Collection Environment") {
                            store.createCollectionEnvironment(in: collection.id)
                        }

                        Divider()

                        Button("Delete Collection", role: .destructive) {
                            store.deleteCollection(id: collection.id)
                        }
                    }
                }
            }

            Section("Global Environments") {
                ForEach(store.workspace.environments) { environment in
                    let rowSelection = CenterPaneSelection.globalEnvironment(environment.id)

                    environmentLabel(
                        environment,
                        isSelected: rowSelection == store.selectedCenterPane,
                        isActive: environment.id == store.selectedGlobalEnvironmentID
                    )
                        .tag(rowSelection)
                        .contextMenu {
                            Button("Use Environment") {
                                store.selectCenterPane(.globalEnvironment(environment.id))
                            }

                            Button("Delete Environment", role: .destructive) {
                                store.deleteEnvironment(id: environment.id)
                            }
                        }
                }
            }

            Section("History") {
                if store.workspace.history.isEmpty {
                    ContentUnavailableView(
                        "No history",
                        systemImage: "clock",
                        description: Text("Responses will appear here after requests run.")
                    )
                } else {
                    ForEach(store.workspace.history) { entry in
                        Label(entry.url, systemImage: "clock")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(store.editorTitle)
    }

    @ViewBuilder
    private func collectionLabel(_ collection: APICollection) -> some View {
        if renamingCollectionID == collection.id {
            TextField("Collection name", text: $collectionNameDraft)
                .textFieldStyle(.plain)
                .focused($isCollectionNameFieldFocused)
                .onSubmit {
                    commitCollectionRename()
                }
                .onExitCommand {
                    cancelCollectionRename()
                }
                .onChange(of: isCollectionNameFieldFocused) { _, isFocused in
                    if !isFocused, renamingCollectionID == collection.id {
                        commitCollectionRename()
                    }
                }
        } else {
            Label {
                Text(collection.name)
            } icon: {
                Image(systemName: "folder")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(RequestLabTheme.collectionColor(collection.color))
            }
        }
    }

    private func requestLabel(_ request: APIRequest, isSelected: Bool) -> some View {
        Label {
            Text(request.name)
                .fontWeight(isSelected ? .semibold : .regular)
        } icon: {
            Image(systemName: request.kind == .graphQL ? "curlybraces" : "doc.text")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(request.kind == .graphQL ? RequestLabTheme.graphQL : RequestLabTheme.selection)
        }
    }

    private func environmentLabel(_ environment: APIEnvironment, isSelected: Bool, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Label {
                Text(environment.name)
                    .fontWeight(isSelected || isActive ? .semibold : .regular)
            } icon: {
                Image(systemName: "server.rack")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected || isActive ? RequestLabTheme.environment : .secondary)
            }

            Spacer(minLength: 4)

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(RequestLabTheme.environment)
                    .accessibilityLabel("Active environment")
            }
        }
    }

    private func startRenamingCollection(_ collection: APICollection) {
        if renamingCollectionID == collection.id {
            isCollectionNameFieldFocused = true
            return
        }

        if renamingCollectionID != nil {
            commitCollectionRename()
        }

        renamingCollectionID = collection.id
        collectionNameDraft = collection.name
        isCollectionNameFieldFocused = true
    }

    private func commitCollectionRename() {
        guard let collectionID = renamingCollectionID else {
            return
        }

        let trimmedName = collectionNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            store.renameCollection(id: collectionID, to: trimmedName)
        }

        renamingCollectionID = nil
        collectionNameDraft = ""
        isCollectionNameFieldFocused = false
    }

    private func cancelCollectionRename() {
        renamingCollectionID = nil
        collectionNameDraft = ""
        isCollectionNameFieldFocused = false
    }

    private var selection: Binding<CenterPaneSelection?> {
        Binding(
            get: { store.selectedCenterPane },
            set: { store.selectCenterPane($0) }
        )
    }
}
