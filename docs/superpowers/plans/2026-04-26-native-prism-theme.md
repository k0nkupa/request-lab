# Native Prism Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a colorful Native Prism visual system that adapts automatically to macOS Light and Dark appearances.

**Architecture:** Add a small app-target SwiftUI theme helper with semantic colors and reusable surface/status helpers. Apply it surgically to the existing SwiftUI views without touching `RequestLabCore`, workspace persistence, or request execution behavior.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, macOS 14+, `rtk swift build`, `rtk swift test`.

---

## File Structure

- Create: `Sources/RequestLab/Support/RequestLabTheme.swift`
  - Owns semantic app colors, HTTP method colors, response status colors, and small reusable view modifiers.
- Modify: `Sources/RequestLab/App/RequestLabApp.swift`
  - Applies the app tint globally to the window content.
- Modify: `Sources/RequestLab/Views/ContentView.swift`
  - Adds adaptive shell background treatment and tints the environment picker.
- Modify: `Sources/RequestLab/Views/SidebarView.swift`
  - Adds colorful item icons and active environment treatment while preserving selection binding behavior.
- Modify: `Sources/RequestLab/Views/RequestEditorView.swift`
  - Adds method badges, request bar surface, editor surface treatment, primary send styling, and response status colors.
- Modify: `Sources/RequestLab/Views/InspectorView.swift`
  - Adds tinted inspector sections and status-aware response summary.
- Modify: `Sources/RequestLab/Views/EnvironmentEditorView.swift`
  - Adds themed header, variable rows, secret/value visual distinction, and adaptive row surfaces.

No fixture, model, persistence, or request execution files should change.

---

### Task 1: Add Native Prism Theme Helper

**Files:**
- Create: `Sources/RequestLab/Support/RequestLabTheme.swift`

- [ ] **Step 1: Create the support directory**

Run:

```bash
mkdir -p Sources/RequestLab/Support
```

Expected: command exits successfully with no output.

- [ ] **Step 2: Create `RequestLabTheme.swift`**

Create `Sources/RequestLab/Support/RequestLabTheme.swift` with this full content:

```swift
import RequestLabCore
import SwiftUI

enum RequestLabTheme {
    static let tint = Color(nsColor: .controlAccentColor)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevatedSurface = Color(nsColor: .textBackgroundColor)
    static let editorBorder = Color(nsColor: .separatorColor).opacity(0.7)

    static let selection = Color.blue
    static let primaryAction = Color.blue
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.cyan
    static let graphQL = Color.purple
    static let environment = Color.indigo
    static let collection = Color.teal

    static func softFill(_ color: Color) -> Color {
        color.opacity(0.12)
    }

    static func softStroke(_ color: Color) -> Color {
        color.opacity(0.35)
    }

    static func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .get, .head:
            success
        case .post:
            primaryAction
        case .put, .patch:
            warning
        case .delete:
            error
        case .options:
            info
        }
    }

    static func responseColor(statusCode: Int) -> Color {
        switch statusCode {
        case 200..<300:
            success
        case 300..<400:
            info
        case 400..<500:
            warning
        default:
            error
        }
    }
}

struct RequestLabSurface: ViewModifier {
    let tint: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(RequestLabTheme.softFill(tint))
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(RequestLabTheme.softStroke(tint), lineWidth: 1)
            }
    }
}

extension View {
    func requestLabSurface(
        tint: Color = RequestLabTheme.selection,
        cornerRadius: CGFloat = 10
    ) -> some View {
        modifier(RequestLabSurface(tint: tint, cornerRadius: cornerRadius))
    }
}
```

- [ ] **Step 3: Build to catch theme helper errors**

Run:

```bash
rtk swift build
```

Expected: build succeeds.

- [ ] **Step 4: Commit the theme helper**

Run:

```bash
git add Sources/RequestLab/Support/RequestLabTheme.swift
git commit -m "feat: add native prism theme tokens"
```

Expected: commit succeeds.

---

### Task 2: Apply Theme To App Shell And Sidebar

**Files:**
- Modify: `Sources/RequestLab/App/RequestLabApp.swift`
- Modify: `Sources/RequestLab/Views/ContentView.swift`
- Modify: `Sources/RequestLab/Views/SidebarView.swift`

- [ ] **Step 1: Apply global tint in `RequestLabApp`**

In `Sources/RequestLab/App/RequestLabApp.swift`, update the `WindowGroup` content to:

```swift
WindowGroup("RequestLab") {
    ContentView(store: store)
        .frame(minWidth: 980, minHeight: 640)
        .tint(RequestLabTheme.tint)
}
```

- [ ] **Step 2: Add shell background and menu tint in `ContentView`**

In `Sources/RequestLab/Views/ContentView.swift`, update the `HSplitView` detail body to:

```swift
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
```

In the `environmentMenu` label chain, add tint:

```swift
.frame(minWidth: 180)
.tint(RequestLabTheme.environment)
.help("Select global and collection environments")
```

- [ ] **Step 3: Add sidebar icon helpers**

In `Sources/RequestLab/Views/SidebarView.swift`, add these helpers above `private var selection`:

```swift
    private func collectionLabel(_ collection: APICollection) -> some View {
        Label(collection.name, systemImage: "folder")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(RequestLabTheme.collection)
    }

    private func requestLabel(_ request: APIRequest) -> some View {
        Label(request.name, systemImage: request.kind == .graphQL ? "curlybraces" : "doc.text")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(request.kind == .graphQL ? RequestLabTheme.graphQL : RequestLabTheme.selection)
    }

    private func environmentLabel(_ environment: APIEnvironment, isActive: Bool) -> some View {
        Label(environment.name, systemImage: "server.rack")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isActive ? RequestLabTheme.environment : .secondary)
            .fontWeight(isActive ? .semibold : .regular)
    }
```

- [ ] **Step 4: Replace sidebar labels with helpers**

In collection environment rows, replace the existing `Label(environment.name, systemImage: "server.rack")` and its `.foregroundStyle(...)` with:

```swift
environmentLabel(
    environment,
    isActive: environment.id == store.selectedCollectionEnvironment?.id
)
```

In request rows, replace the existing request label with:

```swift
requestLabel(request)
```

In the collection disclosure label, replace:

```swift
Label(collection.name, systemImage: "folder")
```

with:

```swift
collectionLabel(collection)
```

In global environment rows, replace the existing `Label(environment.name, systemImage: "server.rack")` and its `.foregroundStyle(...)` with:

```swift
environmentLabel(
    environment,
    isActive: environment.id == store.selectedGlobalEnvironmentID
)
```

- [ ] **Step 5: Build the shell/sidebar changes**

Run:

```bash
rtk swift build
```

Expected: build succeeds.

- [ ] **Step 6: Commit shell/sidebar changes**

Run:

```bash
git add Sources/RequestLab/App/RequestLabApp.swift Sources/RequestLab/Views/ContentView.swift Sources/RequestLab/Views/SidebarView.swift
git commit -m "feat: theme app shell and sidebar"
```

Expected: commit succeeds.

---

### Task 3: Theme Request Editor And Response Panel

**Files:**
- Modify: `Sources/RequestLab/Views/RequestEditorView.swift`

- [ ] **Step 1: Add method and status badges**

In `Sources/RequestLab/Views/RequestEditorView.swift`, add these helpers above `private var requestKindBinding`:

```swift
    private func methodBadge(_ method: HTTPMethod) -> some View {
        Text(method.rawValue)
            .font(.caption.bold())
            .monospaced()
            .foregroundStyle(RequestLabTheme.methodColor(method))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(RequestLabTheme.softFill(RequestLabTheme.methodColor(method)))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(RequestLabTheme.softStroke(RequestLabTheme.methodColor(method)), lineWidth: 1)
            }
    }

    private func responseStatusBadge(_ response: APIExecutionResult) -> some View {
        let color = RequestLabTheme.responseColor(statusCode: response.statusCode)

        return Text("\(response.statusCode) - \(response.durationMilliseconds) ms")
            .font(.caption.bold())
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(RequestLabTheme.softFill(color))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(RequestLabTheme.softStroke(color), lineWidth: 1)
            }
    }
```

- [ ] **Step 2: Theme the request title and bar**

Replace the top title `HStack` in `body` with:

```swift
HStack(spacing: 10) {
    Image(systemName: request?.kind == .graphQL ? "curlybraces" : "doc.text")
        .foregroundStyle(request?.kind == .graphQL ? RequestLabTheme.graphQL : RequestLabTheme.selection)

    Text(store.editorTitle)
        .font(.title.bold())
        .lineLimit(1)

    Spacer()
}
.padding(.horizontal)
.padding(.top)
```

Update the `requestBar` call chain to:

```swift
requestBar
    .padding()
    .requestLabSurface(tint: request?.kind == .graphQL ? RequestLabTheme.graphQL : RequestLabTheme.selection)
    .padding(.horizontal)
    .padding(.bottom, 12)
```

Remove the old standalone `.padding()` directly attached to `requestBar`.

- [ ] **Step 3: Theme the method picker and send button**

Inside `requestBar`, replace the method picker row with:

```swift
Picker("Method", selection: requestMethodBinding) {
    ForEach(HTTPMethod.allCases, id: \.self) { method in
        methodBadge(method)
            .tag(method)
    }
}
.labelsHidden()
.frame(width: 110)
```

Update the Send button to:

```swift
Button("Send", systemImage: "paperplane.fill") {
    Task {
        await store.sendSelectedRequest()
    }
}
.buttonStyle(.borderedProminent)
.tint(RequestLabTheme.primaryAction)
.disabled(request == nil || store.isSending)
```

- [ ] **Step 4: Theme text editor surfaces**

In every `TextEditor` overlay in `RequestEditorView`, replace:

```swift
RoundedRectangle(cornerRadius: 6)
    .stroke(.separator, lineWidth: 1)
```

with:

```swift
RoundedRectangle(cornerRadius: 8, style: .continuous)
    .stroke(RequestLabTheme.editorBorder, lineWidth: 1)
```

For the raw/JSON body editor `TextEditor`, add this background before `.overlay`:

```swift
.background(RequestLabTheme.elevatedSurface)
```

For the `keyValueEditor` `TextEditor`, the final editor chain should be:

```swift
TextEditor(text: keyValueTextBinding(values))
    .font(.system(.body, design: .monospaced))
    .scrollContentBackground(.hidden)
    .frame(minHeight: 160)
    .background(RequestLabTheme.elevatedSurface)
    .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(RequestLabTheme.editorBorder, lineWidth: 1)
    }
```

- [ ] **Step 5: Theme response panel**

In `responsePanel`, replace the response status `Text` block with:

```swift
if let response = store.latestResponse {
    responseStatusBadge(response)
}
```

At the end of `responsePanel`, before `.frame(minHeight: 220)`, add:

```swift
.requestLabSurface(
    tint: store.latestResponse.map { RequestLabTheme.responseColor(statusCode: $0.statusCode) } ?? RequestLabTheme.info,
    cornerRadius: 12
)
```

The final modifier chain should be:

```swift
.padding()
.requestLabSurface(
    tint: store.latestResponse.map { RequestLabTheme.responseColor(statusCode: $0.statusCode) } ?? RequestLabTheme.info,
    cornerRadius: 12
)
.frame(minHeight: 220)
```

- [ ] **Step 6: Build the request editor changes**

Run:

```bash
rtk swift build
```

Expected: build succeeds.

- [ ] **Step 7: Commit request editor changes**

Run:

```bash
git add Sources/RequestLab/Views/RequestEditorView.swift
git commit -m "feat: theme request editor"
```

Expected: commit succeeds.

---

### Task 4: Theme Inspector And Environment Editor

**Files:**
- Modify: `Sources/RequestLab/Views/InspectorView.swift`
- Modify: `Sources/RequestLab/Views/EnvironmentEditorView.swift`

- [ ] **Step 1: Add inspector section wrapper**

In `Sources/RequestLab/Views/InspectorView.swift`, add this helper above `private var requestSection`:

```swift
    private func inspectorSection<Content: View>(
        _ title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)

            content()
        }
        .padding(12)
        .requestLabSurface(tint: tint)
    }
```

- [ ] **Step 2: Wrap inspector sections**

Replace the body of `requestSection` with:

```swift
inspectorSection("Request", systemImage: "doc.text", tint: RequestLabTheme.selection) {
    if let request {
        LabeledContent("Name", value: request.name)
        LabeledContent("Type", value: request.kind == .graphQL ? "GraphQL" : "REST")
        LabeledContent("Method", value: request.method.rawValue)
        LabeledContent("URL", value: request.url)
        LabeledContent("Headers", value: "\(request.headers.count)")
        LabeledContent("Params", value: "\(request.params.count)")
    } else {
        ContentUnavailableView("No request selected", systemImage: "doc.text")
    }
}
```

Replace the body of `globalEnvironmentSection` with:

```swift
inspectorSection("Global Environment", systemImage: "server.rack", tint: RequestLabTheme.environment) {
    if let globalEnvironment {
        environmentFields(globalEnvironment)
    } else {
        ContentUnavailableView("No global environment selected", systemImage: "server.rack")
    }
}
```

Replace the body of `collectionEnvironmentSection` with:

```swift
inspectorSection("Collection Environment", systemImage: "server.rack", tint: RequestLabTheme.graphQL) {
    if let collectionEnvironment {
        environmentFields(collectionEnvironment)
    } else {
        ContentUnavailableView("No collection environment selected", systemImage: "server.rack")
    }
}
```

Replace the body of `responseSection` with:

```swift
inspectorSection("Last Response", systemImage: "tray.full", tint: response.map { RequestLabTheme.responseColor(statusCode: $0.statusCode) } ?? RequestLabTheme.info) {
    if let response {
        LabeledContent("Status", value: "\(response.statusCode)")
        LabeledContent("Duration", value: "\(response.durationMilliseconds) ms")
        LabeledContent("URL", value: response.url)
        LabeledContent("Headers", value: "\(response.headers.count)")
    } else if let errorMessage {
        Text(errorMessage)
            .foregroundStyle(RequestLabTheme.error)
            .textSelection(.enabled)
    } else {
        ContentUnavailableView("No response", systemImage: "tray")
    }
}
```

- [ ] **Step 3: Remove divider-heavy inspector layout**

In `InspectorView.body`, replace the inner `VStack` content with:

```swift
VStack(alignment: .leading, spacing: 14) {
    requestSection
    globalEnvironmentSection
    collectionEnvironmentSection
    responseSection
}
.padding()
```

This removes the existing `Divider()` calls between sections.

- [ ] **Step 4: Theme environment header**

In `Sources/RequestLab/Views/EnvironmentEditorView.swift`, update `header` to:

```swift
private var header: some View {
    HStack(spacing: 12) {
        Image(systemName: "server.rack")
            .font(.title2)
            .foregroundStyle(RequestLabTheme.environment)
            .symbolRenderingMode(.hierarchical)

        VStack(alignment: .leading, spacing: 6) {
            Text(store.selectedEnvironmentEditorTitle)
                .font(.title.bold())

            Text(environment?.name ?? "No environment")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        Spacer()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
```

- [ ] **Step 5: Theme variable rows**

In `variableRow(environmentID:variable:)`, update the icon block to:

```swift
Image(systemName: variable.isSecret ? "key.horizontal.fill" : "textformat")
    .foregroundStyle(variable.isSecret ? RequestLabTheme.warning : RequestLabTheme.environment)
    .symbolRenderingMode(.hierarchical)
    .frame(width: 18)
```

At the end of the row `HStack`, before the closing brace of the function, add:

```swift
.padding(10)
.requestLabSurface(tint: variable.isSecret ? RequestLabTheme.warning : RequestLabTheme.environment)
```

The row should keep the existing key/value fields and delete button behavior unchanged.

- [ ] **Step 6: Theme the add variable button**

In the `"Add variable"` button label chain, add:

```swift
.buttonStyle(.bordered)
.tint(RequestLabTheme.environment)
```

The resulting button should remain:

```swift
Button {
    store.addEnvironmentVariable(environmentID: environment.id)
} label: {
    Label("Add variable", systemImage: "plus")
}
.buttonStyle(.bordered)
.tint(RequestLabTheme.environment)
```

- [ ] **Step 7: Build the inspector/environment changes**

Run:

```bash
rtk swift build
```

Expected: build succeeds.

- [ ] **Step 8: Commit inspector/environment changes**

Run:

```bash
git add Sources/RequestLab/Views/InspectorView.swift Sources/RequestLab/Views/EnvironmentEditorView.swift
git commit -m "feat: theme inspector and environments"
```

Expected: commit succeeds.

---

### Task 5: Final Verification

**Files:**
- Verify current repository state.

- [ ] **Step 1: Run core tests**

Run:

```bash
rtk swift test
```

Expected: all Swift Testing suites pass.

- [ ] **Step 2: Run app verification script**

Run:

```bash
rtk ./script/build_and_run.sh --verify
```

Expected: script stages `dist/RequestLab.app`, launches it, verifies the process, and exits successfully.

- [ ] **Step 3: Manual visual check**

Open the app in Light appearance and Dark appearance. Verify:

- Sidebar item icons are colored and selected environments are visually active.
- Request editor shows method colors and a prominent Send button.
- Response panel status uses green for `2xx`, cyan for `3xx`, orange for `4xx`, and red for `5xx`.
- Inspector sections are tinted and no longer divider-heavy.
- Environment variables preserve editing, secret fields, and delete behavior.

- [ ] **Step 4: Final status check**

Run:

```bash
git status --short
```

Expected: no unstaged or staged changes after all commits.

If manual visual verification identifies a visual bug, fix it in the smallest touched view file, rerun `rtk swift build`, and commit with:

```bash
git add Sources/RequestLab/App/RequestLabApp.swift Sources/RequestLab/Views/ContentView.swift Sources/RequestLab/Views/SidebarView.swift Sources/RequestLab/Views/RequestEditorView.swift Sources/RequestLab/Views/InspectorView.swift Sources/RequestLab/Views/EnvironmentEditorView.swift Sources/RequestLab/Support/RequestLabTheme.swift
git commit -m "fix: polish native prism theme"
```
