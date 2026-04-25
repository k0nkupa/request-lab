import AppKit
import RequestLabCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: AppStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } detail: {
            HSplitView {
                centerWorkspace
                    .frame(minWidth: 560)
                    .background(RequestLabTheme.background)

                if store.isInspectorVisible {
                    InspectorView(store: store)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                        .background(RequestLabTheme.surface)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Open", systemImage: "folder") {
                    openWorkspacePanel()
                }
                .keyboardShortcut("o", modifiers: .command)
                .help("Open workspace")

                Menu("New", systemImage: "plus") {
                    Button("Request") {
                        store.createRequest()
                    }
                    .keyboardShortcut("n", modifiers: .command)

                    Button("GraphQL Request") {
                        store.createRequest(kind: .graphQL)
                    }

                    Divider()

                    Button("Collection") {
                        store.createCollection()
                    }

                    Button("Environment") {
                        store.createEnvironment()
                    }
                }
                .help("Create item")

                Menu("Import", systemImage: "square.and.arrow.down") {
                    Button("Postman Collection") {
                        importPostmanCollectionPanel()
                    }

                    Button("Postman Environment") {
                        importPostmanEnvironmentPanel()
                    }
                }
                .help("Import Postman JSON")

                Button("Send", systemImage: "paperplane") {
                    Task {
                        await store.sendSelectedRequest()
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(store.selectedRequest == nil || store.isSending)
                .help("Send request")

                Button("Delete", systemImage: "trash", role: .destructive) {
                    store.deleteSelectedRequest()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(store.selectedRequest == nil)
                .help("Delete selected request")

                Button("Save", systemImage: "square.and.arrow.down") {
                    if store.workspaceURL == nil {
                        saveWorkspacePanel()
                    } else {
                        store.saveWorkspace()
                    }
                }
                    .keyboardShortcut("s", modifiers: .command)
                    .help("Save workspace")

                Button("Save As", systemImage: "square.and.arrow.down.on.square") {
                    saveWorkspacePanel()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .help("Save workspace as")
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 12) {
                    Text(store.workspaceLocationTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    environmentMenu
                }
            }

            ToolbarItem {
                Button(
                    "Inspector",
                    systemImage: store.isInspectorVisible ? "sidebar.trailing" : "sidebar.right"
                ) {
                    store.isInspectorVisible.toggle()
                }
                .help(store.isInspectorVisible ? "Hide inspector" : "Show inspector")
            }
        }
        .alert(
            "Workspace Error",
            isPresented: Binding(
                get: { store.workspaceErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.workspaceErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.workspaceErrorMessage ?? "")
        }
    }

    private var environmentMenu: some View {
        Menu {
            Section("Global Environments") {
                Button("None") {
                    store.selectGlobalEnvironment(id: nil)
                }

                ForEach(store.workspace.environments) { environment in
                    Button(environment.name) {
                        store.selectCenterPane(.globalEnvironment(environment.id))
                    }
                }
            }

            Section("Collection Environments") {
                if let collection = store.selectedCollection {
                    Button("None") {
                        store.selectCollectionEnvironment(id: nil, for: collection.id)
                    }

                    ForEach(collection.environments) { environment in
                        Button(environment.name) {
                            store.selectCenterPane(
                                .collectionEnvironment(collectionID: collection.id, environmentID: environment.id)
                            )
                        }
                    }
                } else {
                    Text("Select a request")
                }
            }
        } label: {
            Label(store.environmentPairTitle, systemImage: "server.rack")
        }
        .frame(minWidth: 180)
        .tint(RequestLabTheme.environment)
        .help("Select global and collection environments")
    }

    @ViewBuilder
    private var centerWorkspace: some View {
        switch store.selectedCenterPane {
        case .globalEnvironment, .collectionEnvironment:
            EnvironmentEditorView(store: store)
        case .request, .none:
            RequestEditorView(store: store)
        }
    }

    private func openWorkspacePanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        store.openWorkspace(at: url)
    }

    private func saveWorkspacePanel() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(store.workspace.name).workspace"
        panel.canCreateDirectories = true
        panel.prompt = "Save"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        store.saveWorkspace(to: url)
    }

    private func importPostmanCollectionPanel() {
        openJSONPanel(prompt: "Import") { url in
            store.importPostmanCollection(from: url)
        }
    }

    private func importPostmanEnvironmentPanel() {
        openJSONPanel(prompt: "Import") { url in
            store.importPostmanEnvironment(from: url)
        }
    }

    private func openJSONPanel(prompt: String, onSelect: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.prompt = prompt

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        onSelect(url)
    }
}
