# Remaining Slices Roadmap

Date: 2026-04-26

## Context

RequestLab is a lightweight, open-source, macOS-only Postman alternative. The product direction is already split into two major phases:

- Phase 1: local desktop API client.
- Phase 2: Git-friendly workspace sharing.

The app already has the core Phase 1 foundation: SwiftUI shell, local workspace persistence, REST and GraphQL request execution, Postman import, global and collection environments, Keychain-backed secrets, release packaging scripts, and an initial public-facing README.

The remaining work should be tracked as vertical slices so each slice leaves the app more usable, testable, and shippable. This document records the remaining slices, recommended order, and done criteria.

## Goals

- Make the remaining work explicit enough that an agent or maintainer can pick up the next slice without reading the full conversation history.
- Keep Phase 1 polish separate from Phase 2 sharing.
- Avoid accidentally expanding Phase 2 into hosted accounts, live collaboration, or SaaS sync.
- Preserve the app's lightweight macOS-native direction.
- Keep every slice small enough to verify with focused Swift tests and a real app launch.

## Non-Goals

- No hosted backend.
- No user accounts.
- No real-time collaboration.
- No team roles or permissions.
- No OpenAPI or Insomnia import before the Phase 1 public baseline is clean.
- No plugin marketplace, scripting runtime, or generated API docs.

## Current Status

Phase 1 is functional but still needs polish before it should be treated as a clean public baseline.

Implemented or substantially implemented:

- Native SwiftUI macOS app shell.
- Sidebar, center workspace, and inspector layout.
- REST request authoring and execution.
- GraphQL request authoring and execution.
- Local YAML workspace persistence.
- Postman collection and environment import.
- Global environments.
- Collection environments.
- Environment variable resolution with collection overrides.
- Keychain-backed secret variables.
- App icon and release packaging scripts.
- Initial README and release docs.

In progress:

- Environment editor center-pane polish: add variable, delete variable, edit key, edit value, and edit environment name.

## Remaining Slice Count

Recommended count: five remaining slices.

If the in-progress environment editor work is already committed, count four remaining slices.

```text
Slice 0: Environment editor close-out
Slice 1: Request authoring polish
Slice 2: Response and history polish
Slice 3: Phase 2 workspace sharing
Slice 4: Public release hardening
```

## Recommended Order

### Slice 0: Environment Editor Close-Out

Purpose: finish the current environment editing surface so global and collection environments feel complete in the center workspace.

Scope:

- Edit environment name.
- Add a new variable row.
- Edit variable key.
- Edit non-secret variable value.
- Edit secret variable value through secure input backed by Keychain.
- Delete variable rows.
- Keep the right inspector read-only for environment values.
- Preserve global and collection environment behavior.

Done criteria:

- Global environment editing works from the center pane.
- Collection environment editing works from the center pane.
- Variable key rename works, for example `baseUrl` to `BaseUrl`.
- Add and delete work for global and collection environments.
- Secret deletion cleans up the corresponding Keychain value where possible.
- `rtk swift test` passes.
- `rtk swift build` passes.
- `rtk ./script/build_and_run.sh --verify` passes.

### Slice 1: Request Authoring Polish

Purpose: make day-to-day request creation and editing comfortable enough for a public Phase 1 baseline.

Scope:

- Improve params editing ergonomics.
- Improve headers editing ergonomics.
- Improve auth editing ergonomics.
- Improve REST body editor behavior for raw JSON, form data, and urlencoded bodies.
- Improve GraphQL editor layout for query, operation name, variables, headers, and auth.
- Add obvious empty states and validation feedback where request authoring can fail.
- Add keyboard-friendly focus order for common request editing.

Non-goals:

- No pre-request scripts.
- No test runner.
- No generated docs.
- No new import format.

Done criteria:

- A user can create and send a REST request without editing YAML.
- A user can create and send a GraphQL request without editing YAML.
- Params, headers, auth, and body edits persist after save/load.
- Validation errors are visible and specific.
- Focused model and persistence tests cover new editing behavior.
- Manual app pass confirms no overlapping controls in compact and wide windows.

### Slice 2: Response And History Polish

Purpose: make executed requests useful after the response returns, not just technically executed. A response pane that only says "200, have fun" is not a product; it is a shrug.

Scope:

- Improve response status, duration, size, and header display.
- Add response body viewing modes where useful, such as pretty JSON and raw text.
- Add copy affordances for status, headers, body, and URL.
- Improve request history list and detail behavior.
- Allow re-running a request from history where the underlying request still exists.
- Keep history local-only and outside shareable workspace data where needed for Phase 2.

Non-goals:

- No response assertions.
- No monitor runner.
- No cloud history.

Done criteria:

- Response metadata is easy to scan.
- JSON responses can be formatted without destroying raw data.
- History entries are useful enough to identify and re-run recent requests.
- Local-only history behavior is documented before Phase 2 sharing starts.
- Tests cover response formatting and history persistence rules.

### Slice 3: Phase 2 Workspace Sharing

Purpose: make workspace folders easy to share through Git, zip, or file sync without leaking secrets or local-only noise.

Scope:

- Define shareable workspace folder contract.
- Keep stable IDs so diffs are readable.
- Keep secrets out of workspace files.
- Keep history, cache, window state, and other local-only data out of shareable files.
- Add import/export affordances for workspace folders and bundles.
- Add validation for shared workspace bundles before import.
- Document merge-friendly conventions for collections, environments, and requests.

Non-goals:

- No hosted sync.
- No accounts.
- No live multi-user editing.
- No permissions model.
- No conflict-resolution UI beyond clear validation errors and readable files.

Done criteria:

- A workspace folder can be committed to Git without secrets.
- A second local checkout can open the shared workspace.
- Zip export/import works for the shareable subset.
- Stable IDs keep normal edits readable in diffs.
- Docs explain what is shared and what remains local.
- Fixture tests cover shared workspace save/load and secret redaction.

### Slice 4: Public Release Hardening

Purpose: make the repo safe and credible as an open-source macOS app.

Scope:

- Add an explicit open-source license.
- Add public-facing security guidance.
- Finalize README run/build/test/release sections.
- Add contributor guidance where missing.
- Tighten release packaging docs.
- Add GitHub Actions for test/build if desired.
- Check for accidental secrets, local paths, and generated junk before publishing.

Non-goals:

- No notarization requirement unless distribution needs it immediately.
- No website.
- No hosted update system.

Done criteria:

- License is present.
- README clearly explains what RequestLab is, how to run it, and what is not supported yet.
- Security docs explain secrets and workspace sharing.
- Release docs explain packaging, signing options, checksums, and minimum validation.
- Public-repo hygiene check passes.
- `rtk swift test` passes from a clean checkout.

## Dependency Notes

Slice 0 should finish before Slice 1 because request authoring depends on predictable environment behavior.

Slice 1 should finish before Slice 2 because response and history polish should verify realistic request flows.

Slice 2 should finish before Slice 3 because workspace sharing needs a clean distinction between durable request data and local execution/history data.

Slice 4 can partially run in parallel with later slices, but the final public-release check should happen last.

## Suggested Next Slice

Finish and commit Slice 0: Environment Editor Close-Out.

After that, implement Slice 1: Request Authoring Polish.

## Success Criteria For The Roadmap

- The remaining work is visible in docs.
- Each slice has clear boundaries.
- Phase 2 remains file-sharing focused, not SaaS-shaped.
- The app reaches a credible open-source Phase 1 baseline before workspace sharing expands the surface area.
