# RequestLab Full Redesign Spec

Date: 2026-05-11

## Goal

Redesign RequestLab into a credible native macOS API workbench that is comfortable
for daily REST and GraphQL work.

The redesign should keep the product small, local-first, and Git-friendly while
making the core workbench feel complete: create or import a workspace, organize
requests, configure environments, send requests, inspect responses, and reuse
history without editing YAML by hand.

## Product Direction

RequestLab is an open-source SwiftUI macOS app for working with HTTP APIs. The
README describes the current product as a native three-pane workspace for
collections, requests, environments, response inspection, and local request
history. That direction remains the center of the redesign.

Keep:

- Native macOS app behavior built with SwiftUI and Swift Package Manager.
- Three-pane workbench: sidebar, central request/response workspace, and right
  inspector.
- Local `.workspace` folders backed by readable YAML.
- macOS Keychain storage for secret values.
- REST and GraphQL as first-class request types.
- Postman import as an onboarding bridge.
- App-target presentation state in `Sources/RequestLab`.
- Portable request, workspace, execution, validation, variable, import, and
  persistence behavior in `Sources/RequestLabCore`.

Avoid:

- Hosted accounts, billing, sync, teams, or live collaboration.
- A broad plugin marketplace, scripting runtime, or collection test runner in
  this redesign pass.
- Custom window chrome that fights macOS conventions.
- SaaS-style dashboard composition, oversized cards, or marketing-page layouts.
- Visual polish that leaves params, headers, auth, body, response, and history
  workflows underpowered.

## Non-Goals

- No hosted backend.
- No user accounts.
- No live collaboration.
- No script runner in this pass.
- No collection test runner in this pass.
- No custom plugin system in this pass.
- No cloud history.
- No generated API documentation.
- No Phase 2 sharing features until the Phase 1 workbench is coherent.

## Baseline Evidence

Baseline commands were run from the repository root on 2026-05-12:

```bash
rtk swift test
rtk ./script/build_and_run.sh --verify
```

Result: both commands exited `0`. The Swift Testing run reported 57 tests passing
across the core suites.

Files read for the baseline:

- `README.md`
- `docs/superpowers/specs/2026-04-26-remaining-slices-roadmap.md`
- `docs/superpowers/specs/2026-04-26-native-prism-theme-design.md`
- `docs/superpowers/specs/2026-04-26-collection-environments-design.md`
- `docs/superpowers/specs/2026-04-26-collection-sidebar-editing-design.md`
- `Sources/RequestLab/Views/ContentView.swift`
- `Sources/RequestLab/Views/SidebarView.swift`
- `Sources/RequestLab/Views/RequestEditorView.swift`
- `Sources/RequestLab/Views/InspectorView.swift`
- `Sources/RequestLab/Views/EnvironmentEditorView.swift`
- `Sources/RequestLab/Stores/AppStore.swift`
- `Sources/RequestLabCore/Models/WorkspaceModels.swift`

## Current State Notes

The current app already has the right product foundation. The README lists native
SwiftUI macOS UI, REST and GraphQL request editing, environment variables,
Keychain-backed secrets, local YAML workspaces, Postman import, request
validation, URLSession execution, response inspection, local request history, JSON
formatting helpers, and release packaging.

The roadmap records the same foundation and frames the remaining work as vertical
slices: environment editor close-out, request authoring polish, response and
history polish, workspace sharing, and public release hardening. It also states
the important product boundary: Phase 1 is the local desktop API client; Phase 2
is Git-friendly workspace sharing, not SaaS sync.

The current checkout has moved beyond part of the older roadmap wording:

- `ContentView` owns the `NavigationSplitView`, workspace toolbar, import/save
  actions, compact environment menu, and optional inspector.
- `SidebarView` shows collections, collection environments, requests, global
  environments, and history. It already supports collection rename and preset
  color selection.
- `RequestEditorView` has a request header, REST/GraphQL type picker, method and
  URL controls, params, headers, auth, body, and GraphQL tabs, plus a response
  panel with body and headers tabs.
- `InspectorView` is currently a stacked summary surface for request,
  environments, and last response.
- `EnvironmentEditorView` now edits environment name, variable key, non-secret
  value, secret value through Keychain, and variable deletion.
- `AppStore` tracks selected request, selected center pane, selected global and
  collection environments, inspector visibility, send state, latest response,
  and workspace errors.
- `RequestLabCore` models store collections, collection colors, requests,
  request kind, auth, body, GraphQL payload, global and collection environments,
  variables, and history entries.

The redesign should preserve these implemented capabilities while tightening the
daily workflows around them.

## Primary Workflows

1. Create or import a workspace.
2. Create, rename, duplicate, move, reorder, and organize requests.
3. Configure global and collection environments.
4. Store and use secret values without writing them into shared YAML.
5. Author REST requests with structured params, headers, auth, and body editors.
6. Author GraphQL requests with query, variables, operation, headers, and auth.
7. Send requests and inspect response metadata, body, headers, and raw output.
8. Reuse history by opening details, re-running requests, and copying output.
9. Import and export useful formats without leaking secrets or local-only state.

## Target Layout

Use a dense three-pane workbench with a sidebar, central request/response split,
and contextual inspector.

```text
+----------------------+-----------------------------------------------+-----------------------+
| Sidebar              | Request Workbench                             | Inspector             |
| Search               | Method  URL                       Env  Send   | Details               |
| Collections          |                                               | Variables             |
|   Folder             | Params | Headers | Auth | Body | GraphQL      | Resolved              |
|     GET /health      | Structured editors, validation, empty states   | Response              |
| Environments         |                                               |                       |
| History              | Response status strip                         |                       |
|   200 GET /health    | Body | Headers | Cookies | Timeline | Raw     |                       |
+----------------------+-----------------------------------------------+-----------------------+
```

The layout should remain recognizably macOS-native. Use native split behavior,
native controls, and compact workbench density before adding custom presentation.

## Design System

Continue the Native Prism direction already documented for the app:

- System-adaptive surfaces for light and dark appearances.
- Blue primary action and selected workspace state.
- Green success, amber warning, red error, and indigo or cyan environment accents.
- macOS system font for chrome and controls.
- Monospaced font for URLs, headers, bodies, GraphQL, cURL, and raw response.
- Compact 4/8 point rhythm for toolbars, row editors, tabs, and inspector
  sections.
- Visible focus rings, labelled icon buttons, keyboard navigation, readable
  contrast, and no color-only status.

The result should feel like a professional developer workbench, not a marketing
dashboard and not an Electron clone.

## P0 Scope

P0 is the Phase 1 workbench pass. It should make the existing local desktop API
client credible for daily use.

- Workbench shell and navigation polish.
- Sidebar search across collections, requests, environments, and history.
- Request management: rename, duplicate, move, reorder, and confirm destructive
  deletes.
- Structured request authoring for params, headers, auth, REST bodies, and
  GraphQL fields.
- Response viewer polish for metadata, body, headers, raw output, empty states,
  and copy actions.
- History detail and rerun behavior.
- Environment and variable usability across global and collection scopes.
- Keyboard navigation and command affordances for frequent actions.
- Focused RequestLabCore tests where persistence, model behavior, or request
  execution behavior changes.

## P1 Scope

P1 extends the completed local workbench without changing the product shape.

- cURL import and export.
- OpenAPI import.
- Insomnia import.
- Cookie display.
- Redirect and timing details.
- GraphQL schema or docs explorer.
- Workspace sharing contract for Git-friendly folders and bundles, once the
  Phase 1 local client is stable.
- Public release hardening that remains grounded in the actual app surface.

## Workflow Requirements

### Workspace

- Users can create, open, save, and save-as local `.workspace` folders.
- Workspace files remain readable and merge-friendly YAML.
- Shared workspace data excludes secret values and local-only runtime state.
- Local-only history remains under app-private workspace state unless a later
  sharing spec deliberately changes that contract.

### Collections And Requests

- Users can create requests without editing YAML.
- Users can rename, duplicate, move, reorder, and delete requests.
- Users can keep collection color behavior, collection rename behavior, and
  existing workspace compatibility.
- Destructive deletes require confirmation once broader request management is
  implemented.

### Environments And Variables

- Global environments provide shared variables.
- Collection environments override global variables by name.
- Secret variables continue to store runtime values in Keychain using stable
  workspace, environment, and variable identifiers.
- Environment editing remains available from the center pane.
- Inspector variable views redact secrets and distinguish missing, redacted, and
  resolved values clearly.

### REST Authoring

- Params and headers use structured row editing instead of relying only on
  newline-delimited text.
- Auth supports none, bearer, basic, and API key configuration.
- Body editing supports no body, raw text, JSON, form data, and urlencoded data
  when implemented.
- Validation errors are visible, specific, and close to the failing input.

### GraphQL Authoring

- GraphQL requests keep POST defaults and first-class GraphQL payload storage.
- Query, variables JSON, operation name, headers, and auth are easy to edit in
  one coherent workflow.
- Variables formatting and validation remain available.
- GraphQL-specific UI should not make REST requests feel secondary.

### Response Inspection

- Responses show status, duration, URL, headers, and body.
- JSON bodies can be viewed in pretty and raw forms without destroying the raw
  response.
- Copy actions exist for response body, headers, URL, and status where useful.
- Empty, sending, failure, and populated states are visually distinct.
- Response status uses color plus text or labels, never color alone.

### History

- History rows are compact and scannable.
- History detail shows enough context to identify what ran.
- Users can rerun history entries when the underlying request still exists.
- History stays local-only unless a later sharing slice intentionally changes it.

## Implementation Boundaries

- Keep `RequestLabCore` as the owner of portable models, editing helpers,
  persistence, validation, variable resolution, import logic, and request
  execution.
- Keep SwiftUI selection, presentation, split-view state, and transient UI state
  in `RequestLab`.
- Implement vertical slices. Each slice should leave one real workflow better
  rather than spreading shallow polish across the whole app.
- Do not change the workspace format casually. When a format change is required,
  add compatibility tests and update fixture expectations deliberately.
- Do not add infrastructure for accounts, cloud sync, scripting, plugins, or
  test runners as part of this redesign.

## Acceptance Criteria

- A user can create, send, inspect, copy, and rerun REST and GraphQL requests
  without editing YAML.
- Params, headers, auth, body, environments, and collection organization persist
  after save/load.
- Response inspection is useful for debugging real APIs.
- History is useful enough to identify and rerun recent requests.
- Environment layering is understandable and secrets do not leak into shared YAML.
- The app remains native, local-first, and readable in light and dark appearances.
- The redesigned workbench has focused tests for changed core behavior and a
  successful app launch verification before completion.
