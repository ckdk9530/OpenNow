# OpenNow Complex Render Fixture

This fixture is intentionally dense. If this page looks clean, your reader is probably handling the hard cases well enough for V1.

![Complex banner](./complex-banner.svg)

## Typography Stress

Normal text, **bold text**, *italic text*, ***bold italic***, ~~strikethrough~~, `inline code`, and a mixed run with **bold + `code` + [link](https://example.com)** in one sentence.

This paragraph also contains an intentionally long token to test overflow handling:

`OpenNowShouldNotExplodeWhenItSeesAnAbsurdlyLongIdentifierThatHasNoNaturalBreakPoints1234567890ABCDEFGHIJKLMN`

Inline HTML still matters in real Markdown:

<sub>subscript</sub> and <sup>superscript</sup> and <mark>highlight-like HTML</mark>.

## Nested Structure

> A blockquote should breathe.
>
> It should not collapse into a muddy gray slab.
>
> - Nested list item in a quote
> - Another nested item

1. Ordered item one
2. Ordered item two
   - Nested bullet
   - Nested bullet with `code`
     1. Deep ordered item
     2. Another deep ordered item
3. Ordered item three

- [x] Completed task
- [ ] Pending task
- [ ] Task with a [link](https://github.com/stackotter/Down-gfm) and `inline code`

### Definition-Like Content

Term A
: A fake definition line rendered as normal paragraph text in plain Markdown readers.

Term B
: Another fake definition, useful to see whether spacing collapses awkwardly.

## Tables

### Alignment Table

| Column | Left | Center | Right |
| :-- | :-- | :--: | --: |
| Row 1 | plain text | centered value | 42 |
| Row 2 | `inline code` | **bold** | 9001 |
| Row 3 | very long text that should wrap rather than blow out the whole table width | icon-like text | 123456789 |

### Wide Table

| Section | Purpose | Main Risk | Mitigation | Notes | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Launch shell | Show UI first | White screen before interactivity | Initialize shell before document load | This is the non-negotiable rule | App layer | Stable |
| Markdown render | Convert source to HTML | Main-thread parsing | Parse off main thread and inject HTML later | Reuse outline extraction work | Renderer | Stable |
| Relative images | Show local assets | Sandbox tree access missing | Authorize the inferred tree root such as Desktop or a repo root | Keep prompts rare by reusing root bookmarks | Access layer | Watching |
| WebView init | Host the document | Cold creation cost | Keep placeholder path available if profiling proves it necessary | Evidence first, tricks second | Reader | Watching |

## Code Blocks

```swift
import Foundation

struct LaunchBudget {
    let shellFirst = true
    let markdownOnMainThread = false

    func summary() -> String {
        "shellFirst=\(shellFirst), markdownOnMainThread=\(markdownOnMainThread)"
    }
}

print(LaunchBudget().summary())
```

```json
{
  "app": "OpenNow",
  "mode": "read-only",
  "priority": "launch-speed-first",
  "features": [
    "outline",
    "tables",
    "code blocks",
    "relative images",
    "dark mode"
  ]
}
```

```diff
- Do everything during launch.
+ Show the shell first.
+ Load the document asynchronously.
+ Attach file watchers only after the document is visible.
```

```bash
md_path="./docs/render-fixtures/complex-render-fixture.md"
echo "Open fixture: ${md_path}"
```

## Horizontal Rule

---

## Relative Images

The two images below verify `baseURL` handling, sizing, and SVG rendering:

![Pipeline diagram](./complex-diagram.svg)

![Repeated banner to test multiple relative assets](./complex-banner.svg)

## Mixed Content Columns via Table

| Visual | Text |
| --- | --- |
| ![Diagram thumbnail](./complex-diagram.svg) | This is a brutal but useful case: an image embedded inside a table cell next to dense explanatory text. If your CSS is sloppy, this turns into a mess quickly. |

## Edge Cases

### Long Heading With Mixed Symbols 1234567890 !@#$%^&*() [] {} <> Should Still Look Reasonable

If this heading breaks layout, your content width, line height, or anchor styling is too fragile.

#### Tiny Section

Small sections still need sensible spacing.

##### Another Tiny Section

Very deep headings should not dominate the page.

###### H6 Exists Too

This is mostly here to prove the typographic scale does not collapse at the edges.

## Final Checklist

- Images load
- Tables scroll or wrap acceptably
- Code blocks remain readable
- Quote spacing stays deliberate
- Heading scale remains consistent
- No obvious overlap, clipping, or horizontal overflow
