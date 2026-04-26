# Collection Sidebar Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add collection right-click actions for inline rename and preset folder-icon color selection in the RequestLab sidebar.

**Architecture:** Store collection color as a small optional preset enum in `RequestLabCore`, expose narrow workspace/AppStore edit helpers, and keep transient rename/popover state inside `SidebarView`. Color rendering stays in the app target through `RequestLabTheme.collectionColor(_:)` so core remains UI-free.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, SwiftPM, RequestLabCore, YAML persistence through `WorkspaceFileStore`.

---

## File Structure

- Modify `Sources/RequestLabCore/Models/WorkspaceModels.swift`
  - Add `APICollectionColor`.
  - Add optional `color` to `APICollection`.
  - Keep legacy decoding compatible by defaulting missing `color` to `nil`.
- Modify `Sources/RequestLabCore/Models/WorkspaceEditing.swift`
  - Add collection mutation, rename, and color helpers.
- Modify `Tests/RequestLabCoreTests/WorkspaceEditingTests.swift`
  - Add focused tests for rename and color helpers.
- Modify `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`
  - Add color round-trip test.
  - Extend legacy decode test to assert missing color is `nil`.
- Modify `Sources/RequestLab/Stores/AppStore.swift`
  - Add UI-facing collection rename/color methods.
- Modify `Sources/RequestLab/Support/RequestLabTheme.swift`
  - Map `APICollectionColor?` to SwiftUI `Color`.
- Modify `Sources/RequestLab/Views/SidebarView.swift`
  - Add context menu actions.
  - Add inline rename state and text field.
  - Add compact preset color popover.

## Task 1: Add Core Collection Editing Tests

**Files:**
- Modify: `Tests/RequestLabCoreTests/WorkspaceEditingTests.swift`

- [ ] **Step 1: Add failing tests for collection rename and color editing**

Insert these tests after `addsAndDeletesCollections()`:

```swift
    @Test("renames collections by id")
    func renamesCollectionsByID() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [APICollection(id: "col_orders", name: "Orders")]
        )

        let didRename = workspace.renameCollection(id: "col_orders", to: "  Customer Orders  ")

        #expect(didRename)
        #expect(workspace.collections.first?.name == "Customer Orders")
    }

    @Test("rename collection rejects empty names")
    func renameCollectionRejectsEmptyNames() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [APICollection(id: "col_orders", name: "Orders")]
        )

        let didRename = workspace.renameCollection(id: "col_orders", to: "   ")

        #expect(!didRename)
        #expect(workspace.collections.first?.name == "Orders")
    }

    @Test("rename collection rejects duplicate save filenames")
    func renameCollectionRejectsDuplicateSaveFilenames() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [
                APICollection(id: "col_foo", name: "Foo Bar"),
                APICollection(id: "col_orders", name: "Orders"),
            ]
        )

        let didRename = workspace.renameCollection(id: "col_orders", to: "Foo/Bar")

        #expect(!didRename)
        #expect(workspace.collections.map(\.name) == ["Foo Bar", "Orders"])
    }

    @Test("sets and clears collection colors")
    func setsAndClearsCollectionColors() {
        var workspace = APIWorkspace(
            id: "wrk",
            name: "Workspace",
            collections: [APICollection(id: "col_orders", name: "Orders")]
        )

        let didSetColor = workspace.updateCollectionColor(id: "col_orders", color: .blue)
        let didClearColor = workspace.updateCollectionColor(id: "col_orders", color: nil)

        #expect(didSetColor)
        #expect(didClearColor)
        #expect(workspace.collections.first?.color == nil)
    }
```

- [ ] **Step 2: Run the focused editing tests and confirm they fail**

Run:

```bash
rtk swift test --filter WorkspaceEditingTests
```

Expected: FAIL with errors like:

```text
value of type 'APIWorkspace' has no member 'renameCollection'
value of type 'APIWorkspace' has no member 'updateCollectionColor'
type 'APICollectionColor?' has no member 'blue'
```

## Task 2: Implement Core Collection Color Model And Editing Helpers

**Files:**
- Modify: `Sources/RequestLabCore/Models/WorkspaceModels.swift`
- Modify: `Sources/RequestLabCore/Models/WorkspaceEditing.swift`
- Test: `Tests/RequestLabCoreTests/WorkspaceEditingTests.swift`

- [ ] **Step 1: Add `APICollectionColor` and `APICollection.color`**

In `Sources/RequestLabCore/Models/WorkspaceModels.swift`, replace the current `APICollection` declaration with this full block:

```swift
public enum APICollectionColor: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case blue
    case green
    case red
    case purple
    case orange
    case cyan
    case indigo
    case pink
    case gray

    public var id: String { rawValue }
}

public struct APICollection: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var color: APICollectionColor?
    public var environments: [APIEnvironment]
    public var requests: [APIRequest]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case environments
        case requests
    }

    public init(
        id: String,
        name: String,
        color: APICollectionColor? = nil,
        environments: [APIEnvironment] = [],
        requests: [APIRequest] = []
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.environments = environments
        self.requests = requests
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.color = try container.decodeIfPresent(APICollectionColor.self, forKey: .color)
        self.environments = try container.decodeIfPresent([APIEnvironment].self, forKey: .environments) ?? []
        self.requests = try container.decodeIfPresent([APIRequest].self, forKey: .requests) ?? []
    }
}
```

- [ ] **Step 2: Add collection editing helpers**

In `Sources/RequestLabCore/Models/WorkspaceEditing.swift`, insert this block after `deleteCollection(id:)`:

```swift
    mutating func updateCollection(id collectionID: String, mutate: (inout APICollection) -> Void) -> Bool {
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionID }) else {
            return false
        }

        mutate(&collections[collectionIndex])
        return true
    }

    mutating func renameCollection(id collectionID: String, to name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return false
        }

        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionID }) else {
            return false
        }

        let proposedFileName = WorkspaceFileNaming.yamlFileName(for: trimmedName)
        let hasFileNameCollision = collections.enumerated().contains { index, collection in
            index != collectionIndex && WorkspaceFileNaming.yamlFileName(for: collection.name) == proposedFileName
        }
        guard !hasFileNameCollision else {
            return false
        }

        collections[collectionIndex].name = trimmedName
        return true
    }

    mutating func updateCollectionColor(id collectionID: String, color: APICollectionColor?) -> Bool {
        updateCollection(id: collectionID) { collection in
            collection.color = color
        }
    }
```

- [ ] **Step 3: Run the focused editing tests**

Run:

```bash
rtk swift test --filter WorkspaceEditingTests
```

Expected: PASS for `WorkspaceEditingTests`.

- [ ] **Step 4: Commit core model and editing helpers**

Run:

```bash
git add Sources/RequestLabCore/Models/WorkspaceModels.swift Sources/RequestLabCore/Models/WorkspaceEditing.swift Tests/RequestLabCoreTests/WorkspaceEditingTests.swift
git commit -m "feat: add collection edit helpers"
```

## Task 3: Add Persistence Coverage For Collection Color

**Files:**
- Modify: `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`
- Test indirectly: `Sources/RequestLabCore/Stores/WorkspaceFileStore.swift`

- [ ] **Step 1: Add failing color round-trip test**

Insert this test after `collectionEnvironmentsRoundTrip()`:

```swift
    @Test("collection colors save and load inline with collections")
    func collectionColorsRoundTrip() throws {
        let tempURL = temporaryWorkspaceURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WorkspaceFileStore(fileManager: .default)
        let workspace = APIWorkspace(
            id: "wrk_collection_color",
            name: "Collection Color Workspace",
            collections: [
                APICollection(
                    id: "col_orders",
                    name: "Orders",
                    color: .purple,
                    requests: [
                        APIRequest(
                            id: "req_orders",
                            name: "Orders",
                            method: .get,
                            url: "https://api.example.test/orders"
                        )
                    ]
                )
            ]
        )

        try store.save(workspace, to: tempURL)
        let loaded = try store.load(from: tempURL)
        let collectionYAML = try String(
            contentsOf: tempURL.appending(path: "collections/orders.yaml"),
            encoding: .utf8
        )

        #expect(loaded == workspace)
        #expect(collectionYAML.contains("color: purple"))
    }
```

- [ ] **Step 2: Extend legacy decode test**

In `legacyCollectionYAMLDecodesWithoutEnvironments()`, add this assertion after the existing `collection.id` expectation:

```swift
        #expect(collection.color == nil)
```

The final test should read:

```swift
    @Test("legacy collection YAML decodes without environments")
    func legacyCollectionYAMLDecodesWithoutEnvironments() throws {
        let data = try #require(
            #"{"id":"col_legacy","name":"Legacy","requests":[]}"#
                .data(using: .utf8)
        )

        let collection = try JSONDecoder().decode(APICollection.self, from: data)

        #expect(collection.id == "col_legacy")
        #expect(collection.color == nil)
        #expect(collection.environments.isEmpty)
    }
```

- [ ] **Step 3: Run the focused file store tests**

Run:

```bash
rtk swift test --filter WorkspaceFileStoreTests
```

Expected: PASS. If the YAML assertion fails due to quoting behavior, inspect `collectionYAML` and keep the assertion exact for the real emitted YAML string.

- [ ] **Step 4: Commit persistence tests**

Run:

```bash
git add Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift
git commit -m "test: cover collection color persistence"
```

## Task 4: Add AppStore Wrappers And Theme Mapping

**Files:**
- Modify: `Sources/RequestLab/Stores/AppStore.swift`
- Modify: `Sources/RequestLab/Support/RequestLabTheme.swift`
- Test: `rtk swift build`

- [ ] **Step 1: Add AppStore collection edit methods**

In `Sources/RequestLab/Stores/AppStore.swift`, insert this block after `deleteCollection(id:)`:

```swift
    func renameCollection(id collectionID: String, to name: String) {
        guard workspace.renameCollection(id: collectionID, to: name) else {
            return
        }

        clearExecutionState()
    }

    func updateCollectionColor(id collectionID: String, color: APICollectionColor?) {
        guard workspace.updateCollectionColor(id: collectionID, color: color) else {
            return
        }

        clearExecutionState()
    }
```

- [ ] **Step 2: Add theme mapping for collection preset colors**

In `Sources/RequestLab/Support/RequestLabTheme.swift`, insert this method after `static let collection = Color.teal`:

```swift
    static func collectionColor(_ color: APICollectionColor?) -> Color {
        switch color {
        case .blue:
            .blue
        case .green:
            .green
        case .red:
            .red
        case .purple:
            .purple
        case .orange:
            .orange
        case .cyan:
            .cyan
        case .indigo:
            .indigo
        case .pink:
            .pink
        case .gray:
            .gray
        case .none:
            collection
        }
    }
```

- [ ] **Step 3: Build to verify app target sees the core enum**

Run:

```bash
rtk swift build
```

Expected: PASS.

- [ ] **Step 4: Commit app state/theme wiring**

Run:

```bash
git add Sources/RequestLab/Stores/AppStore.swift Sources/RequestLab/Support/RequestLabTheme.swift
git commit -m "feat: wire collection color state"
```

## Task 5: Add Inline Rename UI

**Files:**
- Modify: `Sources/RequestLab/Views/SidebarView.swift`
- Test: `rtk swift build`

- [ ] **Step 1: Add sidebar rename state**

At the top of `SidebarView`, below `@Bindable var store: AppStore`, add:

```swift
    @State private var renamingCollectionID: String?
    @State private var collectionNameDraft = ""
    @FocusState private var isCollectionNameFieldFocused: Bool
```

- [ ] **Step 2: Replace the collection label call with rename-aware label**

Replace:

```swift
                    } label: {
                        collectionLabel(collection)
                    }
```

with:

```swift
                    } label: {
                        collectionLabel(collection)
                            .id(collection.id)
                    }
```

- [ ] **Step 3: Add rename action to the collection context menu**

Replace the collection `.contextMenu` block with this full block:

```swift
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
```

`Change Color` is added in Task 6 so this task remains independently buildable.

- [ ] **Step 4: Replace `collectionLabel(_:)` with inline editing support**

Replace the existing `collectionLabel(_:)` function with:

```swift
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
```

- [ ] **Step 5: Add rename helper methods**

Insert these helper methods below `environmentLabel(_:isSelected:isActive:)`:

```swift
    private func startRenamingCollection(_ collection: APICollection) {
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
```

- [ ] **Step 6: Build and fix compile errors**

Run:

```bash
rtk swift build
```

Expected: PASS. If `TextField` focus does not activate immediately, keep the build green and handle polish during manual verification.

- [ ] **Step 7: Commit inline rename UI**

Run:

```bash
git add Sources/RequestLab/Views/SidebarView.swift
git commit -m "feat: add inline collection rename"
```

## Task 6: Add Collection Color Popover UI

**Files:**
- Modify: `Sources/RequestLab/Views/SidebarView.swift`
- Test: `rtk swift build`

- [ ] **Step 1: Add color picker state**

At the top of `SidebarView`, below the rename/focus state, add:

```swift
    @State private var selectedColorCollectionID: String?
```

- [ ] **Step 2: Add the Change Color context menu action**

Replace the collection `.contextMenu` block from Task 5 with:

```swift
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
```

- [ ] **Step 3: Attach popover to the collection label**

Replace the collection label block from Task 5 Step 2 with:

```swift
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
                                collectionColorPicker(for: collection)
                            }
                    }
```

- [ ] **Step 4: Add the color picker view**

Insert this view helper below `collectionLabel(_:)`:

```swift
    private func collectionColorPicker(for collection: APICollection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collection Color")
                .font(.headline)

            Button {
                store.updateCollectionColor(id: collection.id, color: nil)
                selectedColorCollectionID = nil
            } label: {
                colorOptionLabel(
                    title: "Default",
                    color: RequestLabTheme.collectionColor(nil),
                    isSelected: collection.color == nil
                )
            }
            .buttonStyle(.plain)

            Divider()

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 10)], spacing: 10) {
                ForEach(APICollectionColor.allCases) { color in
                    Button {
                        store.updateCollectionColor(id: collection.id, color: color)
                        selectedColorCollectionID = nil
                    } label: {
                        Circle()
                            .fill(RequestLabTheme.collectionColor(color))
                            .frame(width: 24, height: 24)
                            .overlay {
                                if collection.color == color {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .accessibilityLabel(color.rawValue.capitalized)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 220)
    }
```

- [ ] **Step 5: Add default color option label helper**

Insert this helper below `collectionColorPicker(for:)`:

```swift
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
```

- [ ] **Step 6: Build to verify the sidebar compiles**

Run:

```bash
rtk swift build
```

Expected: PASS.

- [ ] **Step 7: Commit color popover UI**

Run:

```bash
git add Sources/RequestLab/Views/SidebarView.swift
git commit -m "feat: add collection color picker"
```

## Task 7: Run Full Verification And Manual App Check

**Files:**
- No new source edits expected.
- Verify all touched files.

- [ ] **Step 1: Run the full test suite**

Run:

```bash
rtk swift test
```

Expected: PASS.

- [ ] **Step 2: Run the app build**

Run:

```bash
rtk swift build
```

Expected: PASS.

- [ ] **Step 3: Run app launch verification**

Run:

```bash
rtk ./script/build_and_run.sh --verify
```

Expected: PASS, including successful app launch/process verification.

- [ ] **Step 4: Manually verify sidebar behavior**

Launch the app if it is not already open:

```bash
rtk ./script/build_and_run.sh
```

Manual checks:

```text
1. Right-click the Orders collection.
2. Choose Rename Collection.
3. Type Customer Orders and press Enter.
4. Confirm the collection name updates inline.
5. Right-click the renamed collection.
6. Choose Rename Collection.
7. Type three spaces and press Enter.
8. Confirm the previous name remains.
9. Right-click the collection and choose Change Color.
10. Select Purple.
11. Confirm only the folder icon changes color.
12. Right-click the collection and choose Change Color.
13. Select Default.
14. Confirm the folder icon returns to the default collection color.
15. Confirm request rows, environment rows, and sidebar selection still behave as before.
```

- [ ] **Step 5: Inspect final diff**

Run:

```bash
git status --short
git diff --stat main...HEAD
```

Expected: only the planned files changed.

## Self-Review Checklist

- Spec coverage:
  - Inline rename from context menu: Task 5.
  - Enter commit and Escape cancel: Task 5.
  - Empty rename cancels: Task 5 and Task 7.
  - Preset color popover with default option: Task 6.
  - Folder-icon-only color treatment: Task 4 and Task 5.
  - YAML persistence and legacy compatibility: Tasks 2 and 3.
  - Focused tests and manual verification: Tasks 1, 3, and 7.
- Placeholder scan: no placeholder markers or open-ended validation steps remain.
- Type consistency:
  - `APICollectionColor` is defined before AppStore/theme/sidebar references use it.
  - `renameCollection(id:to:)` and `updateCollectionColor(id:color:)` signatures match across core and AppStore.
  - `RequestLabTheme.collectionColor(_:)` is used by sidebar and color picker.
