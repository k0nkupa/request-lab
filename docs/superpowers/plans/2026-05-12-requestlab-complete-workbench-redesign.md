# RequestLab Complete Workbench Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild RequestLab into a visibly new native macOS API workbench with Postman-like request authoring, response inspection, mode-based navigation, and a restrained Liquid Glass/material visual system.

**Architecture:** Keep `RequestLabCore` unchanged unless a feature needs durable domain behavior; the redesign is primarily app-target SwiftUI. Split the UI into focused workbench files: top bar, rail, navigator, request builder, response console, inspector, and shared visual system helpers. Gate Liquid Glass by SDK typechecking first, then use a compile-safe native implementation or the material fallback path.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, macOS 14 package target, Swift Testing for `RequestLabCore`, `rtk swift build`, `rtk swift test`, `rtk ./script/build_and_run.sh --verify`.

---

## Current Branch State

Branch: `codex/requestlab-full-redesign-plan`

Existing uncommitted draft files at plan time:
- `Sources/RequestLab/Views/ContentView.swift`
- `Sources/RequestLab/Views/RequestEditorView.swift`
- `Sources/RequestLab/Views/WorkbenchRailView.swift`

Those draft edits are not the approved redesign. During execution, inspect them as reference, then rewrite them into the structure below. Do not commit draft UI changes before they match this plan.

## Design System

RequestLab should feel like a native developer workbench:

- Use a compact top command bar instead of the old macOS toolbar as the primary chrome.
- Use a narrow app rail for Requests, Environments, History, and Commands.
- Use a mode-based navigator beside the rail instead of one mixed sidebar.
- Use split panes for request builder and response console instead of stacked card sections.
- Use semantic method colors: `GET` and `HEAD` green, `POST` blue, `PUT` and `PATCH` amber, `DELETE` red, `OPTIONS` cyan.
- Use semantic response colors: `2xx` green, `3xx` cyan, `4xx` amber, `5xx` red.
- Use monospaced text for URLs, headers, body, GraphQL, cURL, and raw responses.
- Use Liquid Glass only on grouped interactive chrome where the SDK supports it: top command bar controls, rail active state, command palette, response status strip, and compact inspector chips.
- Use native material fallback on macOS SDKs that do not typecheck Liquid Glass APIs.

## Target Layout

```text
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│ RequestLab  workspace.workspace        Global + Collection Env        [Open] [New] [Send] │
├──────┬──────────────────────┬───────────────────────────────────────────────┬──────────────┤
│ Rail │ Navigator            │ Request Workbench                             │ Inspector    │
│ Req  │ Requests search      │ GET  {{baseUrl}}/users              Send      │ Details      │
│ Env  │ Collection tree      │ Params Headers Auth Body GraphQL              │ Variables    │
│ Hist │ Request rows         │ Structured editor                             │ Resolved     │
│ Cmd  │                      ├───────────────────────────────────────────────┤ Response     │
│      │                      │ Response Console                              │              │
│      │                      │ 200  GET  184 ms  14 KB  application/json     │              │
│      │                      │ Pretty Raw Headers                            │              │
└──────┴──────────────────────┴───────────────────────────────────────────────┴──────────────┘
```

## File Structure

Create:
- `Sources/RequestLab/Support/RequestLabVisualSystem.swift`: shared spacing, typography, badge, and glass/material surface helpers.
- `Sources/RequestLab/Views/Workbench/WorkbenchSection.swift`: app rail section enum and labels.
- `Sources/RequestLab/Views/Workbench/WorkbenchTopBar.swift`: workspace, environment, import/export, command palette, send/save controls.
- `Sources/RequestLab/Views/Workbench/WorkbenchRailView.swift`: narrow icon rail for Requests, Environments, History, Command Palette.
- `Sources/RequestLab/Views/Workbench/WorkspaceNavigatorView.swift`: mode-based navigator container.
- `Sources/RequestLab/Views/Workbench/RequestsNavigatorView.swift`: collections and request rows.
- `Sources/RequestLab/Views/Workbench/EnvironmentsNavigatorView.swift`: global and collection environments.
- `Sources/RequestLab/Views/Workbench/HistoryNavigatorView.swift`: compact history rows with rerun/open actions.
- `Sources/RequestLab/Views/RequestWorkbench/RequestWorkbenchView.swift`: request command strip, section rail, builder pane, response console split.
- `Sources/RequestLab/Views/RequestWorkbench/RequestCommandStrip.swift`: request kind, method, URL, environment label, send button.
- `Sources/RequestLab/Views/RequestWorkbench/RequestSectionRail.swift`: Params, Headers, Auth, Body, GraphQL section navigation.
- `Sources/RequestLab/Views/ResponseConsoleView.swift`: response status strip, tabs, copy controls, error/empty states.
- `Sources/RequestLab/Views/ContextInspectorView.swift`: compact contextual inspector replacing large stacked panels.

Modify:
- `Sources/RequestLab/Views/ContentView.swift`: reduce to app-level state, sheets, and layout composition.
- `Sources/RequestLab/Views/RequestEditorView.swift`: replace with a small compatibility wrapper around `RequestWorkbenchView`, then remove unused old layout code.
- `Sources/RequestLab/Views/ResponseViewerView.swift`: either fold into `ResponseConsoleView` or keep as body-rendering subview only.
- `Sources/RequestLab/Views/CommandPaletteView.swift`: apply workbench visual system and glass/material surface.
- `Sources/RequestLab/Views/EnvironmentEditorView.swift`: align environment editing with the new workbench system.
- `Sources/RequestLab/Views/InspectorView.swift`: replace usage with `ContextInspectorView`, then delete or keep as wrapper only during transition.
- `Sources/RequestLab/Support/RequestLabTheme.swift`: keep semantic colors; move layout and surface helpers to `RequestLabVisualSystem.swift`.

Leave unchanged unless compiler errors require a small import or access adjustment:
- `Sources/RequestLabCore/**`
- `Tests/RequestLabCoreTests/**`
- `Fixtures/**`

---

### Task 1: Baseline And Liquid Glass Probe

**Files:**
- Read: `Package.swift`
- Read: `Sources/RequestLab/Support/RequestLabTheme.swift`
- Create: `/tmp/RequestLabGlassProbe.swift`
- No repo file commit in this task unless the probe result is documented in the plan commit.

- [ ] **Step 1: Confirm current package target**

Run:

```bash
rtk sed -n '1,80p' Package.swift
```

Expected evidence:

```text
// swift-tools-version: 6.0
.macOS(.v14)
```

- [ ] **Step 2: Run the native Liquid Glass typecheck probe**

Run:

```bash
cat >/tmp/RequestLabGlassProbe.swift <<'SWIFT'
import SwiftUI

struct RequestLabGlassProbe: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Text("Probe")
                .padding(8)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        } else {
            Text("Probe")
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
SWIFT
rtk swiftc -typecheck /tmp/RequestLabGlassProbe.swift
```

Expected if the installed SDK supports Liquid Glass:

```text
exit code 0
```

Expected if the installed SDK does not support Liquid Glass:

```text
error: value of type 'some View' has no member 'glassEffect'
```

- [ ] **Step 3: Record the branch decision**

If the probe succeeds, use the native implementation in Task 2. If the probe fails, use the material fallback implementation in Task 2 and do not add `.glassEffect` to repo files.

Run:

```bash
rtk git diff -- Sources/RequestLab/Views/ContentView.swift Sources/RequestLab/Views/RequestEditorView.swift Sources/RequestLab/Views/WorkbenchRailView.swift
```

Expected: the diff shows draft UI work only. Use it as reference; the implementation tasks below own the final structure.

---

### Task 2: Visual System Foundation

**Files:**
- Create: `Sources/RequestLab/Support/RequestLabVisualSystem.swift`
- Modify: `Sources/RequestLab/Support/RequestLabTheme.swift`

- [ ] **Step 1: Add the shared visual system file**

Create `Sources/RequestLab/Support/RequestLabVisualSystem.swift` with this compile-safe fallback-first implementation:

```swift
import SwiftUI

enum RequestLabSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum WorkbenchSurfaceKind {
    case chrome
    case pane
    case elevated
    case interactive
}

struct WorkbenchSurfaceModifier: ViewModifier {
    let kind: WorkbenchSurfaceKind
    let cornerRadius: CGFloat
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .background(surfaceFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(surfaceStroke, lineWidth: 1)
            }
    }

    private var surfaceFill: some ShapeStyle {
        switch kind {
        case .chrome:
            return AnyShapeStyle(.bar)
        case .pane:
            return AnyShapeStyle(RequestLabTheme.surface)
        case .elevated:
            return AnyShapeStyle(RequestLabTheme.elevatedSurface)
        case .interactive:
            return AnyShapeStyle((tint ?? RequestLabTheme.selection).opacity(0.12))
        }
    }

    private var surfaceStroke: Color {
        switch kind {
        case .chrome:
            RequestLabTheme.editorBorder.opacity(0.7)
        case .pane:
            RequestLabTheme.editorBorder
        case .elevated:
            RequestLabTheme.editorBorder.opacity(0.8)
        case .interactive:
            RequestLabTheme.softStroke(tint ?? RequestLabTheme.selection)
        }
    }
}

extension View {
    func workbenchSurface(
        _ kind: WorkbenchSurfaceKind = .pane,
        cornerRadius: CGFloat = 8,
        tint: Color? = nil
    ) -> some View {
        modifier(WorkbenchSurfaceModifier(kind: kind, cornerRadius: cornerRadius, tint: tint))
    }
}
```

- [ ] **Step 2: If the Liquid Glass probe succeeded, replace the modifier body with the native branch**

Use this version only when Task 1 typechecked `.glassEffect` successfully:

```swift
func body(content: Content) -> some View {
    if #available(macOS 26.0, *) {
        if kind == .interactive {
            content
                .background(.clear)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    } else {
        content
            .background(surfaceFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(surfaceStroke, lineWidth: 1)
            }
    }
}
```

- [ ] **Step 3: Add compact typography helpers**

Append to `RequestLabVisualSystem.swift`:

```swift
enum RequestLabTextStyle {
    static let chromeTitle = Font.callout.weight(.semibold)
    static let paneTitle = Font.headline.weight(.semibold)
    static let sectionLabel = Font.caption.weight(.semibold)
    static let rowLabel = Font.callout
    static let code = Font.system(.body, design: .monospaced)
    static let codeSmall = Font.system(.caption, design: .monospaced)
}
```

- [ ] **Step 4: Build after visual system creation**

Run:

```bash
rtk swift build
```

Expected: build exits `0`.

- [ ] **Step 5: Commit visual system**

Run:

```bash
git add Sources/RequestLab/Support/RequestLabVisualSystem.swift Sources/RequestLab/Support/RequestLabTheme.swift
git commit -m "style: add requestlab workbench visual system"
```

Expected: commit contains only visual system support.

---

### Task 3: Workbench Sections And Top-Level Shell

**Files:**
- Create: `Sources/RequestLab/Views/Workbench/WorkbenchSection.swift`
- Create: `Sources/RequestLab/Views/Workbench/WorkbenchTopBar.swift`
- Create: `Sources/RequestLab/Views/Workbench/WorkbenchRailView.swift`
- Modify: `Sources/RequestLab/Views/ContentView.swift`

- [ ] **Step 1: Create the section enum**

Create `Sources/RequestLab/Views/Workbench/WorkbenchSection.swift`:

```swift
import SwiftUI

enum WorkbenchSection: String, CaseIterable, Identifiable {
    case requests
    case environments
    case history
    case commands

    var id: String { rawValue }

    var title: String {
        switch self {
        case .requests:
            "Requests"
        case .environments:
            "Environments"
        case .history:
            "History"
        case .commands:
            "Commands"
        }
    }

    var systemImage: String {
        switch self {
        case .requests:
            "arrow.left.arrow.right"
        case .environments:
            "server.rack"
        case .history:
            "clock.arrow.circlepath"
        case .commands:
            "command"
        }
    }
}
```

- [ ] **Step 2: Create the top bar view**

Create `Sources/RequestLab/Views/Workbench/WorkbenchTopBar.swift`:

```swift
import SwiftUI

struct WorkbenchTopBar<Actions: View>: View {
    let workspaceTitle: String
    let environmentTitle: String
    let isSending: Bool
    let canSend: Bool
    let send: () -> Void
    let toggleInspector: () -> Void
    let actions: () -> Actions

    var body: some View {
        HStack(spacing: RequestLabSpacing.md) {
            Label("RequestLab", systemImage: "point.3.connected.trianglepath.dotted")
                .font(RequestLabTextStyle.chromeTitle)
                .symbolRenderingMode(.hierarchical)

            Text(workspaceTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Divider()
                .frame(height: 20)

            Label(environmentTitle, systemImage: "server.rack")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RequestLabTheme.environment)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .workbenchSurface(.interactive, cornerRadius: 8, tint: RequestLabTheme.environment)

            Spacer(minLength: RequestLabSpacing.md)

            actions()

            Button {
                send()
            } label: {
                Label(isSending ? "Sending" : "Send", systemImage: isSending ? "hourglass" : "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(RequestLabTheme.primaryAction)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: .command)

            Button {
                toggleInspector()
            } label: {
                Image(systemName: "sidebar.trailing")
            }
            .buttonStyle(.borderless)
            .help("Toggle inspector")
        }
        .padding(.horizontal, RequestLabSpacing.md)
        .padding(.vertical, RequestLabSpacing.sm)
        .workbenchSurface(.chrome, cornerRadius: 0)
    }
}
```

- [ ] **Step 3: Create the rail view**

Create `Sources/RequestLab/Views/Workbench/WorkbenchRailView.swift`:

```swift
import SwiftUI

struct WorkbenchRailView: View {
    @Binding var selectedSection: WorkbenchSection
    let openCommandPalette: () -> Void

    var body: some View {
        VStack(spacing: RequestLabSpacing.sm) {
            ForEach(WorkbenchSection.allCases) { section in
                Button {
                    if section == .commands {
                        openCommandPalette()
                    } else {
                        selectedSection = section
                    }
                } label: {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 38, height: 34)
                        .foregroundStyle(section == selectedSection ? .primary : .secondary)
                        .workbenchSurface(
                            section == selectedSection ? .interactive : .pane,
                            cornerRadius: 8,
                            tint: section == selectedSection ? RequestLabTheme.selection : nil
                        )
                }
                .buttonStyle(.plain)
                .help(section.title)
                .accessibilityLabel(section.title)
            }

            Spacer()
        }
        .padding(.vertical, RequestLabSpacing.md)
        .frame(maxHeight: .infinity)
        .background(RequestLabTheme.surface)
    }
}
```

- [ ] **Step 4: Wire the top shell in `ContentView`**

Modify `Sources/RequestLab/Views/ContentView.swift`:

```swift
@State private var selectedWorkbenchSection: WorkbenchSection = .requests
```

Replace the outer body split with this composition:

```swift
VStack(spacing: 0) {
    WorkbenchTopBar(
        workspaceTitle: store.workspaceLocationTitle,
        environmentTitle: store.environmentPairTitle,
        isSending: store.isSending,
        canSend: store.selectedRequest != nil && !store.isSending,
        send: {
            Task {
                await store.sendSelectedRequest()
            }
        },
        toggleInspector: {
            store.isInspectorVisible.toggle()
        },
        actions: {
            topBarActions
        }
    )

    Divider()

    HSplitView {
        WorkbenchRailView(
            selectedSection: $selectedWorkbenchSection,
            openCommandPalette: {
                isCommandPalettePresented = true
            }
        )
        .frame(width: 54)

        WorkspaceNavigatorView(
            store: store,
            selectedSection: $selectedWorkbenchSection
        )
        .frame(minWidth: 240, idealWidth: 290, maxWidth: 360)

        centerWorkspace
            .frame(minWidth: 680)
            .background(RequestLabTheme.background)

        if store.isInspectorVisible {
            ContextInspectorView(store: store)
                .frame(minWidth: 270, idealWidth: 320, maxWidth: 390)
                .background(RequestLabTheme.surface)
        }
    }
}
```

- [ ] **Step 5: Move existing toolbar buttons into `topBarActions`**

In `ContentView`, keep the existing open/new/import/save/delete actions but expose them through:

```swift
private var topBarActions: some View {
    HStack(spacing: RequestLabSpacing.xs) {
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
    }
}
```

- [ ] **Step 6: Build shell**

Run:

```bash
rtk swift build
```

Expected: build exits `0`.

- [ ] **Step 7: Commit shell**

Run:

```bash
git add Sources/RequestLab/Views/Workbench/WorkbenchSection.swift Sources/RequestLab/Views/Workbench/WorkbenchTopBar.swift Sources/RequestLab/Views/Workbench/WorkbenchRailView.swift Sources/RequestLab/Views/ContentView.swift
git commit -m "feat: rebuild requestlab workbench shell"
```

Expected: commit contains shell and rail only.

---

### Task 4: Mode-Based Navigator

**Files:**
- Create: `Sources/RequestLab/Views/Workbench/WorkspaceNavigatorView.swift`
- Create: `Sources/RequestLab/Views/Workbench/RequestsNavigatorView.swift`
- Create: `Sources/RequestLab/Views/Workbench/EnvironmentsNavigatorView.swift`
- Create: `Sources/RequestLab/Views/Workbench/HistoryNavigatorView.swift`
- Modify: `Sources/RequestLab/Views/ContentView.swift`
- Read: `Sources/RequestLab/Views/SidebarView.swift`

- [ ] **Step 1: Create the navigator container**

Create `Sources/RequestLab/Views/Workbench/WorkspaceNavigatorView.swift`:

```swift
import SwiftUI

struct WorkspaceNavigatorView: View {
    @Bindable var store: AppStore
    @Binding var selectedSection: WorkbenchSection
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(RequestLabTheme.surface)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: RequestLabSpacing.sm) {
            HStack {
                Label(selectedSection.title, systemImage: selectedSection.systemImage)
                    .font(RequestLabTextStyle.paneTitle)
                    .symbolRenderingMode(.hierarchical)
                Spacer()
            }

            TextField("Search \(selectedSection.title.lowercased())", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding(RequestLabSpacing.md)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .requests, .commands:
            RequestsNavigatorView(store: store, searchText: searchText)
        case .environments:
            EnvironmentsNavigatorView(store: store, searchText: searchText)
        case .history:
            HistoryNavigatorView(store: store, searchText: searchText)
        }
    }
}
```

- [ ] **Step 2: Create request navigator**

Create `Sources/RequestLab/Views/Workbench/RequestsNavigatorView.swift` with request and collection display copied from `SidebarView` behavior:

```swift
import RequestLabCore
import SwiftUI

struct RequestsNavigatorView: View {
    @Bindable var store: AppStore
    let searchText: String

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredCollections: [APICollection] {
        guard !normalizedSearchText.isEmpty else {
            return store.workspace.collections
        }

        return store.workspace.collections.filter { collection in
            collection.name.localizedCaseInsensitiveContains(normalizedSearchText)
                || collection.requests.contains { request in
                    request.name.localizedCaseInsensitiveContains(normalizedSearchText)
                        || request.url.localizedCaseInsensitiveContains(normalizedSearchText)
                        || request.method.rawValue.localizedCaseInsensitiveContains(normalizedSearchText)
                }
        }
    }

    var body: some View {
        List(selection: Binding(
            get: { store.selectedCenterPane },
            set: { store.selectCenterPane($0) }
        )) {
            ForEach(filteredCollections) { collection in
                Section {
                    ForEach(collection.requests) { request in
                        let selection = CenterPaneSelection.request(request.id)
                        Button {
                            store.selectCenterPane(selection)
                        } label: {
                            HStack(spacing: RequestLabSpacing.sm) {
                                Text(request.method.rawValue)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RequestLabTheme.methodColor(request.method))
                                    .frame(width: 48, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(request.name)
                                        .font(.callout)
                                        .lineLimit(1)
                                    Text(request.url)
                                        .font(RequestLabTextStyle.codeSmall)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .tag(selection)
                        .contextMenu {
                            Button("Duplicate Request") {
                                store.duplicateRequest(id: request.id)
                            }
                            Button("Delete Request", role: .destructive) {
                                store.deleteRequest(id: request.id)
                            }
                        }
                    }
                } header: {
                    Label(collection.name, systemImage: "folder")
                        .foregroundStyle(RequestLabTheme.collectionColor(collection.color))
                }
            }
        }
        .listStyle(.sidebar)
    }
}
```

- [ ] **Step 3: Create environments navigator**

Create `Sources/RequestLab/Views/Workbench/EnvironmentsNavigatorView.swift`:

```swift
import RequestLabCore
import SwiftUI

struct EnvironmentsNavigatorView: View {
    @Bindable var store: AppStore
    let searchText: String

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var globalEnvironments: [APIEnvironment] {
        guard !normalizedSearchText.isEmpty else {
            return store.workspace.environments
        }

        return store.workspace.environments.filter { $0.name.localizedCaseInsensitiveContains(normalizedSearchText) }
    }

    var body: some View {
        List(selection: Binding(
            get: { store.selectedCenterPane },
            set: { store.selectCenterPane($0) }
        )) {
            Section("Global") {
                ForEach(globalEnvironments) { environment in
                    environmentRow(
                        environment,
                        selection: .globalEnvironment(environment.id),
                        isActive: environment.id == store.selectedGlobalEnvironmentID
                    )
                }
            }

            ForEach(store.workspace.collections) { collection in
                Section(collection.name) {
                    ForEach(collection.environments) { environment in
                        environmentRow(
                            environment,
                            selection: .collectionEnvironment(collectionID: collection.id, environmentID: environment.id),
                            isActive: store.selectedCollectionEnvironmentIDByCollectionID[collection.id] == environment.id
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func environmentRow(
        _ environment: APIEnvironment,
        selection: CenterPaneSelection,
        isActive: Bool
    ) -> some View {
        Button {
            store.selectCenterPane(selection)
        } label: {
            HStack {
                Label(environment.name, systemImage: isActive ? "checkmark.circle.fill" : "server.rack")
                    .lineLimit(1)
                Spacer()
                Text("\(environment.variables.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .tag(selection)
    }
}
```

- [ ] **Step 4: Create history navigator**

Create `Sources/RequestLab/Views/Workbench/HistoryNavigatorView.swift`:

```swift
import RequestLabCore
import SwiftUI

struct HistoryNavigatorView: View {
    @Bindable var store: AppStore
    let searchText: String

    private var filteredHistory: [APIHistoryEntry] {
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSearchText.isEmpty else {
            return store.workspace.history
        }

        return store.workspace.history.filter { entry in
            entry.url.localizedCaseInsensitiveContains(normalizedSearchText)
                || entry.method.rawValue.localizedCaseInsensitiveContains(normalizedSearchText)
                || entry.requestName?.localizedCaseInsensitiveContains(normalizedSearchText) == true
                || entry.statusCode.map { "\($0)".localizedCaseInsensitiveContains(normalizedSearchText) } == true
        }
    }

    var body: some View {
        List(selection: Binding(
            get: { store.selectedCenterPane },
            set: { store.selectCenterPane($0) }
        )) {
            if filteredHistory.isEmpty {
                ContentUnavailableView("No history", systemImage: "clock")
            } else {
                ForEach(filteredHistory) { entry in
                    let selection = CenterPaneSelection.history(entry.id)
                    Button {
                        store.selectCenterPane(selection)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.method.rawValue)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RequestLabTheme.methodColor(entry.method))
                                if let statusCode = entry.statusCode {
                                    Text("\(statusCode)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RequestLabTheme.responseColor(statusCode: statusCode))
                                }
                                Spacer()
                                Text("\(entry.durationMilliseconds) ms")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Text(entry.requestName ?? entry.url)
                                .font(.callout)
                                .lineLimit(1)
                            Text(entry.url)
                                .font(RequestLabTextStyle.codeSmall)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .buttonStyle(.plain)
                    .tag(selection)
                    .contextMenu {
                        Button("Open Request") {
                            _ = store.openRequestFromHistory(id: entry.id)
                        }
                        Button("Re-run") {
                            Task {
                                await store.rerunHistoryEntry(id: entry.id)
                            }
                        }
                        .disabled(store.isSending)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}
```

- [ ] **Step 5: Remove old `SidebarView` usage**

Confirm `ContentView` uses only `WorkspaceNavigatorView` and no longer instantiates `SidebarView`.

Run:

```bash
rtk rg "SidebarView\\(" Sources/RequestLab
```

Expected:

```text
no matches
```

- [ ] **Step 6: Build navigator**

Run:

```bash
rtk swift build
```

Expected: build exits `0`.

- [ ] **Step 7: Commit navigator**

Run:

```bash
git add Sources/RequestLab/Views/Workbench/WorkspaceNavigatorView.swift Sources/RequestLab/Views/Workbench/RequestsNavigatorView.swift Sources/RequestLab/Views/Workbench/EnvironmentsNavigatorView.swift Sources/RequestLab/Views/Workbench/HistoryNavigatorView.swift Sources/RequestLab/Views/ContentView.swift
git commit -m "feat: add mode-based workspace navigator"
```

Expected: commit contains navigator files and `ContentView` wiring.

---

### Task 5: Request Workbench Builder

**Files:**
- Create: `Sources/RequestLab/Views/RequestWorkbench/RequestWorkbenchView.swift`
- Create: `Sources/RequestLab/Views/RequestWorkbench/RequestCommandStrip.swift`
- Create: `Sources/RequestLab/Views/RequestWorkbench/RequestSectionRail.swift`
- Modify: `Sources/RequestLab/Views/RequestEditorView.swift`

- [ ] **Step 1: Create request section enum and rail**

Create `Sources/RequestLab/Views/RequestWorkbench/RequestSectionRail.swift`:

```swift
import SwiftUI

enum RequestWorkbenchSection: String, CaseIterable, Identifiable {
    case params
    case headers
    case auth
    case body
    case graphQL

    var id: String { rawValue }

    var title: String {
        switch self {
        case .params:
            "Params"
        case .headers:
            "Headers"
        case .auth:
            "Auth"
        case .body:
            "Body"
        case .graphQL:
            "GraphQL"
        }
    }

    var systemImage: String {
        switch self {
        case .params:
            "line.3.horizontal.decrease.circle"
        case .headers:
            "list.bullet.rectangle"
        case .auth:
            "lock"
        case .body:
            "doc.plaintext"
        case .graphQL:
            "curlybraces"
        }
    }
}

struct RequestSectionRail: View {
    @Binding var selectedSection: RequestWorkbenchSection
    let isGraphQLRequest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RequestLabSpacing.xs) {
            Text("Request")
                .font(RequestLabTextStyle.sectionLabel)
                .foregroundStyle(.secondary)
                .padding(.horizontal, RequestLabSpacing.sm)

            ForEach(RequestWorkbenchSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .font(.callout.weight(selectedSection == section ? .semibold : .regular))
                        .foregroundStyle(selectedSection == section ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, RequestLabSpacing.sm)
                        .padding(.vertical, 7)
                        .workbenchSurface(
                            selectedSection == section ? .interactive : .pane,
                            cornerRadius: 7,
                            tint: section == .graphQL ? RequestLabTheme.graphQL : RequestLabTheme.selection
                        )
                }
                .buttonStyle(.plain)
                .disabled(section == .graphQL && !isGraphQLRequest)
            }

            Spacer()
        }
        .padding(RequestLabSpacing.sm)
        .frame(width: 142)
        .background(RequestLabTheme.surface)
    }
}
```

- [ ] **Step 2: Create request command strip**

Create `Sources/RequestLab/Views/RequestWorkbench/RequestCommandStrip.swift`:

```swift
import RequestLabCore
import SwiftUI

struct RequestCommandStrip: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack(spacing: RequestLabSpacing.sm) {
            Picker("Type", selection: requestKindBinding) {
                ForEach(APIRequestKind.allCases, id: \.self) { kind in
                    Label(kind.displayName, systemImage: kind.systemImage)
                        .tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 138)

            Picker("Method", selection: requestMethodBinding) {
                ForEach(HTTPMethod.allCases, id: \.self) { method in
                    Text(method.rawValue)
                        .foregroundStyle(RequestLabTheme.methodColor(method))
                        .tag(method)
                }
            }
            .labelsHidden()
            .frame(width: 112)

            VariableTokenTextField("Request URL", text: requestURLBinding, unresolvedNames: store.unresolvedVariableNames)
                .font(RequestLabTextStyle.code)

            Button {
                Task {
                    await store.sendSelectedRequest()
                }
            } label: {
                Label(store.isSending ? "Sending" : "Send", systemImage: store.isSending ? "hourglass" : "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(RequestLabTheme.primaryAction)
            .controlSize(.large)
            .disabled(store.selectedRequest == nil || store.isSending)
        }
        .padding(RequestLabSpacing.md)
        .workbenchSurface(.chrome, cornerRadius: 0)
    }

    private var requestKindBinding: Binding<APIRequestKind> {
        Binding(
            get: { store.selectedRequest?.kind ?? .rest },
            set: { newValue in
                store.updateSelectedRequest { request in
                    request.kind = newValue
                    if newValue == .graphQL, request.graphQL == nil {
                        request.graphQL = APIGraphQLPayload(query: "", variables: "", operationName: nil)
                    }
                }
            }
        )
    }

    private var requestMethodBinding: Binding<HTTPMethod> {
        Binding(
            get: { store.selectedRequest?.method ?? .get },
            set: { newValue in
                store.updateSelectedRequest { request in
                    request.method = newValue
                }
            }
        )
    }

    private var requestURLBinding: Binding<String> {
        Binding(
            get: { store.selectedRequest?.url ?? "" },
            set: { newValue in
                store.updateSelectedRequest { request in
                    request.url = newValue
                }
            }
        )
    }
}
```

- [ ] **Step 3: Create request workbench view**

Create `Sources/RequestLab/Views/RequestWorkbench/RequestWorkbenchView.swift`. Move the existing request form bindings and editor content from `RequestEditorView` into this view without changing request persistence behavior:

```swift
import RequestLabCore
import SwiftUI

struct RequestWorkbenchView: View {
    @Bindable var store: AppStore
    @State private var selectedSection: RequestWorkbenchSection = .params

    private var request: APIRequest? {
        store.selectedRequest
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            RequestCommandStrip(store: store)
            unresolvedVariablesWarning
            Divider()
            VSplitView {
                builderPanel
                    .frame(minHeight: 300)
                ResponseConsoleView(store: store)
                    .frame(minHeight: 250)
            }
        }
        .background(RequestLabTheme.background)
    }

    private var header: some View {
        HStack(spacing: RequestLabSpacing.sm) {
            Label(store.editorTitle, systemImage: request?.kind == .graphQL ? "curlybraces" : "arrow.left.arrow.right")
                .font(RequestLabTextStyle.paneTitle)
                .symbolRenderingMode(.hierarchical)
                .lineLimit(1)
            Spacer()
            Text(store.environmentPairTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RequestLabTheme.environment)
                .lineLimit(1)
        }
        .padding(.horizontal, RequestLabSpacing.md)
        .padding(.vertical, RequestLabSpacing.sm)
        .background(RequestLabTheme.surface)
    }

    private var builderPanel: some View {
        HStack(spacing: 0) {
            RequestSectionRail(
                selectedSection: $selectedSection,
                isGraphQLRequest: request?.kind == .graphQL
            )

            Divider()

            requestSectionContent
                .padding(RequestLabSpacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(RequestLabTheme.elevatedSurface.opacity(0.55))
        }
    }

    @ViewBuilder
    private var unresolvedVariablesWarning: some View {
        if !store.unresolvedVariableReferences.isEmpty {
            HStack(spacing: RequestLabSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(RequestLabTheme.warning)
                Text("Unresolved variables: \(store.unresolvedVariableReferences.map(\\.name).sorted().joined(separator: \", \"))")
                    .font(.caption)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, RequestLabSpacing.md)
            .padding(.vertical, RequestLabSpacing.sm)
            .background(RequestLabTheme.warning.opacity(0.12))
        }
    }

    @ViewBuilder
    private var requestSectionContent: some View {
        switch selectedSection {
        case .params:
            KeyValueTableEditor(
                title: "Query Params",
                emptyTitle: "No query params",
                emptyDescription: "Add URL query parameters for this request.",
                unresolvedNames: store.unresolvedVariableNames,
                values: paramsBinding
            )
        case .headers:
            KeyValueTableEditor(
                title: "Headers",
                emptyTitle: "No headers",
                emptyDescription: "Add request headers such as Authorization or Content-Type.",
                unresolvedNames: store.unresolvedVariableNames,
                values: headersBinding
            )
        case .auth:
            authEditor
        case .body:
            bodyEditor
        case .graphQL:
            graphQLEditor
        }
    }
}
```

Move the existing `paramsBinding`, `headersBinding`, `authEditor`, `bodyEditor`, and `graphQLEditor` helpers from `RequestEditorView` into `RequestWorkbenchView` exactly once. Do not duplicate those bindings in both files.

- [ ] **Step 4: Replace `RequestEditorView` with a wrapper**

Replace `Sources/RequestLab/Views/RequestEditorView.swift` body with:

```swift
import SwiftUI

struct RequestEditorView: View {
    @Bindable var store: AppStore

    var body: some View {
        RequestWorkbenchView(store: store)
    }
}
```

- [ ] **Step 5: Build request workbench**

Run:

```bash
rtk swift build
```

Expected: build exits `0`.

- [ ] **Step 6: Commit request workbench**

Run:

```bash
git add Sources/RequestLab/Views/RequestWorkbench/RequestWorkbenchView.swift Sources/RequestLab/Views/RequestWorkbench/RequestCommandStrip.swift Sources/RequestLab/Views/RequestWorkbench/RequestSectionRail.swift Sources/RequestLab/Views/RequestEditorView.swift
git commit -m "feat: rebuild request authoring workbench"
```

Expected: commit contains request workbench only.

---

### Task 6: Response Console

**Files:**
- Create: `Sources/RequestLab/Views/ResponseConsoleView.swift`
- Modify: `Sources/RequestLab/Views/ResponseViewerView.swift`
- Modify: `Sources/RequestLab/Views/RequestWorkbench/RequestWorkbenchView.swift`

- [ ] **Step 1: Create response console**

Create `Sources/RequestLab/Views/ResponseConsoleView.swift`:

```swift
import RequestLabCore
import SwiftUI

struct ResponseConsoleView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: RequestLabSpacing.md) {
            header
            content
        }
        .padding(RequestLabSpacing.md)
        .background(RequestLabTheme.surface)
    }

    private var header: some View {
        HStack(spacing: RequestLabSpacing.sm) {
            Label("Response Console", systemImage: "terminal")
                .font(RequestLabTextStyle.paneTitle)
                .symbolRenderingMode(.hierarchical)

            Spacer()

            if store.isSending {
                ProgressView()
                    .controlSize(.small)
                Text("Sending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if let response = store.latestResponse {
                statusBadge("\(response.statusCode)", color: RequestLabTheme.responseColor(statusCode: response.statusCode))
                statusBadge("\(response.durationMilliseconds) ms", color: RequestLabTheme.info)
                statusBadge(formatByteCount(response.bodySizeBytes), color: RequestLabTheme.selection)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let response = store.latestResponse {
            ResponseViewerView(response: response)
        } else if let message = store.executionErrorMessage {
            ContentUnavailableView(
                "Request failed",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No response yet",
                systemImage: "paperplane",
                description: Text("Send the selected request to inspect status, headers, and body.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func statusBadge(_ value: String, color: Color) -> some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .workbenchSurface(.interactive, cornerRadius: 7, tint: color)
    }

    private func formatByteCount(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
```

- [ ] **Step 2: Make `ResponseViewerView` compact**

Modify `Sources/RequestLab/Views/ResponseViewerView.swift` so its tab picker uses a left-aligned compact width and the body does not create an outer card. Keep existing `Pretty`, `Raw`, and `Headers` behavior.

Use this structure:

```swift
VStack(alignment: .leading, spacing: RequestLabSpacing.sm) {
    Picker("Response view", selection: $selectedTab) {
        ForEach(ResponseViewerTab.allCases) { tab in
            Text(tab.title).tag(tab)
        }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .frame(width: 300)

    viewerContent
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workbenchSurface(.elevated, cornerRadius: 8)
}
```

- [ ] **Step 3: Build response console**

Run:

```bash
rtk swift build
```

Expected: build exits `0`.

- [ ] **Step 4: Commit response console**

Run:

```bash
git add Sources/RequestLab/Views/ResponseConsoleView.swift Sources/RequestLab/Views/ResponseViewerView.swift Sources/RequestLab/Views/RequestWorkbench/RequestWorkbenchView.swift
git commit -m "feat: add response console workbench"
```

Expected: commit contains response console changes only.

---

### Task 7: Context Inspector

**Files:**
- Create: `Sources/RequestLab/Views/ContextInspectorView.swift`
- Modify: `Sources/RequestLab/Views/ContentView.swift`
- Read: `Sources/RequestLab/Views/InspectorView.swift`

- [ ] **Step 1: Create context inspector wrapper**

Create `Sources/RequestLab/Views/ContextInspectorView.swift` by moving the useful sections from `InspectorView` into a denser layout:

```swift
import RequestLabCore
import SwiftUI

struct ContextInspectorView: View {
    @Bindable var store: AppStore
    @State private var selectedMode: InspectorMode = .details

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: RequestLabSpacing.md) {
                    modeSelector
                    selectedSection
                }
                .padding(RequestLabSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var header: some View {
        HStack {
            Label("Inspector", systemImage: "sidebar.trailing")
                .font(RequestLabTextStyle.paneTitle)
            Spacer()
        }
        .padding(RequestLabSpacing.md)
        .background(RequestLabTheme.surface)
    }

    private var modeSelector: some View {
        Picker("Inspector mode", selection: $selectedMode) {
            ForEach(InspectorMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder
    private var selectedSection: some View {
        switch selectedMode {
        case .details:
            detailsSection
        case .variables:
            variablesSection
        case .resolved:
            resolvedSection
        case .response:
            responseSection
        }
    }
}
```

Move the existing private helpers from `InspectorView` into this file:
- `detailsSection`
- `variablesSection`
- `resolvedSection`
- `responseSection`
- `formatByteCount(_:)`
- `variableRow(_:)`
- `displayValue(for:)`
- `resolvedPreview(for:)`
- `effectiveEnvironmentWithSecrets()`
- `environmentWithSecrets(_:)`
- `effectiveVariableRows()`
- `redactedSecrets(in:)`
- `errorMessage(for:)`
- `authSummary(for:)`
- `bodySummary(for:)`
- `InspectorMode`
- `EffectiveVariableRow`
- `EffectiveVariableSource`

- [ ] **Step 2: Change section styling**

In `ContextInspectorView`, make each section use this shell instead of large tinted cards:

```swift
private func inspectorSection<Content: View>(
    _ title: String,
    systemImage: String,
    tint: Color,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: RequestLabSpacing.sm) {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.semibold))
            .foregroundStyle(tint)
            .symbolRenderingMode(.hierarchical)

        content()
    }
    .padding(RequestLabSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .workbenchSurface(.elevated, cornerRadius: 8, tint: tint)
}
```

- [ ] **Step 3: Verify `ContentView` points to the new inspector**

Run:

```bash
rtk rg "ContextInspectorView|InspectorView" Sources/RequestLab/Views/ContentView.swift
```

Expected:

```text
ContextInspectorView(store: store)
```

- [ ] **Step 4: Build inspector**

Run:

```bash
rtk swift build
```

Expected: build exits `0`.

- [ ] **Step 5: Commit inspector**

Run:

```bash
git add Sources/RequestLab/Views/ContextInspectorView.swift Sources/RequestLab/Views/ContentView.swift
git commit -m "feat: add contextual workbench inspector"
```

Expected: commit contains inspector changes only.

---

### Task 8: Command Palette And Environment Surface Alignment

**Files:**
- Modify: `Sources/RequestLab/Views/CommandPaletteView.swift`
- Modify: `Sources/RequestLab/Views/EnvironmentEditorView.swift`
- Modify: `Sources/RequestLab/Views/KeyValueTableEditor.swift`

- [ ] **Step 1: Apply workbench surface to command palette**

Modify `CommandPaletteView.body` outer container:

```swift
VStack(alignment: .leading, spacing: RequestLabSpacing.md) {
    TextField("Search commands", text: $searchText)
        .textFieldStyle(.roundedBorder)
        .focused($isSearchFocused)
        .accessibilityLabel("Search commands")

    Divider()

    commandList
}
.padding(RequestLabSpacing.lg)
.frame(width: 460)
.workbenchSurface(.chrome, cornerRadius: 14)
.onAppear {
    isSearchFocused = true
}
```

Extract the existing list into:

```swift
@ViewBuilder
private var commandList: some View {
    if filteredCommands.isEmpty {
        ContentUnavailableView.search
            .frame(height: 220)
    } else {
        ScrollView {
            VStack(spacing: RequestLabSpacing.xs) {
                ForEach(filteredCommands) { command in
                    Button {
                        command.action()
                        dismiss()
                    } label: {
                        HStack(spacing: RequestLabSpacing.sm) {
                            Image(systemName: command.systemImage)
                                .frame(width: 18)
                                .symbolRenderingMode(.hierarchical)

                            Text(command.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, RequestLabSpacing.sm)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!command.isEnabled)
                    .accessibilityLabel(command.title)
                }
            }
        }
        .frame(height: 280)
    }
}
```

- [ ] **Step 2: Align environment editor surfaces**

In `EnvironmentEditorView`, replace old card-like `requestLabSurface` usage with `workbenchSurface(.elevated, cornerRadius: 8, tint: RequestLabTheme.environment)` and keep current bindings unchanged.

Run:

```bash
rtk rg "requestLabSurface" Sources/RequestLab/Views/EnvironmentEditorView.swift Sources/RequestLab/Views/KeyValueTableEditor.swift
```

Expected after edit: no matches in these two files.

- [ ] **Step 3: Build command and environment surfaces**

Run:

```bash
rtk swift build
```

Expected: build exits `0`.

- [ ] **Step 4: Commit surface alignment**

Run:

```bash
git add Sources/RequestLab/Views/CommandPaletteView.swift Sources/RequestLab/Views/EnvironmentEditorView.swift Sources/RequestLab/Views/KeyValueTableEditor.swift
git commit -m "style: align workbench command and environment surfaces"
```

Expected: commit contains visual alignment only.

---

### Task 9: Verification And Manual Product Check

**Files:**
- Read: all modified files
- No new files unless a screenshot artifact is intentionally requested.

- [ ] **Step 1: Run unit tests**

Run:

```bash
rtk swift test
```

Expected: exits `0`.

- [ ] **Step 2: Run build**

Run:

```bash
rtk swift build
```

Expected: exits `0`.

- [ ] **Step 3: Run launch verification**

Run:

```bash
rtk ./script/build_and_run.sh --verify
```

Expected: exits `0` and confirms the app process launches.

- [ ] **Step 4: Launch app for visual check**

Run:

```bash
rtk ./script/build_and_run.sh
```

Expected: `dist/RequestLab.app` launches.

Manual checks:
- First viewport shows rail + mode navigator + request workbench, not the old sidebar-only design.
- Top command bar replaces the old primary toolbar feel.
- Request command strip has method, URL, and Send in one row.
- Params, Headers, Auth, Body, and GraphQL are section-rail driven.
- Response console is visible below the builder.
- Inspector is compact and contextual.
- Command palette opens with `Cmd+K`.
- Send request shortcut `Cmd+Return` still works when a request is selected.
- Delete confirmation still appears before deleting a request.
- Light and dark appearance remain readable.

- [ ] **Step 5: Commit final verification fixes**

If verification required small fixes, commit only those fixes:

```bash
git add Sources/RequestLab
git commit -m "fix: polish workbench redesign verification"
```

Expected: commit contains only fixes made after verification.

---

## Self-Review

Spec coverage:
- Complete redesign direction: covered by Tasks 2 through 8.
- Postman-like usability: covered by mode navigator, request workbench, response console, command palette, and inspector tasks.
- Liquid Glass: covered by Task 1 probe and Task 2 gated visual system.
- Preserve existing features: covered by keeping `AppStore`, `RequestLabCore`, import/export actions, command palette commands, and request bindings.
- Verification: covered by Task 9.

Placeholder scan:
- No task uses an unspecified file path.
- No task asks for generic testing without commands.
- Conditional Liquid Glass path is explicit and compile-gated by the probe.

Type consistency:
- `WorkbenchSection`, `RequestWorkbenchSection`, `WorkbenchTopBar`, `WorkspaceNavigatorView`, `RequestWorkbenchView`, `RequestCommandStrip`, `ResponseConsoleView`, and `ContextInspectorView` names are consistent across tasks.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-12-requestlab-complete-workbench-redesign.md`.

Two execution options:

1. **Subagent-Driven (recommended)** - Dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
