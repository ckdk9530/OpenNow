# OpenNow V1 Plan

## Product Definition
`OpenNow` is a fast, native-feeling macOS Markdown reader. V1 is intentionally narrow: it opens Markdown files quickly, renders them cleanly, and stays stable. It is not an editor.

## Goals
- Open `.md`, `.markdown`, and compatible plain-text Markdown files.
- Support Finder double-click open and `cmd+o`.
- When `Open Markdown…` encounters relative assets, immediately request a durable bookmark for the document-tree root rather than a narrow child folder.
- Show a left outline and a right reading surface.
- Support headings, lists, blockquotes, tables, code blocks, images, and links.
- Support dark mode.
- Support keyboard paging with `space` and `shift+space`.
- Remember the last window size and recent files.

## Non-Goals
- No editing.
- No multiwindow document architecture.
- No tabbed browsing.
- No plugin system.
- No sync, cloud storage, or startup library scan.

## Performance Rules
- Launch speed is the first product goal.
- The initial shell must appear before file parsing and rendering finish.
- Opening a typical Markdown file should feel immediate.
- Restoring the last document must not freeze the shell while bookmarks resolve or parsing happens.
- The app should avoid startup-side work that is unrelated to the current document.
