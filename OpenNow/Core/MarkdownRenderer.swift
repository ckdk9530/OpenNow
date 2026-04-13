import Down
import Foundation

struct MarkdownRenderer: Sendable {
    nonisolated init() {}

    nonisolated func render(markdown: String, baseURL: URL) throws -> RenderedDocument {
        let tableTransform = GFMTableTransformer.transform(markdown)
        let html = try Down(markdownString: tableTransform.markdown).toHTML()
        let restoredTablesHTML = tableTransform.restore(in: html)
        let outlineItems = OutlineExtractor.extract(from: markdown)
        let anchoredHTML = injectAnchors(into: restoredTablesHTML, outlineItems: outlineItems)
        let relativeLocalAssetURLs = collectRelativeLocalAssetURLs(in: markdown, baseURL: baseURL)
        let documentHTML = wrapHTML(
            rewriteLocalImageSources(in: anchoredHTML, baseURL: baseURL),
            baseURL: baseURL
        )

        return RenderedDocument(
            html: documentHTML,
            outlineItems: outlineItems,
            containsRelativeImages: relativeLocalAssetURLs.isEmpty == false,
            relativeLocalAssetURLs: relativeLocalAssetURLs
        )
    }

    nonisolated private func injectAnchors(into html: String, outlineItems: [OutlineItem]) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"<h([1-6])(?:\s[^>]*)?>"#, options: []) else {
            return html
        }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html))
        guard matches.isEmpty == false else {
            return html
        }

        let mutable = NSMutableString(string: html)
        var offset = 0

        for (index, match) in matches.enumerated() where index < outlineItems.count {
            let range = NSRange(location: match.range.location + offset, length: match.range.length)
            let level = outlineItems[index].level
            let replacement = "<h\(level) id=\"\(outlineItems[index].anchor)\">"
            mutable.replaceCharacters(in: range, with: replacement)
            offset += replacement.count - range.length
        }

        return mutable as String
    }

    nonisolated private func wrapHTML(_ body: String, baseURL: URL) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root {
              color-scheme: light dark;
              --bg: rgba(0, 0, 0, 0);
              --text: #1d1d1f;
              --muted: #5c6570;
              --border: rgba(60, 60, 67, 0.2);
              --code-bg: rgba(60, 60, 67, 0.08);
              --quote: #6f7782;
              --link: #0a84ff;
            }
            :root[data-color-scheme="light"] {
              color-scheme: light;
              --text: #1d1d1f;
              --muted: #5c6570;
              --border: rgba(60, 60, 67, 0.2);
              --code-bg: rgba(60, 60, 67, 0.08);
              --quote: #6f7782;
              --link: #0a84ff;
            }
            :root[data-color-scheme="dark"] {
              color-scheme: dark;
              --text: #f5f5f7;
              --muted: #9ba3af;
              --border: rgba(235, 235, 245, 0.24);
              --code-bg: rgba(255, 255, 255, 0.08);
              --quote: #b2b8c2;
              --link: #4da3ff;
            }
            @media (prefers-color-scheme: dark) {
              :root {
                --text: #f5f5f7;
                --muted: #9ba3af;
                --border: rgba(235, 235, 245, 0.24);
                --code-bg: rgba(255, 255, 255, 0.08);
                --quote: #b2b8c2;
                --link: #4da3ff;
              }
            }
            * { box-sizing: border-box; }
            html {
              margin: 0;
              padding: 0;
              background: var(--bg);
              color: var(--text);
              font-size: 100%;
            }
            body { margin: 0; padding: 0; background: var(--bg); color: var(--text); }
            body {
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              font-size: 1rem;
              line-height: 1.62;
              padding: 28px 34px 80px;
              max-width: 920px;
              margin: 0 auto;
            }
            h1, h2, h3, h4, h5, h6 {
              line-height: 1.2;
              margin-top: 1.6em;
              margin-bottom: 0.55em;
              scroll-margin-top: 18px;
            }
            h1:first-child { margin-top: 0; }
            p, ul, ol, blockquote, pre, table { margin: 0 0 1.15em; }
            ul, ol { padding-left: 1.45em; }
            li + li { margin-top: 0.32em; }
            blockquote {
              border-left: 3px solid var(--border);
              margin-left: 0;
              padding-left: 1em;
              color: var(--quote);
            }
            a { color: var(--link); text-decoration: none; }
            a:hover { text-decoration: underline; }
            code, pre {
              font-family: "SF Mono", SFMono-Regular, ui-monospace, Menlo, Consolas, monospace;
              font-size: 0.92em;
            }
            code {
              background: var(--code-bg);
              border-radius: 6px;
              padding: 0.15em 0.35em;
            }
            pre {
              background: var(--code-bg);
              border: 1px solid var(--border);
              border-radius: 12px;
              overflow-x: auto;
              padding: 16px 18px;
            }
            pre code {
              background: transparent;
              border-radius: 0;
              padding: 0;
            }
            table {
              border-collapse: collapse;
              display: block;
              overflow-x: auto;
              max-width: 100%;
              margin: 0 0 1.15em;
            }
            th, td {
              border: 1px solid var(--border);
              padding: 10px 12px;
              min-width: 0;
              vertical-align: top;
              white-space: normal;
              overflow-wrap: anywhere;
            }
            th {
              background: var(--code-bg);
              font-weight: 600;
            }
            th:not([align]), td:not([align]) { text-align: left; }
            th[align="center"], td[align="center"] { text-align: center; }
            th[align="right"], td[align="right"] { text-align: right; }
            th[align="left"], td[align="left"] { text-align: left; }
            img {
              display: block;
              max-width: 100%;
              height: auto;
              margin: 1.2em 0;
              border-radius: 10px;
            }
            hr {
              border: 0;
              border-top: 1px solid var(--border);
              margin: 2em 0;
            }
          </style>
          <script>
            window.OpenNowBridge = {
              isEditableTarget() {
                const target = document.activeElement;
                if (!target) return false;
                if (target.isContentEditable) return true;
                const tag = target.tagName;
                return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT";
              },
              pageBy(direction) {
                if (window.OpenNowBridge.isEditableTarget()) return false;
                const amount = Math.max(window.innerHeight * 0.88, 220) * direction;
                window.scrollBy({ top: amount, behavior: "smooth" });
                return true;
              },
              scrollToAnchor(anchor) {
                const element = document.getElementById(anchor);
                if (!element) return false;
                element.scrollIntoView({ behavior: "smooth", block: "start" });
                return true;
              },
              captureScrollFraction() {
                const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
                if (maxScroll <= 0) return 0;
                return window.scrollY / maxScroll;
              },
              restoreScrollFraction(fraction) {
                const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
                if (maxScroll <= 0) return;
                window.scrollTo(0, Math.max(0, Math.min(maxScroll, maxScroll * fraction)));
              },
              setFontScale(scale) {
                const clamped = Math.max(0.85, Math.min(1.8, scale));
                document.documentElement.style.fontSize = `${clamped * 100}%`;
                return clamped;
              },
              setColorScheme(scheme) {
                const resolved = scheme === "dark" ? "dark" : "light";
                document.documentElement.setAttribute("data-color-scheme", resolved);
                return resolved;
              }
            };
          </script>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    nonisolated private func rewriteLocalImageSources(in html: String, baseURL: URL) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"(<img\b[^>]*\bsrc=["'])([^"']+)(["'][^>]*>)"#,
            options: [.caseInsensitive]
        ) else {
            return html
        }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html))
        guard matches.isEmpty == false else {
            return html
        }

        let mutable = NSMutableString(string: html)
        for match in matches.reversed() {
            guard match.numberOfRanges == 4,
                  let prefixRange = Range(match.range(at: 1), in: html),
                  let sourceRange = Range(match.range(at: 2), in: html),
                  let suffixRange = Range(match.range(at: 3), in: html)
            else {
                continue
            }

            let source = String(html[sourceRange])
            guard let rewrittenSource = rewrittenImageSource(for: source, baseURL: baseURL) else {
                continue
            }

            let replacement = "\(html[prefixRange])\(rewrittenSource)\(html[suffixRange])"
            mutable.replaceCharacters(in: match.range, with: replacement)
        }

        return mutable as String
    }

    nonisolated private func rewrittenImageSource(for source: String, baseURL: URL) -> String? {
        guard let fileURL = resolvedLocalAssetURL(for: source, baseURL: baseURL) else {
            return nil
        }

        return makeReaderAssetURLString(for: fileURL)
    }

    nonisolated private func resolvedLocalAssetURL(for source: String, baseURL: URL) -> URL? {
        let normalizedSource = normalizeLocalAssetSource(source)

        guard normalizedSource.isEmpty == false,
              normalizedSource.hasPrefix("data:") == false,
              normalizedSource.hasPrefix("blob:") == false,
              normalizedSource.hasPrefix("#") == false,
              normalizedSource.hasPrefix("\(readerAssetSchemeName):") == false
        else {
            return nil
        }

        if let absoluteURL = URL(string: normalizedSource), absoluteURL.scheme != nil {
            guard absoluteURL.isFileURL else {
                return nil
            }

            return absoluteURL.standardizedFileURL
        }

        let decodedPath = normalizedSource.removingPercentEncoding ?? normalizedSource
        return URL(fileURLWithPath: decodedPath, relativeTo: baseURL).standardizedFileURL
    }

    nonisolated private var readerAssetSchemeName: String {
        "opennow-file"
    }

    nonisolated private func makeReaderAssetURLString(for fileURL: URL) -> String {
        let standardizedFileURL = fileURL.standardizedFileURL
        let encodedPath = standardizedFileURL.path
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? standardizedFileURL.path

        var components = URLComponents()
        components.scheme = readerAssetSchemeName
        components.host = ""
        components.percentEncodedPath = encodedPath
        return components.url!.absoluteString
    }

    nonisolated private func normalizeLocalAssetSource(_ source: String) -> String {
        let trimmed = source
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))

        guard let hashIndex = trimmed.firstIndex(of: "#") else {
            return String(trimmed.split(separator: "?", maxSplits: 1).first ?? "")
        }

        let withoutFragment = String(trimmed[..<hashIndex])
        return String(withoutFragment.split(separator: "?", maxSplits: 1).first ?? "")
    }

    nonisolated private func collectRelativeLocalAssetURLs(in markdown: String, baseURL: URL) -> [URL] {
        let patterns = [
            #"!\[[^\]]*\]\(([^)]+)\)"#,
            #"<img[^>]+src=["']([^"']+)["']"#
        ]

        var urls: [URL] = []
        var seenPaths = Set<String>()

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
            for match in regex.matches(in: markdown, range: range) {
                guard match.numberOfRanges >= 2,
                      let captureRange = Range(match.range(at: 1), in: markdown)
                else {
                    continue
                }

                let captured = markdown[captureRange]
                    .split(separator: " ", maxSplits: 1)
                    .first
                    .map(String.init)?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "<>")) ?? ""

                guard isRelativePath(captured) else {
                    continue
                }

                let decodedPath = normalizeLocalAssetSource(captured).removingPercentEncoding ?? normalizeLocalAssetSource(captured)
                let resolvedURL = URL(fileURLWithPath: decodedPath, relativeTo: baseURL).standardizedFileURL
                if seenPaths.insert(resolvedURL.path).inserted {
                    urls.append(resolvedURL)
                }
            }
        }

        return urls
    }

    nonisolated private func isRelativePath(_ value: String) -> Bool {
        if value.isEmpty || value.hasPrefix("/") || value.hasPrefix("#") {
            return false
        }

        if let url = URL(string: value), url.scheme != nil {
            return false
        }

        return true
    }
}
