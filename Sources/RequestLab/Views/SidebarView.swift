import RequestLabCore
import SwiftUI

struct SidebarView: View {
    @Bindable var store: AppStore
    @State private var sidebarSearchText = ""
    @State private var renamingCollectionID: String?
    @State private var collectionNameDraft = ""
    @FocusState private var isCollectionNameFieldFocused: Bool
    @State private var renamingRequestID: String?
    @State private var requestNameDraft = ""
    @FocusState private var isRequestNameFieldFocused: Bool
    @State private var selectedColorCollectionID: String?
    @State private var pendingDelete: SidebarDeleteTarget?

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
                                        confirmDelete(
                                            .collectionEnvironment(
                                                id: environment.id,
                                                collectionID: collection.id,
                                                name: environment.name
                                            )
                                        )
                                    }
                                }
                        }

                        ForEach(filteredRequests(in: collection)) { request in
                            let rowSelection = CenterPaneSelection.request(request.id)

                            requestLabel(request, isSelected: rowSelection == store.selectedCenterPane)
                                .tag(rowSelection)
                                .contextMenu {
                                    Button("Rename Request") {
                                        startRenamingRequest(request)
                                    }

                                    Button("Duplicate Request") {
                                        store.duplicateRequest(id: request.id)
                                    }

                                    Menu("Move To Collection") {
                                        ForEach(store.workspace.collections) { destinationCollection in
                                            Button(destinationCollection.name) {
                                                store.moveRequest(id: request.id, toCollectionID: destinationCollection.id)
                                            }
                                            .disabled(destinationCollection.id == collection.id)
                                        }
                                    }

                                    Divider()

                                    Button("Move Up") {
                                        moveRequestUp(request, in: collection)
                                    }
                                    .disabled(!canMoveRequestUp(request, in: collection))

                                    Button("Move Down") {
                                        moveRequestDown(request, in: collection)
                                    }
                                    .disabled(!canMoveRequestDown(request, in: collection))

                                    Divider()

                                    Button("Delete Request", role: .destructive) {
                                        confirmDelete(.request(id: request.id, name: request.name))
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
                            confirmDelete(.collection(id: collection.id, name: collection.name))
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
                                confirmDelete(.globalEnvironment(id: environment.id, name: environment.name))
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
        .confirmationDialog(
            pendingDelete?.title ?? "Delete Item",
            isPresented: isDeleteConfirmationPresented,
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { target in
            Button(target.actionTitle, role: .destructive) {
                performDelete(target)
            }

            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { target in
            Text(target.message)
        }
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

    @ViewBuilder
    private func requestLabel(_ request: APIRequest, isSelected: Bool) -> some View {
        if renamingRequestID == request.id {
            TextField("Request name", text: $requestNameDraft)
                .textFieldStyle(.plain)
                .focused($isRequestNameFieldFocused)
                .onSubmit {
                    commitRequestRename()
                }
                .onExitCommand {
                    cancelRequestRename()
                }
                .onChange(of: isRequestNameFieldFocused) { _, isFocused in
                    if !isFocused, renamingRequestID == request.id {
                        cancelRequestRename()
                    }
                }
        } else {
            Label {
                Text(request.name)
                    .fontWeight(isSelected ? .semibold : .regular)
            } icon: {
                Image(systemName: request.kind == .graphQL ? "curlybraces" : "doc.text")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(request.kind == .graphQL ? RequestLabTheme.graphQL : RequestLabTheme.selection)
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

        cancelRequestRename()

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

    private func startRenamingRequest(_ request: APIRequest) {
        if renamingRequestID == request.id {
            isRequestNameFieldFocused = true
            return
        }

        cancelCollectionRename()

        if renamingRequestID != nil {
            cancelRequestRename()
        }

        renamingRequestID = request.id
        requestNameDraft = request.name
        isRequestNameFieldFocused = true
    }

    private func commitRequestRename() {
        guard let requestID = renamingRequestID else {
            return
        }

        let trimmedName = requestNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            store.renameRequest(id: requestID, to: trimmedName)
        }

        renamingRequestID = nil
        requestNameDraft = ""
        isRequestNameFieldFocused = false
    }

    private func cancelRequestRename() {
        renamingRequestID = nil
        requestNameDraft = ""
        isRequestNameFieldFocused = false
    }

    private func requestIndex(_ request: APIRequest, in collection: APICollection) -> Int? {
        collection.requests.firstIndex { $0.id == request.id }
    }

    private func canMoveRequestUp(_ request: APIRequest, in collection: APICollection) -> Bool {
        guard let index = requestIndex(request, in: collection) else {
            return false
        }

        return index > 0
    }

    private func canMoveRequestDown(_ request: APIRequest, in collection: APICollection) -> Bool {
        guard let index = requestIndex(request, in: collection) else {
            return false
        }

        return index < collection.requests.count - 1
    }

    private func moveRequestUp(_ request: APIRequest, in collection: APICollection) {
        guard let index = requestIndex(request, in: collection), index > 0 else {
            return
        }

        store.reorderRequest(id: request.id, toIndex: index - 1)
    }

    private func moveRequestDown(_ request: APIRequest, in collection: APICollection) {
        guard let index = requestIndex(request, in: collection), index < collection.requests.count - 1 else {
            return
        }

        store.reorderRequest(id: request.id, toIndex: index + 1)
    }

    private func confirmDelete(_ target: SidebarDeleteTarget) {
        pendingDelete = target
    }

    private func performDelete(_ target: SidebarDeleteTarget) {
        switch target {
        case .request(let id, _):
            store.deleteRequest(id: id)
        case .collection(let id, _):
            store.deleteCollection(id: id)
        case .globalEnvironment(let id, _):
            store.deleteEnvironment(id: id)
        case .collectionEnvironment(let id, let collectionID, _):
            store.deleteCollectionEnvironment(id: id, fromCollectionID: collectionID)
        }

        pendingDelete = nil
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDelete = nil
                }
            }
        )
    }

    private var selection: Binding<CenterPaneSelection?> {
        Binding(
            get: { store.selectedCenterPane },
            set: { store.selectCenterPane($0) }
        )
    }
}

private enum SidebarDeleteTarget {
    case request(id: String, name: String)
    case collection(id: String, name: String)
    case globalEnvironment(id: String, name: String)
    case collectionEnvironment(id: String, collectionID: String, name: String)

    var title: String {
        switch self {
        case .request:
            "Delete Request?"
        case .collection:
            "Delete Collection?"
        case .globalEnvironment, .collectionEnvironment:
            "Delete Environment?"
        }
    }

    var actionTitle: String {
        switch self {
        case .request:
            "Delete Request"
        case .collection:
            "Delete Collection"
        case .globalEnvironment, .collectionEnvironment:
            "Delete Environment"
        }
    }

    var message: String {
        switch self {
        case .request(_, let name):
            "Delete \"\(name)\"? This cannot be undone."
        case .collection(_, let name):
            "Delete \"\(name)\" and its requests and environments? This cannot be undone."
        case .globalEnvironment(_, let name), .collectionEnvironment(_, _, let name):
            "Delete \"\(name)\"? This cannot be undone."
        }
    }
}
