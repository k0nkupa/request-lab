# Collection Environments Design

## Context

RequestLab currently supports workspace-level environments only. The next slice adds collection-level environments while keeping global environments. The selected UI direction is the compact environment selector: a single toolbar control summarizing the active global and collection environment pair.

## Goals

- Keep global environments for shared variables and secrets.
- Add environments scoped to each collection.
- Resolve request variables from both scopes.
- Change the main title from `RequestLab` to `<Collection> - <Request>` when a request is selected.
- Improve the REST/GraphQL picker with icon + text labels.
- Keep the change surgical and compatible with existing workspace files.

## Non-Goals

- No backend sync or shared workspace service in this slice.
- No team permissions, conflict resolution, or account model.
- No destructive migration that removes existing global environments.
- No large visual redesign beyond the requested header/picker polish.

## Data Model

`APIWorkspace.environments` remains the global environment list.

`APICollection` gains:

```swift
public var environments: [APIEnvironment]
```

Existing workspace YAML remains compatible because collection environment decoding defaults to an empty array when the field is absent.

Collection YAML will store collection environments inline with the collection, alongside requests. Global environment YAML remains under `environments/`.

## Selection Model

The app tracks two environment selections:

- `selectedGlobalEnvironmentID`
- `selectedCollectionEnvironmentIDByCollectionID`

When the selected request changes, the app derives the selected collection. The compact selector shows the selected pair for that collection:

```text
GlobalName + CollectionEnvName
```

If either scope has no active environment, the label omits that side:

```text
Local
Dev
No environment
```

## Variable Resolution

On send, RequestLab builds one effective environment:

1. Start with selected global environment variables.
2. Overlay selected collection environment variables.
3. If variable names collide, the collection value wins.

This keeps shared variables like `apiToken` global while allowing a collection to override `baseUrl`, `tenantId`, or request-specific auth variables.

Secret values remain in Keychain using environment IDs. Global and collection secrets are separate because their environment IDs are separate.

## UI Design

The main editor title becomes:

```text
<Collection> - <Request>
```

Fallbacks:

- selected collection but no request: `<Collection>`
- no selection: workspace name

The environment toolbar uses the compact option B:

- one menu-style control in the principal toolbar area
- displays the active global + collection pair
- menu sections:
  - `Global Environments`
  - `Collection Environments`
  - `None` option for either scope where useful

The REST/GraphQL selector becomes icon + text:

- REST: request/arrow-style SF Symbol plus `REST`
- GraphQL: `curlybraces` or node-style SF Symbol plus `GraphQL`

## Sidebar

The sidebar keeps the existing `Environments` section for global environments, renamed to `Global Environments`.

Collection-level environments are exposed inside each collection area. The first implementation can keep creation/deletion in context menus to avoid overloading the sidebar:

- collection context menu: `New Collection Environment`
- collection environment context menu: `Use Environment`, `Delete Environment`

## Testing

Add or update focused tests for:

- decoding legacy collection YAML without `environments`
- collection environment round trip through workspace save/load
- variable merge precedence, with collection variables overriding global variables
- collection environment add/delete helpers

Manual verification:

- launch app
- select starter REST request
- confirm title reads `Starter Collection - Get started`
- confirm compact environment selector is visible
- switch REST/GraphQL and confirm icon + text labels render cleanly

## Success Criteria

- Existing workspace fixtures still load.
- Global environments still work.
- Collection environments can be created, selected, saved, loaded, and used for request execution.
- Variable collision behavior is deterministic: collection overrides global.
- The header/title and request type picker match the approved compact direction.
