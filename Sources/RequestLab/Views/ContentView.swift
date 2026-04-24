import AppKit
import RequestLabCore
import SwiftUI

struct ContentView: View {
    @Bindable var store: AppStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } detail: {
            HSplitView {
                RequestEditorView(store: store)
                    .frame(minWidth: 560)

                if store.isInspectorVisible {
                    InspectorView(store: store)
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Open", systemImage: "folder") {
                    openWorkspacePanel()
                }
                .help("Open workspace")

                Button("Send", systemImage: "paperplane") {
                    Task {
                        await store.sendSelectedRequest()
                    }
                }
                .disabled(store.selectedRequest == nil || store.isSending)
                .help("Send request")

                Button("Save", systemImage: "square.and.arrow.down") {
                    if store.workspaceURL == nil {
                        saveWorkspacePanel()
                    } else {
                        store.saveWorkspace()
                    }
                }
                    .help("Save workspace")

                Button("Save As", systemImage: "square.and.arrow.down.on.square") {
                    saveWorkspacePanel()
                }
                .help("Save workspace as")
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 12) {
                    Text(store.workspaceLocationTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Environment", selection: $store.selectedEnvironmentID) {
                        ForEach(store.workspace.environments) { environment in
                            Text(environment.name)
                                .tag(Optional(environment.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 180)
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
}
