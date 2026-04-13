# OpenNow Architecture

## Core Shape
- `SwiftUI` owns the app shell, layout, menus, and empty/loading/error states.
- `WKWebView` renders the document body.
- A single `AppLaunchCoordinator` owns file-open flows, restore flows, and active document state.

## Startup Phases
1. Launch the shell and restore the window frame.
2. Decide whether to show an empty state or try a last-open restore.
3. Load and render the document asynchronously.
4. Attach the file watcher only after the document is open.

## Subsystems
- `AppLaunchCoordinator`: startup, open flows, active document state, recents, reloads.
- `DocumentAccessController`: file pickers, folder-tree authorization, bookmark creation, bookmark resolution, security scope lifecycle.
- `MarkdownRenderer`: Markdown to HTML plus outline generation.
- `ReaderWebBridge`: bridge between the coordinator and `WKWebView`.
- `FileWatcher`: `DispatchSource` watcher for the active file only.
- `PreferencesStore`: recent files, authorized folder roots, last-open record, and window frame persistence.

## Constraints
- The app stays single-window in V1.
- Persistence stays lightweight.
- Startup work must stay lazy and document-driven.
- Sandbox support should prefer durable folder-tree authorization over per-file repair flows.
- If `WKWebView` creation becomes the startup bottleneck, make the reader surface lazy before adding heavier mitigation.
