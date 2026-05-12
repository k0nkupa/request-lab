# RequestLab Full Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign RequestLab into a credible native macOS Postman-like API workbench while preserving its local-first, Git-friendly, non-SaaS product direction.

**Architecture:** Keep the current SwiftPM split: `RequestLabCore` owns portable request, workspace, environment, import, and execution behavior; `RequestLab` owns SwiftUI state and presentation. Execute the redesign as vertical slices that improve one real workflow at a time: author request, send request, inspect response, reuse history, manage environments, import/export, and navigate quickly.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, Swift Testing, macOS 14+, `rtk swift test`, `rtk swift build`, `rtk ./script/build_and_run.sh --verify`.

---

## Product Direction

RequestLab should become a dense native macOS developer tool, not a marketing-style app and not an Electron clone.

Keep:
- Three-pane workbench: sidebar, center workspace, right inspector.
- Local `.workspace` folders backed by readable YAML.
- macOS Keychain for secret values.
- Native controls where they fit.
- REST and GraphQL as first-class request types.
- Postman import as an onboarding bridge.

Avoid:
- Hosted accounts, teams, billing, sync, or collaboration.
- A broad plugin marketplace or scripting runtime in the first redesign pass.
- Heavy custom chrome that fights macOS.
- Card-heavy SaaS dashboard styling.
- Visual polish that leaves params, headers, response, and history workflows underpowered.

## Target Workbench Shape

```text
┌──────────────────────┬───────────────────────────────────────────────┬───────────────────────┐
│ Sidebar              │ Request Workbench                             │ Inspector             │
│ Search               │ Method  URL                       Env  Send   │ Request Details       │
│ Collections          │                                               │ Variables             │
│   Folder             │ Params | Headers | Auth | Body | GraphQL      │ Resolved Request      │
│     GET /health      │ Structured editors, validation, empty states   │ Last Response         │
│ Environments         │                                               │                       │
│ History              │ Response status strip                         │                       │
│   200 GET /health    │ Body | Headers | Cookies | Timeline | Raw     │                       │
└──────────────────────┴───────────────────────────────────────────────┴───────────────────────┘
```

## Design System

Use the UI/UX Pro Max direction from the audit:

- Product style: professional developer workbench with restrained micro-interactions.
- Color: system-adaptive surfaces; blue primary action; green success; amber warning; red error; indigo/cyan environment accents.
- Typography: macOS system font for chrome and controls; monospaced font for URL, headers, body, GraphQL, cURL, and raw response.
- Spacing: compact 4/8 point rhythm for toolbars, row editors, and inspector sections.
- Accessibility: visible focus rings, keyboard navigation, labelled icon buttons, no color-only status, readable light/dark contrast.

---

## Milestone 0: Baseline And Redesign Spec

**Purpose:** Freeze the current product baseline, define the redesigned workflows, and prevent the implementation from drifting into unrelated platform work.

**Files:**
- Create: `docs/superpowers/specs/2026-05-11-requestlab-full-redesign.md`
- Read: `README.md`
- Read: `docs/superpowers/specs/2026-04-26-remaining-slices-roadmap.md`
- Read: `Sources/RequestLab/Views/ContentView.swift`
- Read: `Sources/RequestLab/Views/SidebarView.swift`
- Read: `Sources/RequestLab/Views/RequestEditorView.swift`
- Read: `Sources/RequestLab/Views/InspectorView.swift`
- Read: `Sources/RequestLab/Views/EnvironmentEditorView.swift`
- Read: `Sources/RequestLab/Stores/AppStore.swift`
- Read: `Sources/RequestLabCore/Models/WorkspaceModels.swift`

- [ ] **Step 1: Capture baseline evidence**

Run:

```bash
rtk swift test
rtk ./script/build_and_run.sh --verify
```

Expected: both commands exit `0`. If either fails, record the exact failing command and error in the redesign spec before changing code.

- [ ] **Step 2: Write the redesign spec**

Create `docs/superpowers/specs/2026-05-11-requestlab-full-redesign.md` with these sections:

```markdown
# RequestLab Full Redesign Spec

## Goal
Redesign RequestLab into a native macOS API workbench that is comfortable for daily REST and GraphQL work.

## Non-Goals
- No hosted backend.
- No user accounts.
- No live collaboration.
- No script runner in this pass.
- No collection test runner in this pass.
- No custom plugin system in this pass.

## Primary Workflows
1. Create or import a workspace.
2. Create, rename, duplicate, move, and organize requests.
3. Configure environments and secrets.
4. Author REST requests with structured params, headers, auth, and body editors.
5. Author GraphQL requests with query, variables, operation, headers, and auth.
6. Send requests and inspect response metadata, body, headers, and raw output.
7. Reuse history by opening details, re-running requests, and copying output.
8. Import/export useful formats without leaking secrets.

## Target Layout
Use a three-pane workbench with a dense sidebar, central request/response split, and contextual inspector.

## P0 Scope
- Request management polish.
- Structured request authoring.
- Response viewer polish.
- History detail and rerun.
- Environment/variable usability.
- Keyboard navigation and command affordances.

## P1 Scope
- cURL import/export.
- OpenAPI import.
- Insomnia import.
- Cookie display.
- Redirect and timing details.
- GraphQL schema/doc explorer.

## Acceptance Criteria
- A user can create, send, inspect, copy, and rerun REST and GraphQL requests without editing YAML.
- Params, headers, auth, body, environments, and collection organization persist after save/load.
- Response inspection is useful for debugging real APIs.
- History is useful enough to identify and rerun recent requests.
- The app remains native, local-first, and readable in light/dark appearances.
```

- [ ] **Step 3: Commit spec only**

Run:

```bash
git add docs/superpowers/specs/2026-05-11-requestlab-full-redesign.md
git commit -m "docs: define requestlab full redesign"
```

Expected: commit includes only the redesign spec.

---

## Milestone 1: Workbench Shell And Navigation

**Purpose:** Make the app feel like one coherent API workbench before changing deeper editor behavior.

**Files:**
- Modify: `Sources/RequestLab/Views/ContentView.swift`
- Modify: `Sources/RequestLab/Views/SidebarView.swift`
- Modify: `Sources/RequestLab/Views/InspectorView.swift`
- Modify: `Sources/RequestLab/Stores/AppStore.swift`
- Modify: `Sources/RequestLab/Support/RequestLabTheme.swift`
- Add tests only if store selection behavior changes.

**Scope:**
- Replace the loose toolbar feel with a stronger request workbench header in the center pane.
- Add sidebar search/filter over collections, requests, environments, and history.
- Make selected request, selected environment, and active environment state clearer.
- Make history rows compact and scannable: method, status, duration, URL/name, timestamp once available.
- Convert inspector into contextual sections/tabs instead of large stacked tinted panels.
- Preserve current split-view sizing and inspector visibility behavior.

- [ ] **Step 1: Plan the shell split**

Define these view responsibilities before editing:

```text
ContentView: top-level split layout, workspace toolbar, file/import actions.
SidebarView: navigation tree, search, history list, collection/request context menus.
RequestEditorView: request workbench and response panel.
InspectorView: contextual details for request, variables, resolved request, and latest response.
AppStore: selected item state, history selection, filtered search state if needed.
```

- [ ] **Step 2: Add sidebar search without changing persistence**

Add local SwiftUI state to `SidebarView` first. Only move search state into `AppStore` if another view needs it.

Expected behavior:
- Empty search shows all sections.
- Search matches collection name, request name, request URL, environment name, and history URL.
- Search does not mutate the workspace.

- [ ] **Step 3: Add contextual inspector modes**

Add an inspector segmented control or equivalent compact native navigation:

```text
Details | Variables | Resolved | Response
```

Expected behavior:
- Details shows selected request metadata.
- Variables shows effective environment values with secret redaction.
- Resolved shows resolved URL/headers/body preview after validation.
- Response shows last response summary.

- [ ] **Step 4: Verify shell**

Run:

```bash
rtk swift build
rtk swift test
rtk ./script/build_and_run.sh --verify
```

Manual checks:
- Sidebar search does not hide selected rows in a confusing way.
- Inspector can be hidden and shown.
- Window remains usable at current minimum sizes.
- Light and dark appearances remain readable.

---

## Milestone 2: Request Management

**Purpose:** Make collections and requests manageable without touching YAML.

**Files:**
- Modify: `Sources/RequestLab/Views/SidebarView.swift`
- Modify: `Sources/RequestLab/Stores/AppStore.swift`
- Modify: `Sources/RequestLabCore/Models/WorkspaceEditing.swift`
- Test: `Tests/RequestLabCoreTests/WorkspaceEditingTests.swift`
- Test: `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`

**Scope:**
- Rename requests inline or through a focused edit action.
- Duplicate requests.
- Move requests between collections.
- Reorder requests within collections.
- Confirm destructive deletes for requests, collections, and environments.
- Keep collection color behavior intact.

- [ ] **Step 1: Add core editing tests first**

Add tests for:

```text
rename request by id
rename request rejects empty names
duplicate request creates a stable new id and copied editable fields
move request to another collection
reorder request within collection
delete request keeps workspace valid
```

Run:

```bash
rtk swift test --filter WorkspaceEditingTests
```

Expected: new tests fail before implementation.

- [ ] **Step 2: Implement core workspace editing**

Add only the methods required by the tests in `WorkspaceEditing.swift`. Keep logic in `RequestLabCore` so persistence and UI can share the same behavior.

- [ ] **Step 3: Wire UI actions**

Add sidebar context menu actions:

```text
Rename Request
Duplicate Request
Move To Collection
Delete Request
```

Use native confirmation dialogs for destructive deletes.

- [ ] **Step 4: Verify request management**

Run:

```bash
rtk swift test
rtk ./script/build_and_run.sh --verify
```

Manual checks:
- Rename persists after save/load.
- Duplicate request can be edited independently.
- Delete confirmation prevents accidental removal.

---

## Milestone 3: Structured Request Authoring

**Purpose:** Replace fragile raw key/value text blocks with proper Postman-like editors.

**Files:**
- Modify: `Sources/RequestLab/Views/RequestEditorView.swift`
- Create: `Sources/RequestLab/Views/KeyValueTableEditor.swift`
- Create: `Sources/RequestLab/Views/AuthEditorView.swift`
- Create: `Sources/RequestLab/Views/BodyEditorView.swift`
- Modify: `Sources/RequestLab/Stores/AppStore.swift`
- Modify: `Sources/RequestLabCore/Models/WorkspaceModels.swift`
- Modify: `Sources/RequestLabCore/Services/VariableResolver.swift`
- Modify: `Sources/RequestLabCore/Services/RequestValidationService.swift`
- Test: `Tests/RequestLabCoreTests/VariableResolverTests.swift`
- Test: `Tests/RequestLabCoreTests/RequestValidationServiceTests.swift`
- Test: `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`

**Scope:**
- Params editor: enabled checkbox, key, value, description.
- Headers editor: enabled checkbox, key, value, description.
- Form/urlencoded editor: enabled checkbox, key, value, description.
- Raw/JSON editor: monospaced editor, format JSON, validation near editor.
- Auth editor: no auth, bearer, basic, API key; leave OAuth/AWS SigV4 for P1.
- GraphQL editor: query, variables, operation, headers/auth remain visible without fighting REST tabs.
- Inline validation near the field that failed.

- [ ] **Step 1: Decide model compatibility**

Use the least disruptive model that supports disabled rows and descriptions:

```swift
public struct APIKeyValue: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var key: String
    public var value: String
    public var description: String?
    public var isEnabled: Bool
}
```

Migration rule:
- Existing `[String: String]` params/headers/form fields decode into enabled `APIKeyValue` rows.
- Save format may move forward only after fixture tests prove compatibility.

- [ ] **Step 2: Write compatibility tests**

Tests must prove:
- Existing fixture still loads.
- Old params/headers dictionaries decode correctly.
- New key/value rows save and load.
- Disabled rows do not resolve into sent URL/header/body output.

- [ ] **Step 3: Build reusable key/value table editor**

Create `KeyValueTableEditor` with:

```text
enabled toggle
key text field
value field with variable token support where useful
description field or disclosure
row add
row delete
keyboard tab order
empty state
```

- [ ] **Step 4: Replace Params, Headers, and Form Body tabs**

Replace calls to the current raw `keyValueEditor` with the table editor.

- [ ] **Step 5: Split auth/body editors into focused views**

Keep `RequestEditorView` as the composition surface. Move auth and body internals into focused files so the main request view does not keep growing.

- [ ] **Step 6: Verify authoring**

Run:

```bash
rtk swift test
rtk swift build
rtk ./script/build_and_run.sh --verify
```

Manual checks:
- Create and send GET with params.
- Create and send POST JSON.
- Create and send form body.
- Configure bearer auth from an environment variable.
- GraphQL query and variables remain usable.
- Save/load preserves all edits.

---

## Milestone 4: Response Viewer And Debugging Loop

**Purpose:** Make the result of a request useful for actual debugging.

**Files:**
- Modify: `Sources/RequestLabCore/Services/RequestExecutionService.swift`
- Modify: `Sources/RequestLabCore/Models/WorkspaceModels.swift`
- Modify: `Sources/RequestLab/Views/RequestEditorView.swift`
- Create: `Sources/RequestLab/Views/ResponseViewerView.swift`
- Create: `Sources/RequestLab/Views/ResponseMetadataBar.swift`
- Modify: `Sources/RequestLab/Views/InspectorView.swift`
- Test: `Tests/RequestLabCoreTests/RequestExecutionServiceTests.swift`
- Test: `Tests/RequestLabCoreTests/JSONFormattingServiceTests.swift`

**Scope:**
- Metadata strip: status, duration, size, content type, final URL.
- Body modes: pretty JSON, raw text.
- Headers table.
- Copy actions: status, URL, headers, body, cURL-like summary.
- Empty, loading, error, non-2xx, and binary-ish body states.
- Preserve raw body; pretty view must not mutate response data.

- [ ] **Step 1: Extend execution result metadata**

Add response size and content type to `APIExecutionResult`.

- [ ] **Step 2: Write execution metadata tests**

Tests must cover:
- status is preserved.
- non-2xx does not throw.
- response headers are available.
- body byte size is computed consistently.
- content type comes from headers when present.

- [ ] **Step 3: Create response viewer components**

Move response rendering out of `RequestEditorView` into `ResponseViewerView`.

Tabs:

```text
Pretty | Raw | Headers
```

Optional P1 tabs:

```text
Cookies | Timeline
```

- [ ] **Step 4: Add copy affordances**

Every copy button must have a visible label or accessibility label and must not rely on color only.

- [ ] **Step 5: Verify response loop**

Run:

```bash
rtk swift test
rtk ./script/build_and_run.sh --verify
```

Manual checks:
- 2xx, 4xx, and request failure states are visually distinct.
- JSON can be viewed pretty and raw.
- Copy body/headers works.
- Response panel remains readable in compact and wide windows.

---

## Milestone 5: History As A First-Class Workflow

**Purpose:** Turn history from a URL list into a practical run log.

**Files:**
- Modify: `Sources/RequestLabCore/Models/WorkspaceModels.swift`
- Modify: `Sources/RequestLab/Stores/AppStore.swift`
- Modify: `Sources/RequestLab/Views/SidebarView.swift`
- Create: `Sources/RequestLab/Views/HistoryDetailView.swift`
- Test: `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`
- Test: `Tests/RequestLabCoreTests/WorkspaceEditingTests.swift`

**Scope:**
- Store enough metadata to scan: timestamp, request name if available, method, URL, status, duration.
- Select a history item and show details.
- Re-run from history when the underlying request still exists.
- Open the original request from history.
- Keep history local-only and avoid leaking secrets.

- [ ] **Step 1: Extend `APIHistoryEntry`**

Add:

```swift
public var createdAt: Date
public var requestName: String?
public var responseSizeBytes: Int?
public var contentType: String?
```

Keep decode compatibility by defaulting missing values.

- [ ] **Step 2: Write history compatibility tests**

Tests must cover old history entries and new metadata entries.

- [ ] **Step 3: Add history selection state**

Add selected history state to `AppStore` only if sidebar detail routing needs it.

- [ ] **Step 4: Add history detail UI**

History detail should show:

```text
method
URL
request name
status
duration
timestamp
actions: Open Request, Re-run, Copy URL
```

- [ ] **Step 5: Verify history**

Run:

```bash
rtk swift test
rtk ./script/build_and_run.sh --verify
```

Manual checks:
- Run at least two requests and confirm history order.
- Select history entry and open detail.
- Re-run works when request exists.
- Deleted request history shows clear unavailable state.

---

## Milestone 6: Environments And Variable Confidence

**Purpose:** Make environment use obvious and prevent hidden variable mistakes.

**Files:**
- Modify: `Sources/RequestLab/Views/EnvironmentEditorView.swift`
- Modify: `Sources/RequestLab/Views/InspectorView.swift`
- Modify: `Sources/RequestLab/Views/VariableTokenTextField.swift`
- Modify: `Sources/RequestLab/Stores/AppStore.swift`
- Modify: `Sources/RequestLabCore/Services/VariableResolver.swift`
- Test: `Tests/RequestLabCoreTests/VariableResolverTests.swift`
- Test: `Tests/RequestLabCoreTests/KeychainSecretStoreTests.swift`

**Scope:**
- Show active global + collection environment clearly near the request URL.
- Show resolved variable preview in inspector.
- Highlight unresolved tokens before send.
- Improve secret value editing so users understand Keychain behavior.
- Add duplicate variable-name warnings within merged effective environment.

- [ ] **Step 1: Add unresolved-token detection tests**

Variable resolver tests must cover unresolved URL, header, auth, body, and GraphQL variable tokens.

- [ ] **Step 2: Add effective environment preview**

Inspector Variables tab should show:

```text
effective key
source: global or collection
value preview or secret redaction
override indicator when collection value replaces global value
```

- [ ] **Step 3: Add field-level unresolved warnings**

Warnings must appear before send and near the relevant editor section.

- [ ] **Step 4: Verify environments**

Run:

```bash
rtk swift test
rtk ./script/build_and_run.sh --verify
```

Manual checks:
- Global variable resolves.
- Collection variable overrides global variable.
- Missing variable is visible before send.
- Secret values stay out of saved YAML.

---

## Milestone 7: Import, Export, And Interop

**Purpose:** Make RequestLab easy to adopt from real API-client workflows.

**Files:**
- Modify: `Sources/RequestLab/Views/ContentView.swift`
- Modify: `Sources/RequestLab/Stores/AppStore.swift`
- Modify: `Sources/RequestLabCore/Services/PostmanImportService.swift`
- Create: `Sources/RequestLabCore/Services/CurlExportService.swift`
- Create: `Sources/RequestLabCore/Services/CurlImportService.swift`
- Create: `Sources/RequestLabCore/Services/WorkspaceExportService.swift`
- Test: `Tests/RequestLabCoreTests/PostmanImportServiceTests.swift`
- Test: `Tests/RequestLabCoreTests/CurlImportServiceTests.swift`
- Test: `Tests/RequestLabCoreTests/CurlExportServiceTests.swift`
- Test: `Tests/RequestLabCoreTests/WorkspaceFileStoreTests.swift`

**Scope:**
- Keep Postman import.
- Add copy as cURL/export cURL for selected request.
- Add import from cURL text.
- Add workspace bundle export/import for the shareable subset.
- Defer OpenAPI and Insomnia import to P1 unless this milestone has spare capacity.

- [ ] **Step 1: Add cURL export tests**

Tests must prove method, URL, headers, body, and auth output are represented without secret values unless explicitly resolved at runtime.

- [ ] **Step 2: Add cURL import tests**

Tests must cover a small practical subset:

```text
curl -X POST
-H header
--data JSON
URL
```

- [ ] **Step 3: Add UI import/export actions**

Add actions under the existing import/create toolbar pattern. Do not add a new top-level navigation section.

- [ ] **Step 4: Verify interop**

Run:

```bash
rtk swift test
rtk ./script/build_and_run.sh --verify
```

Manual checks:
- Copy cURL from current request.
- Import cURL into a new request.
- Save/load imported request.

---

## Milestone 8: Command Palette, Search, And Keyboard Flow

**Purpose:** Make the redesigned app efficient for repeated daily use.

**Files:**
- Modify: `Sources/RequestLab/Views/ContentView.swift`
- Modify: `Sources/RequestLab/Views/SidebarView.swift`
- Modify: `Sources/RequestLab/Views/RequestEditorView.swift`
- Create: `Sources/RequestLab/Views/CommandPaletteView.swift`
- Modify: `Sources/RequestLab/Stores/AppStore.swift`

**Scope:**
- Command palette for create request, create collection, open workspace, save, import, send, toggle inspector, search requests.
- Keyboard shortcuts for common actions.
- Focus order through method, URL, params, headers, body, send.
- Accessible labels for icon-only toolbar buttons.

- [ ] **Step 1: Define command list**

Initial command list:

```text
Open Workspace
Save Workspace
Save Workspace As
Import Postman Collection
Import Postman Environment
New Request
New GraphQL Request
New Collection
New Environment
Send Request
Toggle Inspector
Search Requests
Copy Response Body
Copy Response Headers
Copy as cURL
```

- [ ] **Step 2: Add command palette UI**

Use a native sheet or popover. Keep it keyboard-first and avoid custom visual complexity.

- [ ] **Step 3: Verify keyboard flow**

Manual checks:
- Command palette opens and closes with keyboard.
- Sending request remains available with `Command-Return`.
- Delete remains protected by confirmation for destructive actions.
- VoiceOver labels for icon buttons are meaningful.

---

## Milestone 9: Visual System And Accessibility Pass

**Purpose:** Apply a coherent final visual layer after workflows are functionally stronger.

**Files:**
- Modify: `Sources/RequestLab/Support/RequestLabTheme.swift`
- Modify: `Sources/RequestLab/Views/ContentView.swift`
- Modify: `Sources/RequestLab/Views/SidebarView.swift`
- Modify: `Sources/RequestLab/Views/RequestEditorView.swift`
- Modify: `Sources/RequestLab/Views/InspectorView.swift`
- Modify: `Sources/RequestLab/Views/EnvironmentEditorView.swift`
- Modify all new view files created by earlier milestones.

**Scope:**
- Normalize spacing.
- Normalize icon sizes and stroke style.
- Ensure all icon-only buttons have labels/tooltips.
- Improve light/dark contrast.
- Remove nested-card feeling from the inspector.
- Ensure text does not overlap or truncate badly at supported window sizes.
- Respect reduced motion if animations are introduced.

- [ ] **Step 1: Run visual inventory**

Use this checklist:

```text
No emoji structural icons.
No color-only status.
All icon buttons labelled.
All destructive actions visually separated.
All focusable controls have visible focus.
Light/dark contrast checked manually.
No horizontal clipping at minimum window size.
No nested card stacks in main page sections.
```

- [ ] **Step 2: Apply visual cleanup only after workflow slices**

Do not use this milestone to sneak in data-model or execution behavior changes.

- [ ] **Step 3: Verify final UI pass**

Run:

```bash
rtk swift test
rtk swift build
rtk ./script/build_and_run.sh --verify
```

Manual checks:
- Light appearance.
- Dark appearance.
- Minimum window with inspector visible.
- Minimum window with inspector hidden.
- REST request.
- GraphQL request.
- Environment editor.
- Response with success and error states.

---

## Milestone 10: Release Hardening

**Purpose:** Make the redesigned app credible as a public baseline.

**Files:**
- Modify: `README.md`
- Modify: `docs/RELEASE.md`
- Modify: `docs/agentic-documentation-reference.md`
- Modify: `Fixtures/SampleWorkspace.workspace/`
- Optional create: `SECURITY.md`
- Optional create: `.github/workflows/test.yml`

**Scope:**
- Update screenshots after redesign.
- Update feature list to match implemented behavior.
- Document unsupported features plainly.
- Document workspace sharing and secret behavior.
- Keep sample workspace useful for first launch.
- Add or update CI only if repository policy wants it.

- [ ] **Step 1: Refresh docs from actual implemented behavior**

Do not advertise OAuth, scripting, collection runner, OpenAPI import, or team sync unless implemented.

- [ ] **Step 2: Refresh sample workspace**

Only update fixture data when workspace format or default experience intentionally changes.

- [ ] **Step 3: Final validation**

Run:

```bash
rtk swift test
rtk swift build
rtk ./script/build_and_run.sh --verify
rtk ./script/package_release.sh
```

Expected:
- tests pass.
- build passes.
- app launch verify passes.
- release package script exits `0`.

---

## Recommended Execution Order

1. Milestone 0: Baseline And Redesign Spec.
2. Milestone 1: Workbench Shell And Navigation.
3. Milestone 2: Request Management.
4. Milestone 3: Structured Request Authoring.
5. Milestone 4: Response Viewer And Debugging Loop.
6. Milestone 5: History As A First-Class Workflow.
7. Milestone 6: Environments And Variable Confidence.
8. Milestone 7: Import, Export, And Interop.
9. Milestone 8: Command Palette, Search, And Keyboard Flow.
10. Milestone 9: Visual System And Accessibility Pass.
11. Milestone 10: Release Hardening.

## Cut Lines

If the full redesign needs to be reduced, keep this minimum:

```text
Milestone 1: Workbench Shell And Navigation
Milestone 2: Request Management
Milestone 3: Structured Request Authoring
Milestone 4: Response Viewer And Debugging Loop
Milestone 5: History As A First-Class Workflow
Milestone 9: Visual System And Accessibility Pass
```

Defer these first:

```text
OpenAPI import
Insomnia import
GraphQL schema explorer
Cookies/timeline deep detail
Command palette
Workspace bundle export/import
CI changes
```

## Verification Standard

Every milestone must end with:

```bash
rtk swift test
rtk swift build
rtk ./script/build_and_run.sh --verify
```

Every UI milestone also needs a manual app pass covering:

```text
Light appearance
Dark appearance
Minimum window size
Wide window size
Inspector hidden
Inspector visible
REST request path
GraphQL request path
Save/load persistence when data changed
```

## Completion Criteria

The full redesign is complete when:

- A new user can import or create a workspace and send a request without editing YAML.
- A user can manage collections and requests from the UI.
- Params, headers, auth, body, GraphQL, and environments have structured editing.
- Responses provide enough metadata and body/header tooling for debugging.
- History supports scan, select, open, and rerun.
- Secrets remain in Keychain and out of shared files.
- Light and dark modes are readable and polished.
- The README and release docs describe only implemented behavior.
- `rtk swift test`, `rtk swift build`, and `rtk ./script/build_and_run.sh --verify` pass.
