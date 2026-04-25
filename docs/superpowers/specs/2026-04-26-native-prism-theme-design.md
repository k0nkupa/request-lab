# Native Prism Theme Design

Date: 2026-04-26

## Summary

Refresh RequestLab with a colorful, system-adaptive visual theme named Native Prism.
The app should feel more polished and easier to scan while staying native to macOS.
The first pass adds reusable SwiftUI theme tokens and applies them to existing app
surfaces. It does not add an in-app appearance picker or multiple selectable
palettes.

## Goals

- Make the app visibly more colorful without sacrificing readability.
- Support macOS Light and Dark appearances automatically.
- Keep the existing three-pane SwiftUI layout and native controls.
- Add a reusable app-level theme layer for colors and small visual helpers.
- Improve visual hierarchy for request editing, responses, sidebar selections,
  inspector sections, environment editing, and status states.
- Keep `RequestLabCore` untouched.

## Non-Goals

- No manual Light/Dark/System appearance setting in this pass.
- No user-selectable palette system.
- No layout redesign beyond small spacing or surface treatments needed for the theme.
- No custom window chrome, custom toolbar replacement, or heavy glass simulation.
- No change to workspace persistence, request execution, or environment behavior.

## Visual Direction

Native Prism uses restrained color across native macOS surfaces:

- Blue for primary actions, current selection, active tabs, and focused workspace state.
- Green for successful responses and safe request outcomes.
- Amber or orange for redirects, warnings, and slower or uncertain states.
- Red for request failures and destructive/error states.
- Cyan or indigo accents for environment and inspector context.
- Subtle adaptive fills for request bars, response panels, editor surfaces, and inspector cards.

The palette must adapt through SwiftUI dynamic colors or semantic system colors so
Light and Dark appearances both remain readable. Color should carry hierarchy and
state, not decorate every available pixel like the UI lost a bet.

## Theme Architecture

Add an app-target theme helper at `Sources/RequestLab/Support/RequestLabTheme.swift`
with semantic values such as:

- `RequestLabTheme.background`
- `RequestLabTheme.surface`
- `RequestLabTheme.elevatedSurface`
- `RequestLabTheme.selection`
- `RequestLabTheme.primaryAction`
- `RequestLabTheme.success`
- `RequestLabTheme.warning`
- `RequestLabTheme.error`
- `RequestLabTheme.info`
- `RequestLabTheme.editorBorder`

The helper should stay lightweight: static `Color` values and small view modifiers
only where they reduce repetition. Avoid a broad design-system abstraction until
there is more than one actual theme.

## App Surfaces

### Content Shell

`ContentView` keeps the current `NavigationSplitView`, toolbar, center editor, and
optional inspector. Theme work may add app tinting and subtle background treatment
around the center workspace, but it should not replace native toolbar or split-view
behavior.

### Sidebar

`SidebarView` should use color to distinguish item types and state:

- Collections keep a folder identity.
- Requests get REST or GraphQL accents.
- Environments use the environment accent.
- Selected/active environments become visibly active without relying only on primary
  versus secondary text color.

The recent sidebar selection behavior must be preserved.

### Request Editor

`RequestEditorView` receives the most visible polish:

- HTTP methods render with compact colored badges.
- The request bar gets a subtle adaptive surface treatment.
- The Send button uses the primary action color.
- Editor text areas keep monospaced readability with adaptive borders/fills.
- Request tabs get clearer active state through native styling plus accent color.

### Response Panel

Response state should be color-coded:

- `2xx`: success.
- `3xx`: info or warning.
- `4xx`: warning.
- `5xx`: error.

The response panel should show status and duration with readable contrast in both
Light and Dark mode. Empty, sending, failure, and populated states must remain clear.

### Inspector

`InspectorView` should use small tinted sections or accent markers for request,
global environment, collection environment, and last response sections. This should
improve scanning without turning the inspector into nested card soup.

### Environment Editor

`EnvironmentEditorView` should align with the theme while preserving current
environment editing behavior. Variable rows can use subtle icons, tints, and borders
for regular versus secret values. Secret handling remains unchanged.

## Testing And Verification

Run the narrow checks that prove this pass did not break the app:

```bash
rtk swift build
rtk swift test
rtk ./script/build_and_run.sh --verify
```

If `--verify` is impractical in the current environment, document the reason and run
at least `rtk swift build` and `rtk swift test`.

Manual visual verification should check:

- Light appearance readability.
- Dark appearance readability.
- Sidebar selection and environment active state.
- Request editor with REST and GraphQL requests.
- Response panel for success and error states.
- Environment editor with regular and secret variables.

## Implementation Constraints

- Keep changes scoped to the app target unless a compile issue requires otherwise.
- Do not modify workspace format or fixtures.
- Do not overwrite existing in-progress environment-editing changes.
- Use SwiftUI-native colors and modifiers before introducing custom drawing.
- Keep reusable helpers small and obvious.
- Add comments only where the theme intent is not self-explanatory.
