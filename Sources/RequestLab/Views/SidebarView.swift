import RequestLabCore
import SwiftUI

struct SidebarView: View {
    @Bindable var store: AppStore

    var body: some View {
        List(selection: $store.selectedRequestID) {
            Section("Collections") {
                ForEach(store.workspace.collections) { collection in
                    DisclosureGroup {
                        ForEach(collection.requests) { request in
                            Label(request.name, systemImage: request.kind == .graphQL ? "curlybraces" : "doc.text")
                                .tag(Optional(request.id))
                        }
                    } label: {
                        Label(collection.name, systemImage: "folder")
                    }
                }
            }

            Section("Environments") {
                ForEach(store.workspace.environments) { environment in
                    Label(environment.name, systemImage: "server.rack")
                        .foregroundStyle(
                            environment.id == store.selectedEnvironmentID ? .primary : .secondary
                        )
                        .contextMenu {
                            Button("Use Environment") {
                                store.selectedEnvironmentID = environment.id
                            }
                        }
                        .onTapGesture {
                            store.selectedEnvironmentID = environment.id
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
        .navigationTitle(store.workspace.name)
    }
}
