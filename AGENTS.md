# Repository Guidelines

## Project Structure & Module Organization

RequestLab is a SwiftPM macOS app. `Sources/RequestLab` contains the SwiftUI executable target: app entry point, views, and `AppStore`. `Sources/RequestLabCore` contains reusable domain logic, models, persistence, request execution, variable resolution, and Keychain storage. Keep business logic here when it can be tested without launching the UI.

Tests live in `Tests/RequestLabCoreTests` and target `RequestLabCore`. Sample workspace data lives in `Fixtures/SampleWorkspace.workspace`; update it only when the serialized workspace format intentionally changes. Build artifacts are generated under `.build/` and `dist/`.

## Build, Test, and Development Commands

Repo commands should be run through `rtk`.

```bash
rtk swift package resolve
rtk swift test
rtk swift build
rtk ./script/build_and_run.sh
rtk ./script/build_and_run.sh --verify
```

`swift package resolve` refreshes dependencies, including `Yams`. `swift test` runs the Swift Testing suite. `swift build` compiles the package. `script/build_and_run.sh` stages `dist/RequestLab.app` and launches it; `--verify` launches, checks the process, and exits.

## Coding Style & Naming Conventions

Use Swift 6 conventions with four-space indentation. Prefer explicit, small value types that conform to `Codable`, `Equatable`, `Sendable`, and `Identifiable` where applicable. Public domain models use the `API` prefix (`APIRequest`, `APIWorkspace`), while services and stores use descriptive nouns (`VariableResolver`, `WorkspaceFileStore`). Keep UI state in the app target and portable behavior in `RequestLabCore`.

## Testing Guidelines

Use Swift Testing via `import Testing`, `@Suite`, `@Test`, `#expect`, and `#require`. Test files should follow the subject name, such as `VariableResolverTests.swift`. Add focused tests for model encoding, persistence round trips, request execution behavior, error cases, and fixture compatibility. Run `rtk swift test` before finishing changes.

## Commit & Pull Request Guidelines

Recent commits use short Conventional Commit-style subjects, especially `feat: ...`. Match that style: `feat: add workspace import validation`, `fix: preserve collection order`. Keep commits scoped and avoid ticket references.

Pull requests should include a concise summary, the user-visible behavior changed, verification commands run, and screenshots or screen recordings for UI changes. Mention fixture or workspace format changes explicitly.

## Security & Configuration Tips

Do not commit real API tokens, passwords, or workspace secrets. Secret environment variable values belong in macOS Keychain; shared YAML should preserve names and metadata without secret values.
