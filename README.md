# RequestLab

RequestLab is a lightweight open-source macOS API client: a native SwiftUI alternative to Postman for REST and GraphQL workflows.

This repository currently contains the early native app slice. It can build, launch, open and save workspace folders, import Postman collection/environment JSON, create/delete workspace items, edit REST and GraphQL requests, validate requests before send, keep secret variable values in Keychain, round-trip typed workspace data through YAML, resolve environment variables, and execute requests through `URLSession`. Glamour later; load-bearing beams first.

## Current Scope

- Native SwiftUI macOS app shell.
- Three-pane workspace/request/inspector layout.
- Typed workspace, collection, request, environment, variable, auth, body, and history models.
- YAML workspace load/save support.
- REST and GraphQL request execution with environment variable resolution.
- GraphQL query, operation name, and variables payload support.
- Request editing for type, method, URL, params, headers, auth, body, and GraphQL fields.
- Open, Save, and Save As for local `.workspace` folders.
- Postman Collection v2.1 and environment JSON import.
- Create and delete actions for requests, collections, global environments, and collection environments.
- Request validation and JSON formatting helpers.
- Response body and header tabs.
- Keyboard shortcuts for common actions.
- Global and collection-scoped environments with collection variables overriding globals on send.
- Center-pane environment editing with read-only environment summaries in the inspector.
- Keychain-backed values for secret environment variables.
- Response status, duration, headers, body, and local history capture.
- Monochrome macOS app icon generated from the `RL` mark.
- Sample workspace fixture at `Fixtures/SampleWorkspace.workspace`.
- Swift tests for model and persistence behavior.
- Local build/run and release archive scripts for Codex and terminal workflows.

## Planned Follow-Up Slices

- Phase 2 workspace sharing.

## Requirements

- macOS 14 Sonoma or later.
- Xcode command line tools with Swift 6 support.

## Development

Repo instructions require shell commands to be prefixed with `rtk`.

```bash
rtk swift package resolve
rtk swift test
rtk swift build
rtk swift script/generate_app_icon.swift
rtk ./script/build_and_run.sh
rtk ./script/build_and_run.sh --verify
rtk ./script/package_release.sh
```

`script/build_and_run.sh` builds the Swift package, stages a local `.app` bundle under `dist/`, and launches it. The `--verify` mode launches the staged app, checks that the `RequestLab` process is running, and closes it.

`script/generate_app_icon.swift` regenerates `Resources/AppIcon.icns` from a deterministic black-and-beige geometric `RL` mark.

`script/package_release.sh` builds a release `.app`, signs it, creates a zipped macOS archive, and writes a SHA-256 checksum. See `docs/RELEASE.md` for release metadata and Developer ID signing notes.

## Workspace Format

RequestLab workspaces are folders with YAML files:

```text
Example.workspace/
  workspace.yaml
  collections/
    .order.yaml
    orders.yaml
  environments/
    .order.yaml
    local.yaml
  .client/
    history.yaml
```

`workspace.yaml` stores workspace metadata. Collection and environment YAML files hold the shareable workspace content.

`.order.yaml` manifests preserve collection and environment ordering instead of relying on filesystem sort behavior, because filesystem ordering is not a product strategy.

`.client/` stores local-only state such as request history. Treat it as app-private working state rather than shared workspace definition.

Secret environment variables are intentionally written to shared YAML without values. The app stores their runtime values in macOS Keychain using the workspace, environment, and variable identifiers as the lookup key.

Collections can also carry their own inline `environments` list. When a request runs, RequestLab resolves variables from the selected global environment first and then overlays the selected collection environment. If both define the same variable name, the collection environment wins.

## Tests

The current Swift test suite covers:

- Workspace model shape.
- YAML save/load round trips.
- Sample workspace fixture loading.
- Stale YAML cleanup on repeated saves.
- Duplicate generated filename rejection.
- Collection and environment order preservation.
- Collection-scoped environment persistence and legacy collection compatibility.
- Variable identity behavior.
- Request body encoding and decoding.
- Variable resolution and global/collection environment override behavior.
- Mocked REST request execution.
- Mocked GraphQL request execution.
- Nested workspace editing helpers.
- Keychain secret write/read/update/delete behavior.
- Postman collection and environment import mapping.
- Request validation and JSON formatting behavior.

Run the suite with:

```bash
rtk swift test
```
