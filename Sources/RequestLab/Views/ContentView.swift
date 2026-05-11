import AppKit
import RequestLabCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: AppStore
    @State private var isDeleteSelectedRequestConfirmationPresented = false

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            HSplitView {
                centerWorkspace
                    .frame(minWidth: 620)
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
                ToolbarIconButton("Open workspace", systemImage: "folder") {
                    openWorkspacePanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                ToolbarIconButton("Create item", systemImage: "plus") {
                    createItemPopover
                }

                ToolbarIconButton("Import Postman JSON", systemImage: "square.and.arrow.down") {
                    importPopover
                }

                ToolbarIconButton("Send request", systemImage: "paperplane") {
                    Task {
                        await store.sendSelectedRequest()
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(store.selectedRequest == nil || store.isSending)

                ToolbarIconButton("Delete selected request", systemImage: "trash", role: .destructive) {
                    isDeleteSelectedRequestConfirmationPresented = true
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(store.selectedRequest == nil)

                ToolbarIconButton("Save workspace", systemImage: "square.and.arrow.down") {
                    if store.workspaceURL == nil {
                        saveWorkspacePanel()
                    } else {
                        store.saveWorkspace()
                    }
                }
                .keyboardShortcut("s", modifiers: .command)

                ToolbarIconButton("Save workspace as", systemImage: "square.and.arrow.down.on.square") {
                    saveWorkspacePanel()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
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
                ToolbarIconButton(
                    store.isInspectorVisible ? "Hide inspector" : "Show inspector",
                    systemImage: store.isInspectorVisible ? "sidebar.trailing" : "sidebar.right"
                ) {
                    store.isInspectorVisible.toggle()
                }
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
        .confirmationDialog(
            "Delete Request?",
            isPresented: $isDeleteSelectedRequestConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Request", role: .destructive) {
                store.deleteSelectedRequest()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \"\(store.selectedRequest?.name ?? "selected request")\"? This cannot be undone.")
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

    private var createItemPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .buttonStyle(.plain)
        .padding(10)
        .frame(width: 180, alignment: .leading)
    }

    private var importPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("Postman Collection") {
                importPostmanCollectionPanel()
            }

            Button("Postman Environment") {
                importPostmanEnvironmentPanel()
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .frame(width: 220, alignment: .leading)
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

private enum ToolbarIconPopover: Identifiable {
    case tooltip
    case actions

    var id: String {
        switch self {
        case .tooltip:
            "tooltip"
        case .actions:
            "actions"
        }
    }
}

private struct ToolbarIconButton<PopoverContent: View>: View {
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let action: () -> Void
    let popoverContent: (() -> PopoverContent)?
    @State private var activePopover: ToolbarIconPopover?
    @State private var tooltipWorkItem: DispatchWorkItem?

    init(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) where PopoverContent == EmptyView {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
        popoverContent = nil
    }

    init(
        _ title: String,
        systemImage: String,
        @ViewBuilder popoverContent: @escaping () -> PopoverContent
    ) {
        self.title = title
        self.systemImage = systemImage
        role = nil
        action = {}
        self.popoverContent = popoverContent
    }

    var body: some View {
        Button(role: role) {
            if popoverContent == nil {
                action()
            } else {
                tooltipWorkItem?.cancel()
                activePopover = .actions
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .help(title)
        .accessibilityLabel(Text(title))
        .onHover { isHovering in
            if isHovering {
                scheduleTooltip()
            } else if activePopover == .tooltip {
                tooltipWorkItem?.cancel()
                activePopover = nil
            } else {
                tooltipWorkItem?.cancel()
            }
        }
        .popover(item: $activePopover, arrowEdge: .bottom) { popover in
            switch popover {
            case .tooltip:
                ToolbarTooltipBubble(text: title)
            case .actions:
                if let popoverContent {
                    popoverContent()
                }
            }
        }
    }

    private func scheduleTooltip() {
        tooltipWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            activePopover = .tooltip
        }
        tooltipWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }
}

private struct ToolbarTooltipBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
