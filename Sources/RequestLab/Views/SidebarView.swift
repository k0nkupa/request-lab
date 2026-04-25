import RequestLabCore
import SwiftUI

struct SidebarView: View {
    @Bindable var store: AppStore

    var body: some View {
        List(selection: selection) {
            Section("Collections") {
                ForEach(store.workspace.collections) { collection in
                    DisclosureGroup {
                        ForEach(collection.environments) { environment in
                            Label(environment.name, systemImage: "server.rack")
                                .tag(
                                    CenterPaneSelection.collectionEnvironment(
                                        collectionID: collection.id,
                                        environmentID: environment.id
                                    )
                                )
                                .foregroundStyle(
                                    environment.id == store.selectedCollectionEnvironment?.id ? .primary : .secondary
                                )
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
                            Label(request.name, systemImage: request.kind == .graphQL ? "curlybraces" : "doc.text")
                                .tag(CenterPaneSelection.request(request.id))
                                .contextMenu {
                                    Button("Delete Request", role: .destructive) {
                                        store.deleteRequest(id: request.id)
                                    }
                                }
                        }
                    } label: {
                        Label(collection.name, systemImage: "folder")
                    }
                    .contextMenu {
                        Button("New Request") {
                            store.createRequest(in: collection.id)
                        }

                        Button("New Collection Environment") {
                            store.createCollectionEnvironment(in: collection.id)
                        }

                        Button("Delete Collection", role: .destructive) {
                            store.deleteCollection(id: collection.id)
                        }
                    }
                }
            }

            Section("Global Environments") {
                ForEach(store.workspace.environments) { environment in
                    Label(environment.name, systemImage: "server.rack")
                        .tag(CenterPaneSelection.globalEnvironment(environment.id))
                        .foregroundStyle(
                            environment.id == store.selectedGlobalEnvironmentID ? .primary : .secondary
                        )
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

    private var selection: Binding<CenterPaneSelection?> {
        Binding(
            get: { store.selectedCenterPane },
            set: { store.selectCenterPane($0) }
        )
    }
}
