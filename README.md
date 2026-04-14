# OpenNow

Fast, read-only Markdown viewing for macOS.

OpenNow is a deliberately narrow app: it opens Markdown files quickly, renders them in a native-feeling macOS shell, and stays out of the way. It is not trying to become an editor, workspace, tab manager, or plugin host.

## Why OpenNow Exists

Most Markdown tools drift toward editing, project management, or browser-style complexity. OpenNow takes the opposite position:

- launch speed comes first
- native macOS feel comes second
- feature completeness comes after that

That constraint is intentional. If a feature threatens startup speed or adds editor behavior, it is probably the wrong feature for this app.

## Current Scope

OpenNow is built for:

- opening `.md`, `.markdown`, and `.mdown` files from Finder or `Open Markdown…`
- rendering document bodies with `WKWebView`
- showing a sidebar outline for heading-based navigation
- supporting common Markdown reading flows: headings, lists, blockquotes, tables, code blocks, images, and links
- remembering recent files, authorized roots, reader scale, and window state
- restoring the last document without blocking the first interactive window
- handling sandboxed file access with security-scoped bookmarks

## Non-Goals

These are intentionally out of scope:

- editing
- multiwindow document architecture
- tabs
- plugin systems
- sync or cloud libraries
- startup-time scans, prep, or preloading unrelated to the active document

If you want a Markdown IDE, this project should not pretend to be one.

## Architecture

OpenNow keeps the shape simple on purpose:

- `SwiftUI` owns the shell, commands, sidebar, empty states, and settings
- `WKWebView` renders the document body
- `AppLaunchCoordinator` owns the document lifecycle and open/restore flows
- `DocumentAccessController` owns sandbox authorization and bookmark management
- `MarkdownRenderer` turns Markdown into HTML and outline data
- `ReaderWebBridge` connects app state to the web view

The document pipeline is intentionally single-path:

`file read -> render -> outline -> web view update`

Startup is also intentionally lazy:

1. Show the shell.
2. Decide whether to restore or show an empty state.
3. Load and render the document asynchronously.
4. Attach the file watcher only after the document is open.

## Sandboxed File Access

OpenNow is designed for the Mac App Store path, not for cheating around sandbox rules.

- File access is based on user selection plus security-scoped bookmarks.
- Recent-file reopen flows use persisted bookmark data.
- When a Markdown file needs relative assets, OpenNow should request a durable bookmark for the inferred document-tree root instead of a random child folder.
- Relative image support is treated as a real sandbox problem, not something to hand-wave away with non-sandbox testing.

## Finder Integration

OpenNow is registered as a Markdown viewer and is meant to be a valid default app for:

- `.md`
- `.markdown`
- `.mdown`

It is intentionally not broadening into a generic plain-text app just to catch more file opens.

## Development

### Requirements

- macOS
- Xcode

### Build

```bash
xcodebuild -project OpenNow.xcodeproj -scheme OpenNow -destination 'platform=macOS' build
```

### Test

```bash
xcodebuild -project OpenNow.xcodeproj -scheme OpenNow -destination 'platform=macOS' test
xcodebuild -project OpenNow.xcodeproj -scheme OpenNowUI -destination 'platform=macOS' test
```

Notes:

- `OpenNowUI` depends on macOS UI automation being available.
- If `System Events` UI scripting or required Accessibility / Automation permissions are missing, treat that as an environment failure, not automatic evidence of an app bug.

## Repository Notes

- Reader state is intentionally lightweight: `UserDefaults` plus bookmark data.
- The app should not reintroduce `SwiftData` or `CoreData` for reader state.
- `ContentView` should stay thin; file access, rendering, persistence, and lifecycle logic belong in dedicated types.

## Status

OpenNow is a focused macOS Markdown reader with App-Store-oriented sandbox behavior, Finder integration, a heading outline, recent-file restore, and a launch path optimized around first-window responsiveness.

If the product starts to drift into “editor with viewer mode,” the architecture is losing the plot.
