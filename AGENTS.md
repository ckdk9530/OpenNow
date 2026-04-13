# OpenNow Agent Guide

## Product Position
- `OpenNow` is a single-window, read-only macOS Markdown reader.
- The priorities are: `launch speed first`, `native macOS feel second`, `feature completeness after that`.
- Do not drift into editor behavior, multiwindow document architecture, or speculative plugin work.

## Hard Constraints
- Keep the shell in `SwiftUI`.
- Render document bodies in `WKWebView`.
- Treat launch performance as the top-level architecture rule.
- Avoid startup work that blocks the first interactive window:
  - no Markdown preparse
  - no recent-files validation sweep
  - no image preloading
  - no eager file watchers
- Prefer asynchronous file load and render after the shell is visible.
- Keep persistence lightweight: `UserDefaults` plus bookmark data only.
- Do not reintroduce `SwiftData` or `CoreData` for reader state.

## App Store Direction
- Design as if the app will ship through the Mac App Store.
- File access must work with sandboxed user-selected files.
- Prefer security-scoped bookmarks for reopen flows and recent files.
- Relative image support must account for parent-folder access, not just the file bookmark.

## Implementation Boundaries
- Keep `ContentView` thin.
- Keep file access, rendering, persistence, and lifecycle logic in dedicated types.
- One document load pipeline only: file read -> render -> outline -> web view update.
- If a feature conflicts with startup speed, the feature loses unless the user explicitly says otherwise.

## Verification
- `xcodebuild -project OpenNow.xcodeproj -scheme OpenNow -destination 'platform=macOS' build`
- `xcodebuild -project OpenNow.xcodeproj -scheme OpenNow -destination 'platform=macOS' test`
