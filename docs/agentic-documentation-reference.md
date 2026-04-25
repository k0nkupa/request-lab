# Agentic Documentation Reference

This reference describes the current RequestLab documentation system for agentic contributors. Use it to decide where to keep notes, feature context, implementation plans, release instructions, and repository guidance.

It documents the repository as it exists now. It does not define a future documentation platform, a full user manual, or a grand unified theory of markdown. We have enough of those already.

## Scope

This reference covers:

- The current documentation surfaces in this repository.
- Where agents should record notes, decisions, feature slices, and implementation plans.
- How existing documents map to Diataxis documentation types.
- How documentation should stay aligned with RequestLab source, tests, fixtures, and scripts.

This reference excludes:

- Future documentation redesigns.
- Public website or product marketing documentation.
- Generated API documentation.
- External documentation framework details beyond the Diataxis labels used here.

## Documentation Surfaces

| Surface | Purpose | Audience | Update when | Do not use for |
| --- | --- | --- | --- | --- |
| `README.md` | Project overview, quick start, current capabilities, workspace format summary, testing and release pointers. | Developers evaluating, running, or contributing to RequestLab. | User-visible capability, command, requirement, project structure, workspace summary, or public positioning changes. | Long implementation plans, raw design debates, or temporary notes. |
| `AGENTS.md` | Repository operating rules for coding agents and contributors. | Agents and maintainers working in this checkout. | Build commands, coding conventions, test expectations, security rules, or workflow expectations change. | Feature design detail, release notes, or user-facing product explanation. |
| `docs/RELEASE.md` | Release packaging instructions and release artifact reference. | Maintainers cutting or validating a local macOS app release. | Packaging script behavior, signing behavior, artifact names, checksum handling, or validation commands change. | General development setup or feature specs. |
| `docs/superpowers/specs/` | Feature and product design specifications. | Agents and maintainers planning or reviewing feature behavior. | A feature slice needs goals, non-goals, architecture, data model, UI behavior, testing expectations, or success criteria. | Step-by-step implementation checklists. |
| `docs/superpowers/plans/` | Executable implementation plans with task checklists. | Agents implementing approved work. | Work is ready to be executed task-by-task or tracked across commits. | Open-ended design discussion or product rationale without implementation steps. |
| `Fixtures/SampleWorkspace.workspace/` | Serialized sample workspace data and fixture compatibility anchor. | Tests, maintainers, and agents changing workspace persistence. | Workspace file format intentionally changes, or fixture compatibility must cover new persisted behavior. | Notes, prose documentation, or scratch examples not used by tests. |
| Inline code comments | Local clarification for non-obvious implementation details. | Developers reading the relevant source file. | A small piece of code needs context that cannot be made obvious by naming or structure. | Architecture essays, TODO graveyards, or duplicating obvious code behavior. |

## Diataxis Classification

RequestLab currently has a small mixed documentation set. Treat each surface according to its dominant Diataxis role:

| Surface | Type | Notes |
| --- | --- | --- |
| `README.md` | Tutorial and explanation hybrid | Introduces the app, explains why it exists, and gives quick-start commands. Keep it approachable and current. |
| `AGENTS.md` | Reference | Defines repository rules, structure, commands, conventions, testing expectations, and security constraints. |
| `docs/RELEASE.md` | How-to and reference hybrid | Gives release commands and describes generated artifacts. Keep command examples exact. |
| `docs/superpowers/specs/*.md` | Explanation | Captures why a feature slice exists, what it includes, what it excludes, and how it should behave. |
| `docs/superpowers/plans/*.md` | How-to | Provides ordered implementation steps and checklists for agents executing a slice. |
| `Fixtures/SampleWorkspace.workspace/` | Reference artifact | Acts as executable documentation for the workspace file format through tests. |

## Feature Slice Notes

A feature slice is a coherent vertical change to RequestLab behavior. It may touch the SwiftUI app target, the `RequestLabCore` domain layer, fixtures, tests, scripts, and documentation.

Examples of current feature slices:

- `docs/superpowers/specs/2026-04-25-collection-environments-design.md`
- `docs/superpowers/plans/2026-04-24-macos-api-client-foundation.md`

Use a spec in `docs/superpowers/specs/` when a slice needs design context before implementation. A good spec records:

- Context
- Goals
- Non-goals
- Data model changes
- Selection or state model changes
- Variable resolution or business rules
- UI behavior
- Testing expectations
- Success criteria

Use a plan in `docs/superpowers/plans/` when a slice is ready for execution. A good plan records:

- Goal
- Architecture
- Tech stack
- Scope
- Deferred work
- File structure
- Task checklist
- Verification commands

Keep specs explanatory and plans operational. If a document is trying to do both, split it. Markdown is cheap; confusion is not.

## Agentic Workflow Rules

Agents should follow these rules when maintaining documentation:

- Read existing documentation before creating new documentation.
- Prefer updating the smallest correct surface over adding another file.
- Keep current-state references aligned with the actual repository, not hoped-for architecture.
- Keep business logic documentation aligned with `Sources/RequestLabCore`.
- Keep UI behavior documentation aligned with `Sources/RequestLab`.
- Keep workspace format claims aligned with `WorkspaceFileStore`, model types, tests, and `Fixtures/SampleWorkspace.workspace/`.
- Keep command examples routed through `rtk`.
- Update tests or fixtures when documentation describes serialized behavior that tests should enforce.
- Avoid copying full design content into `README.md`; summarize and link instead.
- Avoid hiding behavior changes only in a plan. Plans are execution artifacts, not durable product truth.

When changing documentation, verify the relevant surface:

- For docs-only edits, read the rendered markdown or at least inspect the changed file.
- For command or script documentation, run the documented command when practical.
- For workspace format documentation, run `rtk swift test` unless the change is purely editorial.
- For release packaging documentation, run or explicitly defer `rtk ./script/package_release.sh`.

## Documentation Update Matrix

| Change type | Update location |
| --- | --- |
| New user-visible capability | `README.md` and the relevant spec in `docs/superpowers/specs/`. |
| New or changed agent workflow | `AGENTS.md` or this reference. |
| New feature design decision | A dated spec under `docs/superpowers/specs/`. |
| Approved implementation checklist | A dated plan under `docs/superpowers/plans/`. |
| Release packaging behavior change | `docs/RELEASE.md`. |
| Build, test, or development command change | `README.md` and `AGENTS.md`. |
| Workspace file format change | `README.md`, fixtures, persistence tests, and any relevant spec. |
| Fixture compatibility change | `Fixtures/SampleWorkspace.workspace/` and `Tests/RequestLabCoreTests/`. |
| Security handling change | `AGENTS.md`, `README.md` if user-visible, and relevant tests. |
| Public distribution requirement change | `README.md` and `docs/RELEASE.md`. |

## Naming And Format Conventions

Use date-prefixed names for specs and plans:

```text
docs/superpowers/specs/YYYY-MM-DD-short-feature-name.md
docs/superpowers/plans/YYYY-MM-DD-short-feature-name.md
```

Use short, descriptive slugs:

```text
2026-04-25-collection-environments-design.md
2026-04-24-macos-api-client-foundation.md
```

Use clear Markdown structure:

- Start with one `#` heading.
- Prefer `##` headings for major reference sections.
- Use tables for stable reference data.
- Use bullets for lists of rules or expectations.
- Use fenced code blocks for commands and file trees.
- Use `rtk` in command examples.

Specs should usually include:

```text
Context
Goals
Non-Goals
Data Model
UI Design
Testing
Success Criteria
```

Plans should usually include:

```text
Goal
Architecture
Tech Stack
Scope
File Structure
Task Checklist
Verification
```

## Current Gaps

These gaps exist in the current documentation set:

- No dedicated user manual.
- No standalone architecture reference beyond `README.md` and design specs.
- No standalone workspace format reference.
- No public contributor guide beyond `AGENTS.md`.
- No license file yet, despite the open-source intent described in `README.md`.
- No notarization runbook for public macOS distribution.

Do not fill these gaps opportunistically inside unrelated changes. Create or update the right document when the work actually needs it.

## Quick Reference

| If you changed... | Put the documentation here |
| --- | --- |
| Request execution behavior | Relevant tests, `README.md` if user-visible, and a spec if it was planned behavior. |
| Variable resolution behavior | `README.md` if user-visible, tests, and relevant spec. |
| Workspace YAML shape | `README.md`, fixtures, persistence tests, and relevant spec. |
| Release packaging | `docs/RELEASE.md`. |
| Build or test commands | `README.md` and `AGENTS.md`. |
| A new feature slice design | `docs/superpowers/specs/YYYY-MM-DD-short-feature-name.md`. |
| A task-by-task implementation plan | `docs/superpowers/plans/YYYY-MM-DD-short-feature-name.md`. |
| Agent operating rules | `AGENTS.md` or this reference. |
| A temporary investigation note | Prefer the active plan or spec; avoid creating random scratch docs in the repo. |

When in doubt, update an existing durable document before adding a new one. If the note only makes sense during implementation, it probably belongs in the active plan. If it explains product behavior after the implementation lands, it belongs in a spec, README, release doc, or tests.
