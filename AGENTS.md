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
- Relative image support must use folder-tree authorization, not one-off repair banners.
- `Open Markdown…` is the primary path; when a document needs relative assets, the app should immediately request a durable bookmark for the inferred root folder (for example `Desktop` or a repo root), not for an arbitrary child directory.
- Do not “solve” file access bugs by switching testing to non-sandbox mode and pretending the App Store constraint disappeared.

## File Association
- OpenNow should register cleanly as a Markdown viewer in Finder `Open With`.
- It should be valid for users to set OpenNow as the default app for `.md` and `.markdown` files.
- Do not broaden file associations to all plain-text files just to get more opens.

## Implementation Boundaries
- Keep `ContentView` thin.
- Keep file access, rendering, persistence, and lifecycle logic in dedicated types.
- One document load pipeline only: file read -> render -> outline -> web view update.
- If a feature conflicts with startup speed, the feature loses unless the user explicitly says otherwise.

## Verification
- `xcodebuild -project OpenNow.xcodeproj -scheme OpenNow -destination 'platform=macOS' build`
- `xcodebuild -project OpenNow.xcodeproj -scheme OpenNow -destination 'platform=macOS' test`
- `xcodebuild -project OpenNow.xcodeproj -scheme OpenNowUI -destination 'platform=macOS' test`
- `OpenNowUI` requires macOS UI automation to be available. If `System Events` UI scripting is disabled or the machine has not granted the needed Accessibility / Automation permissions, treat that as an environment failure, not proof that the app UI is broken.
