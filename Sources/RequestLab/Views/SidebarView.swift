import RequestLabCore
import SwiftUI

struct SidebarView: View {
    @Bindable var store: AppStore
    @State private var sidebarSearchText = ""
    @State private var renamingCollectionID: String?
    @State private var collectionNameDraft = ""
    @FocusState private var isCollectionNameFieldFocused: Bool
    @State private var selectedColorCollectionID: String?

    var body: some View {
        List(selection: selection) {
            Section("Collections") {
                ForEach(filteredCollections) { collection in
                    DisclosureGroup {
                        ForEach(filteredCollectionEnvironments(in: collection)) { environment in
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

                        ForEach(filteredRequests(in: collection)) { request in
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
                            .popover(
                                isPresented: Binding(
                                    get: { selectedColorCollectionID == collection.id },
                                    set: { isPresented in
                                        if !isPresented, selectedColorCollectionID == collection.id {
                                            selectedColorCollectionID = nil
                                        }
                                    }
                                )
                            ) {
                                collectionColorPicker(forCollectionID: collection.id)
                            }
                    }
                    .contextMenu {
                        Button("Rename Collection") {
                            startRenamingCollection(collection)
                        }

                        Button("Change Color") {
                            selectedColorCollectionID = collection.id
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
                ForEach(filteredGlobalEnvironments) { environment in
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
                } else if filteredHistory.isEmpty {
                    ContentUnavailableView.search
                } else {
                    ForEach(filteredHistory) { entry in
                        historyLabel(entry)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $sidebarSearchText, placement: .sidebar, prompt: "Search")
        .navigationTitle(store.editorTitle)
    }

    private var normalizedSearchText: String {
        sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFilteringSidebar: Bool {
        !normalizedSearchText.isEmpty
    }

    private var filteredCollections: [APICollection] {
        guard isFilteringSidebar else {
            return store.workspace.collections
        }

        return store.workspace.collections.filter { collection in
            collectionMatchesSearch(collection)
                || !filteredCollectionEnvironments(in: collection).isEmpty
                || !filteredRequests(in: collection).isEmpty
        }
    }

    private var filteredGlobalEnvironments: [APIEnvironment] {
        guard isFilteringSidebar else {
            return store.workspace.environments
        }

        return store.workspace.environments.filter(environmentMatchesSearch)
    }

    private var filteredHistory: [APIHistoryEntry] {
        guard isFilteringSidebar else {
            return store.workspace.history
        }

        return store.workspace.history.filter { entry in
            matchesSearch(entry.url)
        }
    }

    private func filteredCollectionEnvironments(in collection: APICollection) -> [APIEnvironment] {
        guard isFilteringSidebar else {
            return collection.environments
        }

        if collectionMatchesSearch(collection) {
            return collection.environments
        }

        return collection.environments.filter(environmentMatchesSearch)
    }

    private func filteredRequests(in collection: APICollection) -> [APIRequest] {
        guard isFilteringSidebar else {
            return collection.requests
        }

        if collectionMatchesSearch(collection) {
            return collection.requests
        }

        return collection.requests.filter(requestMatchesSearch)
    }

    private func collectionMatchesSearch(_ collection: APICollection) -> Bool {
        matchesSearch(collection.name)
    }

    private func requestMatchesSearch(_ request: APIRequest) -> Bool {
        matchesSearch(request.name) || matchesSearch(request.url)
    }

    private func environmentMatchesSearch(_ environment: APIEnvironment) -> Bool {
        matchesSearch(environment.name)
    }

    private func matchesSearch(_ value: String) -> Bool {
        value.localizedCaseInsensitiveContains(normalizedSearchText)
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
                        cancelCollectionRename()
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

    private func collectionColorPicker(forCollectionID collectionID: String) -> some View {
        let selectedColor = store.workspace.collections.first { $0.id == collectionID }?.color

        return VStack(alignment: .leading, spacing: 12) {
            Text("Collection Color")
                .font(.headline)

            Button {
                store.updateCollectionColor(id: collectionID, color: nil)
                selectedColorCollectionID = nil
            } label: {
                colorOptionLabel(
                    title: "Default",
                    color: RequestLabTheme.collectionColor(nil),
                    isSelected: selectedColor == nil
                )
            }
            .accessibilityValue(selectedColor == nil ? "Selected" : "")
            .buttonStyle(.plain)

            Divider()

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 10)], spacing: 10) {
                ForEach(APICollectionColor.allCases) { color in
                    let isSelected = selectedColor == color

                    Button {
                        store.updateCollectionColor(id: collectionID, color: color)
                        selectedColorCollectionID = nil
                    } label: {
                        Circle()
                            .fill(RequestLabTheme.collectionColor(color))
                            .frame(width: 24, height: 24)
                            .overlay {
                                Circle()
                                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                                    .frame(width: 30, height: 30)
                            }
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption.bold())
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.primary)
                                }
                            }
                            .accessibilityLabel(color.rawValue.capitalized)
                            .accessibilityValue(isSelected ? "Selected" : "")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 220)
    }

    private func colorOptionLabel(title: String, color: Color, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)

            Text(title)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
            }
        }
        .contentShape(Rectangle())
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

    private func historyLabel(_ entry: APIHistoryEntry) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.url)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(entry.method.rawValue)
                        .fontWeight(.semibold)
                        .foregroundStyle(RequestLabTheme.methodColor(entry.method))

                    if let statusCode = entry.statusCode {
                        Text("\(statusCode)")
                            .foregroundStyle(RequestLabTheme.responseColor(statusCode: statusCode))
                    }

                    if let durationMilliseconds = entry.durationMilliseconds {
                        Text("\(durationMilliseconds) ms")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        } icon: {
            Image(systemName: "clock")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
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
            cancelCollectionRename()
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
