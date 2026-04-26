# Collection Sidebar Editing Design

Date: 2026-04-26

## Summary

Add collection-level editing affordances to the left sidebar. Right-clicking a
collection will support inline renaming and preset color selection. Collection
colors tint only the folder icon so the sidebar remains native, readable, and
compatible with SwiftUI's selection behavior.

## Goals

- Let users rename a collection from the collection context menu.
- Let users assign a preset color to a collection from the same context menu.
- Persist collection colors in workspace YAML.
- Preserve compatibility with existing workspace files that do not have color.
- Keep request rows, environment rows, disclosure behavior, and selection behavior unchanged.
- Reuse the current `RequestLabTheme` style instead of hardcoding view colors everywhere.

## Non-Goals

- No custom collection icons in this slice.
- No arbitrary macOS color picker or hex input.
- No drag-and-drop collection reordering.
- No rename support for requests or environments.
- No large sidebar redesign beyond the requested collection row affordances.

## Data Model

`APICollection` gains an optional preset color:

```swift
public var color: APICollectionColor?
```

`APICollectionColor` is a `String`, `Codable`, `Equatable`, `Sendable`, `CaseIterable`,
and `Identifiable` enum in `RequestLabCore`. The initial presets are:

```swift
blue
green
red
purple
orange
cyan
indigo
pink
gray
```

Missing color means the default collection color. Existing collection YAML remains
valid because decoding defaults `color` to `nil`.

When set, collection YAML stores the preset name:

```yaml
id: col_orders
name: Orders
color: blue
requests:
  ...
```

When cleared, `color` is absent or `nil`; no separate `"default"` value is needed.

## Core Editing API

Add focused workspace editing helpers:

```swift
mutating func updateCollection(id collectionID: String, mutate: (inout APICollection) -> Void) -> Bool
mutating func renameCollection(id collectionID: String, to name: String) -> Bool
mutating func updateCollectionColor(id collectionID: String, color: APICollectionColor?) -> Bool
```

`renameCollection` trims whitespace and rejects empty names by returning `false`.
It does not enforce unique collection names in this slice because the app already
allows duplicate display names until save-time filename validation catches duplicate
collection filenames. Changing that policy here would widen the behavior surface.

`AppStore` wraps these helpers with UI-facing methods and calls `clearExecutionState()`
after successful edits, matching existing collection create/delete behavior.

## Sidebar Interaction

The collection context menu adds two actions above creation/destructive actions:

- `Rename Collection`
- `Change Color`

The final order is:

1. `Rename Collection`
2. `Change Color`
3. `New Request`
4. `New Collection Environment`
5. `Delete Collection`

`Rename Collection` enters inline editing for that collection row. The row label is
replaced with a text field seeded with the current collection name.

Inline rename behavior:

- Enter commits the trimmed name.
- Escape cancels and restores the original name.
- Losing focus commits if the trimmed name is non-empty.
- Empty or whitespace-only input cancels instead of saving garbage.

Only one collection can be in rename mode at a time. Starting rename on another
collection cancels the previous draft.

## Color Picker

`Change Color` opens a compact SwiftUI popover attached to the collection row.
The popover is the only color-editing surface for this slice.

The picker contains:

- a `Default` or `None` option to clear the color
- one swatch for each `APICollectionColor` preset
- a visible selected state for the current color

Selecting a swatch immediately updates the collection color and closes the picker.
Selecting `Default` clears the stored color and closes the picker.

## Visual Design

Collection color tints only the folder icon. The collection name remains standard
sidebar text so selected rows still read correctly in Light and Dark appearances.
Request rows and environment rows keep their existing themed behavior from
`RequestLabTheme`.

Add a small app-target mapping helper near `RequestLabTheme`:

```swift
static func collectionColor(_ color: APICollectionColor?) -> Color
```

This maps nil to the existing `RequestLabTheme.collection` color and maps presets
to SwiftUI colors. The sidebar calls this helper from `collectionLabel`.

## Persistence

`WorkspaceFileStore` should not need custom save/load logic beyond the updated
`APICollection` encoding and decoding. Collection YAML files already serialize the
collection model directly.

Fixture updates are optional. The compatibility test should cover legacy YAML
without `color`; a round-trip test should cover a color-bearing collection without
needing to modify the sample workspace fixture.

## Error Handling

Rename and color updates return `false` if the collection ID is missing. UI actions
can ignore that failure because stale context menu actions are not recoverable by
the user. No alert is needed.

Empty rename drafts cancel. This avoids introducing validation UI for a context menu
feature and keeps the sidebar from saving blank collection names.

## Testing

Add focused `RequestLabCore` tests for:

- legacy collection YAML decodes without `color`
- collection color round-trips through workspace save/load
- `renameCollection` updates the name and trims whitespace
- `renameCollection` rejects empty names
- `updateCollectionColor` sets and clears the preset color

Manual verification:

```bash
rtk swift test
rtk swift build
rtk ./script/build_and_run.sh --verify
```

In the app:

- right-click a collection and choose `Rename Collection`
- verify Enter commits and Escape cancels
- verify empty rename input does not persist
- right-click a collection and choose `Change Color`
- select a preset and confirm only the folder icon changes color
- select default/none and confirm the folder icon returns to the default collection color

## Success Criteria

- Existing workspaces load without migration.
- Collection names can be changed inline from the sidebar context menu.
- Collection colors can be set and cleared from the sidebar context menu.
- Collection color persists through workspace save/load.
- The color treatment is limited to the collection folder icon.
- Existing request, environment, and sidebar selection behavior remains intact.
