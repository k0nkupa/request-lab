import AppKit
import RequestLabCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: AppStore
    @State private var isDeleteSelectedRequestConfirmationPresented = false
    @State private var isCurlImportPresented = false
    @State private var curlImportText = ""
    @State private var isCommandPalettePresented = false

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

                ToolbarIconButton("Import and export", systemImage: "square.and.arrow.down") {
                    importPopover
                }

                ToolbarIconButton("Command palette", systemImage: "command") {
                    isCommandPalettePresented = true
                }
                .keyboardShortcut("k", modifiers: .command)

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
        .sheet(isPresented: $isCurlImportPresented) {
            CurlImportSheet(
                command: $curlImportText,
                onCancel: {
                    curlImportText = ""
                    isCurlImportPresented = false
                },
                onImport: {
                    store.importCurlCommand(curlImportText)
                    curlImportText = ""
                    isCurlImportPresented = false
                }
            )
        }
        .sheet(isPresented: $isCommandPalettePresented) {
            CommandPaletteView(commands: commandPaletteCommands)
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

            Divider()

            Button("cURL Command") {
                isCurlImportPresented = true
            }

            Button("Copy Selected as cURL") {
                copySelectedRequestAsCurl()
            }
            .disabled(store.selectedRequest == nil)
        }
        .buttonStyle(.plain)
        .padding(10)
        .frame(width: 220, alignment: .leading)
    }

    private var commandPaletteCommands: [CommandPaletteCommand] {
        [
            CommandPaletteCommand(id: "open-workspace", title: "Open Workspace", systemImage: "folder") {
                openWorkspacePanel()
            },
            CommandPaletteCommand(id: "save-workspace", title: "Save Workspace", systemImage: "square.and.arrow.down") {
                if store.workspaceURL == nil {
                    saveWorkspacePanel()
                } else {
                    store.saveWorkspace()
                }
            },
            CommandPaletteCommand(id: "save-workspace-as", title: "Save Workspace As", systemImage: "square.and.arrow.down.on.square") {
                saveWorkspacePanel()
            },
            CommandPaletteCommand(id: "import-postman-collection", title: "Import Postman Collection", systemImage: "square.and.arrow.down") {
                importPostmanCollectionPanel()
            },
            CommandPaletteCommand(id: "import-postman-environment", title: "Import Postman Environment", systemImage: "server.rack") {
                importPostmanEnvironmentPanel()
            },
            CommandPaletteCommand(id: "import-curl", title: "Import cURL Command", systemImage: "terminal") {
                isCurlImportPresented = true
            },
            CommandPaletteCommand(id: "new-request", title: "New Request", systemImage: "doc.badge.plus") {
                store.createRequest()
            },
            CommandPaletteCommand(id: "new-graphql-request", title: "New GraphQL Request", systemImage: "curlybraces") {
                store.createRequest(kind: .graphQL)
            },
            CommandPaletteCommand(id: "new-collection", title: "New Collection", systemImage: "folder.badge.plus") {
                store.createCollection()
            },
            CommandPaletteCommand(id: "new-environment", title: "New Environment", systemImage: "server.rack") {
                store.createEnvironment()
            },
            CommandPaletteCommand(
                id: "send-request",
                title: "Send Request",
                systemImage: "paperplane",
                isEnabled: store.selectedRequest != nil && !store.isSending
            ) {
                Task {
                    await store.sendSelectedRequest()
                }
            },
            CommandPaletteCommand(id: "toggle-inspector", title: "Toggle Inspector", systemImage: "sidebar.right") {
                store.isInspectorVisible.toggle()
            },
            CommandPaletteCommand(id: "search-requests", title: "Search Requests", systemImage: "magnifyingglass") {
                isCommandPalettePresented = false
            },
            CommandPaletteCommand(
                id: "copy-response-body",
                title: "Copy Response Body",
                systemImage: "doc.on.doc",
                isEnabled: store.latestResponse != nil
            ) {
                copyToPasteboard(store.latestResponse?.body ?? "")
            },
            CommandPaletteCommand(
                id: "copy-response-headers",
                title: "Copy Response Headers",
                systemImage: "list.bullet.rectangle",
                isEnabled: store.latestResponse != nil
            ) {
                copyToPasteboard(formattedHeaders(store.latestResponse?.headers ?? [:]))
            },
            CommandPaletteCommand(
                id: "copy-curl",
                title: "Copy as cURL",
                systemImage: "terminal",
                isEnabled: store.selectedRequest != nil
            ) {
                copySelectedRequestAsCurl()
            }
        ]
    }

    @ViewBuilder
    private var centerWorkspace: some View {
        switch store.selectedCenterPane {
        case .globalEnvironment, .collectionEnvironment:
            EnvironmentEditorView(store: store)
        case .history:
            HistoryDetailView(store: store)
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

    private func copySelectedRequestAsCurl() {
        guard let command = store.curlCommandForSelectedRequest() else {
            return
        }

        copyToPasteboard(command)
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func formattedHeaders(_ headers: [String: String]) -> String {
        headers
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
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

private struct CurlImportSheet: View {
    @Binding var command: String
    let onCancel: () -> Void
    let onImport: () -> Void

    private var canImport: Bool {
        !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Import cURL", systemImage: "terminal")
                    .font(.title2.bold())

                Spacer()
            }

            TextEditor(text: $command)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .accessibilityLabel("cURL command")
                .frame(width: 620, height: 220)
                .padding(8)
                .background(RequestLabTheme.elevatedSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(RequestLabTheme.editorBorder, lineWidth: 1)
                }

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    onCancel()
                }

                Button("Import", systemImage: "square.and.arrow.down") {
                    onImport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canImport)
            }
        }
        .padding(18)
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
