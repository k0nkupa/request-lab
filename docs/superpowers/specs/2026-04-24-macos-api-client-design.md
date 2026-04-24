# macOS API Client Design

Date: 2026-04-24

## Summary

Build a lightweight, open-source, macOS-only Postman alternative. Phase 1 is a normal single-user desktop API client with local workspaces, REST, GraphQL, collections, environments, request history, and Postman import. Phase 2 adds Git-friendly workspace sharing built on the same local file format.

The app will be native SwiftUI, target macOS 14 Sonoma and later, and use modern Apple glass-style system materials where available. The design should stay native first: standard sidebars, toolbars, sheets, commands, and inspectors before any custom glass effect is introduced.

## Goals

- Native macOS app that feels fast, small, and desktop-native.
- Open-source default: MIT license unless a different license is chosen before the first public release.
- REST and GraphQL request authoring and execution.
- Local workspace model with collections, folders, requests, environments, and history.
- Human-readable, Git-friendly workspace files.
- Postman collection and environment import for migration.
- Keychain-backed secrets so workspace files are safe to share.
- Clean architecture with testable request execution, persistence, import, and variable resolution services.

## Non-Goals

- Hosted accounts or cloud sync.
- Real-time collaboration.
- Team roles and permissions.
- Pre-request scripting or response test runtime.
- OpenAPI or Insomnia import in Phase 1.
- Generated API documentation.
- Plugin marketplace or extension runtime.
- Storing secret values in workspace files.

## Product Phases

### Phase 1: Local Desktop App

Phase 1 ships a complete local API client:

- Open, create, and import local workspaces.
- Browse workspaces, collections, folders, saved requests, and history.
- Compose REST requests with method, URL, params, headers, auth, body, and variables.
- Compose GraphQL requests with endpoint, query, operation name, variables, headers, and auth.
- Execute requests through `URLSession`.
- Inspect response status, duration, size, headers, and body.
- Save requests back into local YAML workspace files.
- Import Postman collections and environments.
- Store secrets in macOS Keychain.

Phase 1 Postman import covers the practical migration subset:

- Postman Collection v2.1 JSON.
- Folders and requests.
- Method, URL, query params, headers, and descriptions.
- Raw, form-data, and urlencoded bodies.
- Bearer, basic, and API key auth.
- Postman environment variables.

Postman scripts, tests, monitors, examples, and generated docs are intentionally ignored in Phase 1.

### Phase 2: Share Workspace

Phase 2 optimizes for Git-style sharing, not hosted SaaS:

- Share a workspace folder directly through Git, zip, or file sync.
- Keep stable IDs so diffs and merges are readable.
- Keep local-only history, cache, UI state, and secrets outside shareable files.
- Add import/export affordances for workspace folders and bundles.

Hosted team sync is intentionally out of scope unless the product direction changes from desktop app to SaaS.

## Platform And Visual Direction

The app targets macOS 14 Sonoma and later.

Use native SwiftUI structures:

- `WindowGroup` for the primary app window.
- `Settings` for preferences.
- `NavigationSplitView` for sidebar, editor, and detail composition.
- SwiftUI toolbar and command APIs for desktop actions.
- `@SceneStorage` for window-scoped UI state.
- `@AppStorage` for durable preferences.

Visual direction should follow the latest Apple glass-style language where the OS supports it:

- Let system sidebars, toolbars, sheets, and split views render their native materials.
- Avoid custom opaque backgrounds behind system chrome.
- Use custom glass effects only for app-specific surfaces, such as a compact request bar, environment selector, or focused send controls.
- Keep icons monochrome unless color carries semantic meaning.
- Preserve readable contrast in Light and Dark appearance.

## App Layout

Use a three-pane desktop layout:

- Left sidebar: workspaces, collections, folders, requests, environments, and history.
- Center editor: request composer, response viewer, and request tabs.
- Right inspector: selected environment, variables, auth summary, docs notes, or request metadata.

The inspector should be optional and hideable. The center editor remains the primary work surface.

## Architecture

### App Shell

The SwiftUI app shell owns window composition and desktop affordances:

- Root `NavigationSplitView`.
- Toolbar actions for send, save, import, environment selection, and inspector toggle.
- Command menu items and keyboard shortcuts.
- Settings scene.
- Request tabs and selected item state.

### Domain And Stores

Typed models represent:

- Workspace
- Collection
- Folder
- Request
- Environment
- Variable
- Auth configuration
- Response snapshot
- History entry

Stores should be observable and file-backed. The UI talks to typed stores instead of reading YAML directly.

### Services

Core services:

- `WorkspaceFileStore`: loads and saves workspace folders.
- `RequestExecutionService`: executes REST and GraphQL requests using `URLSession`.
- `VariableResolver`: resolves environment and workspace variables before execution.
- `KeychainSecretStore`: stores and retrieves secret values.
- `PostmanImportService`: imports Postman collections and environments into native models.
- `WorkspaceExportService`: exports native workspace files and JSON where useful.

Small AppKit interop is allowed only where SwiftUI is not good enough, especially for rich text editing or response rendering. It should not become the default app architecture.

## Workspace File Format

Workspaces are plain folders with YAML as the primary format.

Example:

```text
Acme API.workspace/
  workspace.yaml
  collections/
    orders.yaml
    catalog.yaml
  environments/
    local.yaml
    staging.yaml
  examples/
    graphql-orders.yaml
  .client/
    history.yaml
    cache/
    secrets.keychain-ref.yaml
```

Shareable files:

- `workspace.yaml`
- `collections/*.yaml`
- `environments/*.yaml`
- saved REST and GraphQL request definitions
- variable names and non-secret defaults

Local-only files:

- `.client/history.yaml`
- `.client/cache/`
- `.client/secrets.keychain-ref.yaml`
- window and tab UI state

Secrets must not be written into shareable workspace files. Store secret values in macOS Keychain and keep only variable names or Keychain references on disk.

## Request Model

Example REST request:

```yaml
id: req_orders_list
name: List orders
method: GET
url: "{{baseUrl}}/orders"
auth:
  type: bearer
  tokenVariable: apiToken
headers:
  Accept: application/json
params:
  limit: "50"
body:
  type: none
```

GraphQL requests use the same execution model with GraphQL-specific fields:

```yaml
id: req_graphql_orders
name: GraphQL orders
method: POST
url: "{{baseUrl}}/graphql"
graphql:
  operationName: Orders
  query: |
    query Orders($limit: Int!) {
      orders(limit: $limit) {
        id
        status
      }
    }
  variables:
    limit: 50
headers:
  Content-Type: application/json
```

## Error Handling

Errors should keep the request editable and tell the user exactly what failed:

- Invalid URL: block send and show an inline URL error.
- Missing variable: show the unresolved variable name.
- Missing auth secret: prompt to save or select the secret in Keychain.
- Network failure: show the transport error in the response area.
- Non-2xx response: display it as a valid HTTP response, not as an app error.
- Import failure: show file path, source format, and the unsupported field or parse error.

## Testing Strategy

Unit tests:

- YAML load and save.
- Stable IDs.
- Variable resolution.
- Auth configuration.
- GraphQL request shaping.
- Postman import mapping.
- Workspace round-trip tests.

Service tests:

- Mock `URLProtocol` for REST and GraphQL execution.
- Verify request method, URL, headers, body, and timeout behavior.
- Verify response status, headers, body, duration, and error mapping.

UI tests:

- Open workspace.
- Create request.
- Send mocked request.
- Save request.
- Toggle inspector.

Manual macOS pass:

- Keyboard shortcuts.
- Toolbar grouping.
- Sidebar selection stability.
- Inspector show and hide.
- Light and Dark appearance.

## Open Decisions For Implementation Planning

- Whether the first scaffold uses Swift Package Manager directly or an Xcode project.
- Which YAML library to use.
- Whether rich editors start with SwiftUI `TextEditor` or an AppKit-backed text view.
- Exact app name, icon direction, and repository name.
