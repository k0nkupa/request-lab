# Layout Resizing Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent RequestLab's main sidebar from expanding indefinitely and stop the three-pane window layout from being resized below a usable width.

**Architecture:** Keep the existing `NavigationSplitView` plus `HSplitView` layout. Add explicit pane width budgets at the composition boundary in `ContentView`, and raise the root window minimum width in `RequestLabApp` so the layout cannot be compressed into an invalid state.

**Tech Stack:** Swift 6, SwiftUI, SwiftPM, macOS, `rtk` command wrapper.

---

### Task 1: Clamp The Main Panes

**Files:**
- Modify: `Sources/RequestLab/Views/ContentView.swift`

- [ ] **Step 1: Inspect the current pane frames**

Run:

```bash
sed -n '1,40p' Sources/RequestLab/Views/ContentView.swift
```

Expected: `SidebarView(store: store)` has no explicit width frame, `centerWorkspace` has `.frame(minWidth: 560)`, and `InspectorView(store: store)` has `.frame(minWidth: 260, idealWidth: 300, maxWidth: 360)`.

- [ ] **Step 2: Add explicit width bounds to the sidebar and update the center minimum**

Replace the current `NavigationSplitView` body block in `Sources/RequestLab/Views/ContentView.swift` with this code:

```swift
var body: some View {
    NavigationSplitView {
        SidebarView(store: store)
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
    } detail: {
        HSplitView {
            centerWorkspace
                .frame(minWidth: 620)
                .background(RequestLabTheme.background)

            if store.isInspectorVisible {
                InspectorView(store: store)
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                    .background(RequestLabTheme.surface)
            }
        }
    }
    .toolbar {
```

Keep the existing toolbar and alert code that follows `.toolbar {` unchanged.

- [ ] **Step 3: Verify the pane code matches the approved layout budget**

Run:

```bash
sed -n '1,30p' Sources/RequestLab/Views/ContentView.swift
```

Expected: the sidebar has `minWidth: 220, idealWidth: 260, maxWidth: 320`, the center pane has `minWidth: 620`, and the inspector is still bounded at `260...360`.

### Task 2: Raise The Window Minimum Width

**Files:**
- Modify: `Sources/RequestLab/App/RequestLabApp.swift`

- [ ] **Step 1: Inspect the current root window frame**

Run:

```bash
sed -n '1,25p' Sources/RequestLab/App/RequestLabApp.swift
```

Expected: `ContentView(store: store)` uses `.frame(minWidth: 980, minHeight: 640)`.

- [ ] **Step 2: Set the window minimum width to the approved budget**

Replace the `ContentView` frame in `Sources/RequestLab/App/RequestLabApp.swift` with this code:

```swift
ContentView(store: store)
    .frame(minWidth: 1120, minHeight: 640)
    .tint(RequestLabTheme.tint)
```

- [ ] **Step 3: Verify the root frame is updated**

Run:

```bash
sed -n '8,16p' Sources/RequestLab/App/RequestLabApp.swift
```

Expected: the root app frame has `minWidth: 1120` and `minHeight: 640`.

### Task 3: Build And Verify

**Files:**
- Read: `docs/superpowers/specs/2026-04-26-layout-resizing-design.md`
- Verify: `Sources/RequestLab/Views/ContentView.swift`
- Verify: `Sources/RequestLab/App/RequestLabApp.swift`

- [ ] **Step 1: Run the Swift build**

Run:

```bash
rtk swift build
```

Expected: build exits `0`.

- [ ] **Step 2: Run the core test suite**

Run:

```bash
rtk swift test
```

Expected: test command exits `0`.

- [ ] **Step 3: Launch-verify the app bundle**

Run:

```bash
rtk ./script/build_and_run.sh --verify
```

Expected: script exits `0` after launching and verifying the staged app.

- [ ] **Step 4: Manually verify the resizing behavior**

With the app open, verify these exact behaviors:

```text
1. Drag the left sidebar wider.
   Expected: it stops expanding around the 320 point max width.

2. Drag the left sidebar narrower.
   Expected: it stays usable around the 220 point min width.

3. Shrink the main RequestLab window.
   Expected: the window stops at the 1120 x 640 minimum instead of letting panes overlap.

4. At the minimum window size, inspect the request editor, toolbar, and right inspector.
   Expected: text remains readable and primary controls are not stacked on top of each other.
```

### Task 4: Commit The Implementation

**Files:**
- Stage: `Sources/RequestLab/Views/ContentView.swift`
- Stage: `Sources/RequestLab/App/RequestLabApp.swift`
- Stage: `docs/superpowers/plans/2026-04-26-layout-resizing.md`

- [ ] **Step 1: Review the final diff**

Run:

```bash
git diff -- Sources/RequestLab/Views/ContentView.swift Sources/RequestLab/App/RequestLabApp.swift docs/superpowers/plans/2026-04-26-layout-resizing.md
```

Expected: the diff only contains the pane sizing changes, root window width change, and this plan.

- [ ] **Step 2: Stage the implementation files**

Run:

```bash
git add Sources/RequestLab/Views/ContentView.swift Sources/RequestLab/App/RequestLabApp.swift docs/superpowers/plans/2026-04-26-layout-resizing.md
```

- [ ] **Step 3: Commit the implementation**

Run:

```bash
git commit -m "fix: stabilize main window resizing"
```

Expected: commit succeeds with only the implementation and plan files included.

