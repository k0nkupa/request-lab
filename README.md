# RequestLab

RequestLab is a lightweight open-source macOS API client: a native SwiftUI alternative to Postman for REST and GraphQL workflows.

This repository currently contains the early native app slice. It can build, launch, open and save workspace folders, edit REST and GraphQL requests, keep secret variable values in Keychain, round-trip typed workspace data through YAML, resolve environment variables, and execute requests through `URLSession`. Glamour later; load-bearing beams first.

## Current Scope

- Native SwiftUI macOS app shell.
- Three-pane workspace/request/inspector layout.
- Typed workspace, collection, request, environment, variable, auth, body, and history models.
- YAML workspace load/save support.
- REST and GraphQL request execution with environment variable resolution.
- GraphQL query, operation name, and variables payload support.
- Request editing for type, method, URL, params, headers, auth, body, and GraphQL fields.
- Open, Save, and Save As for local `.workspace` folders.
- Keychain-backed values for secret environment variables.
- Response status, duration, headers, body, and local history capture.
- Sample workspace fixture at `Fixtures/SampleWorkspace.workspace`.
- Swift tests for model and persistence behavior.
- Local build/run script for Codex and terminal workflows.

## Planned Follow-Up Slices

- Postman import.

## Requirements

- macOS 14 Sonoma or later.
- Xcode command line tools with Swift 6 support.

## Development

Repo instructions require shell commands to be prefixed with `rtk`.

```bash
rtk swift package resolve
rtk swift test
rtk swift build
rtk ./script/build_and_run.sh
rtk ./script/build_and_run.sh --verify
```

`script/build_and_run.sh` builds the Swift package, stages a local `.app` bundle under `dist/`, and launches it. The `--verify` mode launches the staged app, checks that the `RequestLab` process is running, and closes it.

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

## Tests

The current Swift test suite covers:

- Workspace model shape.
- YAML save/load round trips.
- Sample workspace fixture loading.
- Stale YAML cleanup on repeated saves.
- Duplicate generated filename rejection.
- Collection and environment order preservation.
- Variable identity behavior.
- Request body encoding and decoding.
- Variable resolution.
- Mocked REST request execution.
- Mocked GraphQL request execution.
- Nested request editing helpers.
- Keychain secret write/read/update/delete behavior.

Run the suite with:

```bash
rtk swift test
```
