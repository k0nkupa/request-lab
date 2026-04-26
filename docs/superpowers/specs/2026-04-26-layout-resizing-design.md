# Layout Resizing Stability Design

## Problem

The RequestLab main window can be resized into states that break the visible layout. The left sidebar can be expanded far beyond a useful width, and when the app window is made smaller the three-pane interface overlaps and clips important editor controls.

## Goals

- Keep the current desktop-oriented three-pane layout stable.
- Clamp the left sidebar to a useful minimum and maximum width.
- Preserve the existing bounded right inspector behavior.
- Set a realistic minimum app window size so the UI cannot be compressed below the layout budget.
- Keep the change surgical and avoid redesigning request editor internals unless verification shows a remaining overflow.

## Non-Goals

- No automatic inspector collapse.
- No overlay navigation model.
- No mobile-style responsive redesign.
- No unrelated visual polish or component refactor.

## Proposed Layout Budget

The layout should continue to use the existing `NavigationSplitView` and `HSplitView` structure in `Sources/RequestLab/Views/ContentView.swift`.

- Sidebar: minimum `220`, ideal `260`, maximum `320`.
- Center workspace: minimum `620`.
- Inspector: keep the current minimum `260`, ideal `300`, maximum `360`.
- Window minimum width with inspector visible: `1120`.
- Window minimum width with inspector hidden: `860`.

These values are intended to keep the request editor usable while leaving enough room for the sidebar and inspector. The center pane remains the flexible work area.

## Implementation Shape

1. Add an explicit `navigationSplitViewColumnWidth` to `SidebarView(store:)` inside `ContentView`.
2. Adjust the `centerWorkspace` minimum width to the selected layout budget.
3. Keep the inspector frame bounded at its current range unless verification shows it needs a small adjustment.
4. Raise the root `ContentView` frame minimum width in `RequestLabApp`, using `1120` when the inspector is visible and `860` when it is hidden.

## Validation

Run the narrow checks that prove the app still builds and the core behavior remains intact:

```bash
rtk swift build
rtk swift test
rtk ./script/build_and_run.sh --verify
```

Manual verification should confirm:

- The left sidebar cannot expand indefinitely.
- The left sidebar cannot be squeezed below a usable width.
- The window cannot be resized smaller than the supported layout budget.
- The request editor, toolbar, and inspector remain readable at the minimum window size.
