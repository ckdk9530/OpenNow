import Down
import Foundation

struct GFMTableTransformer: Sendable {
    nonisolated init() {}

    struct Result {
        let markdown: String
        let replacements: [String: String]

        nonisolated func restore(in html: String) -> String {
            replacements.reduce(html) { partial, entry in
                let token = entry.key
                let tableHTML = entry.value
                let escapedToken = NSRegularExpression.escapedPattern(for: token)
                let paragraphPattern = "<p>\\s*\(escapedToken)\\s*</p>"

                let withoutParagraphWrapper: String
                if let regex = try? NSRegularExpression(pattern: paragraphPattern, options: [.caseInsensitive]) {
                    let range = NSRange(partial.startIndex..<partial.endIndex, in: partial)
                    withoutParagraphWrapper = regex.stringByReplacingMatches(
                        in: partial,
                        options: [],
                        range: range,
                        withTemplate: tableHTML
                    )
                } else {
                    withoutParagraphWrapper = partial
                }

                return withoutParagraphWrapper.replacingOccurrences(of: token, with: tableHTML)
            }
        }
    }

    nonisolated func transform(_ markdown: String) -> Result {
        let lines = markdown.components(separatedBy: .newlines)
        var output: [String] = []
        var replacements: [String: String] = [:]
        var index = 0
        var activeFence: Fence?

        while index < lines.count {
            let line = lines[index]

            if let fence = Fence(line: line) {
                if let currentFence = activeFence, currentFence.matches(line: line) {
                    activeFence = nil
                } else if activeFence == nil {
                    activeFence = fence
                }

                output.append(line)
                index += 1
                continue
            }

            guard activeFence == nil,
                  index + 1 < lines.count,
                  let headerCells = tableCells(from: line),
                  let alignments = tableAlignments(from: lines[index + 1]),
                  alignments.isEmpty == false
            else {
                output.append(line)
                index += 1
                continue
            }

            var rows: [[String]] = []
            var rowIndex = index + 2
            while rowIndex < lines.count, let cells = tableCells(from: lines[rowIndex]) {
                rows.append(cells)
                rowIndex += 1
            }

            let token = "OPENNOW_TABLE_BLOCK_\(replacements.count)__TOKEN"
            replacements[token] = renderTable(
                headerCells: headerCells,
                alignments: alignments,
                rows: rows
            )
            output.append(token)
            index = rowIndex
        }

        return Result(markdown: output.joined(separator: "\n"), replacements: replacements)
    }

    nonisolated private func renderTable(headerCells: [String], alignments: [TableAlignment], rows: [[String]]) -> String {
        let normalizedHeaderCells = normalizeCells(headerCells, count: alignments.count)
        let normalizedRows = rows.map { normalizeCells($0, count: alignments.count) }

        let thead = normalizedHeaderCells.enumerated().map { index, cell in
            makeCell(tag: "th", contents: cell, alignment: alignments[index])
        }.joined()

        let tbody = normalizedRows.map { row in
            let cells = row.enumerated().map { index, cell in
                makeCell(tag: "td", contents: cell, alignment: alignments[index])
            }.joined()

            return "<tr>\(cells)</tr>"
        }.joined()

        if tbody.isEmpty {
            return "<table><thead><tr>\(thead)</tr></thead></table>"
        }

        return "<table><thead><tr>\(thead)</tr></thead><tbody>\(tbody)</tbody></table>"
    }

    nonisolated private func makeCell(tag: String, contents: String, alignment: TableAlignment) -> String {
        let renderedContents = renderInlineMarkdown(contents)
        let alignAttribute = alignment.htmlAttribute.map { #" align="\#($0)""# } ?? ""
        return "<\(tag)\(alignAttribute)>\(renderedContents)</\(tag)>"
    }

    nonisolated private func renderInlineMarkdown(_ markdown: String) -> String {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return ""
        }

        do {
            let html = try Down(markdownString: trimmed).toHTML()
            return stripSingleParagraphWrapper(from: html)
        } catch {
            return trimmed.htmlEscaped()
        }
    }

    nonisolated private func stripSingleParagraphWrapper(from html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<p>"),
              trimmed.hasSuffix("</p>")
        else {
            return trimmed
        }

        let start = trimmed.index(trimmed.startIndex, offsetBy: 3)
        let end = trimmed.index(trimmed.endIndex, offsetBy: -4)
        return String(trimmed[start..<end])
    }

    nonisolated private func normalizeCells(_ cells: [String], count: Int) -> [String] {
        let trimmedCells = Array(cells.prefix(count))
        if trimmedCells.count == count {
            return trimmedCells
        }

        return trimmedCells + Array(repeating: "", count: count - trimmedCells.count)
    }

    nonisolated private func tableCells(from line: String) -> [String]? {
        guard line.contains("|") else {
            return nil
        }

        var cells: [String] = []
        var current = ""
        var isEscaped = false

        for character in line {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }

            if character == "\\" {
                current.append(character)
                isEscaped = true
                continue
            }

            if character == "|" {
                cells.append(current)
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(character)
            }
        }

        cells.append(current)

        if line.trimmingCharacters(in: .whitespaces).hasPrefix("|"), cells.first?.isEmpty == true {
            cells.removeFirst()
        }

        if line.trimmingCharacters(in: .whitespaces).hasSuffix("|"), cells.last?.isEmpty == true {
            cells.removeLast()
        }

        let trimmedCells = cells.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmedCells.isEmpty ? nil : trimmedCells
    }

    nonisolated private func tableAlignments(from line: String) -> [TableAlignment]? {
        guard let cells = tableCells(from: line), cells.isEmpty == false else {
            return nil
        }

        let alignments = cells.compactMap(TableAlignment.init)
        guard alignments.count == cells.count else {
            return nil
        }

        return alignments
    }
}

private struct Fence {
    let marker: Character
    let count: Int

    nonisolated init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.first, marker == "`" || marker == "~" else {
            return nil
        }

        let markerCount = trimmed.prefix { $0 == marker }.count
        guard markerCount >= 3 else {
            return nil
        }

        self.marker = marker
        self.count = markerCount
    }

    nonisolated func matches(line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let markerCount = trimmed.prefix { $0 == marker }.count
        return markerCount >= count
    }
}

private enum TableAlignment {
    case left
    case center
    case right
    case unspecified

    nonisolated init?(_ raw: String) {
        let cleaned = raw.replacingOccurrences(of: " ", with: "")
        guard cleaned.isEmpty == false else {
            return nil
        }

        let hasLeadingColon = cleaned.hasPrefix(":")
        let hasTrailingColon = cleaned.hasSuffix(":")
        let dashBody = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ":"))

        guard dashBody.count >= 2, dashBody.allSatisfy({ $0 == "-" }) else {
            return nil
        }

        switch (hasLeadingColon, hasTrailingColon) {
        case (true, true):
            self = .center
        case (true, false):
            self = .left
        case (false, true):
            self = .right
        case (false, false):
            self = .unspecified
        }
    }

    nonisolated var htmlAttribute: String? {
        switch self {
        case .left:
            return "left"
        case .center:
            return "center"
        case .right:
            return "right"
        case .unspecified:
            return nil
        }
    }
}

private extension String {
    nonisolated func htmlEscaped() -> String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
