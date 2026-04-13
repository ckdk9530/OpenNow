import Foundation

enum OutlineExtractor {
    static func extract(from markdown: String) -> [OutlineItem] {
        let lines = markdown.components(separatedBy: .newlines)
        var items: [OutlineItem] = []
        var counts: [String: Int] = [:]
        var isInsideFence = false
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                isInsideFence.toggle()
                index += 1
                continue
            }

            if isInsideFence {
                index += 1
                continue
            }

            if let heading = parseATXHeading(line) {
                let anchor = uniqueAnchor(for: heading.title, counts: &counts)
                items.append(OutlineItem(title: heading.title, level: heading.level, anchor: anchor))
                index += 1
                continue
            }

            if index + 1 < lines.count,
               let heading = parseSetextHeading(titleLine: line, underlineLine: lines[index + 1]) {
                let anchor = uniqueAnchor(for: heading.title, counts: &counts)
                items.append(OutlineItem(title: heading.title, level: heading.level, anchor: anchor))
                index += 2
                continue
            }

            index += 1
        }

        return items
    }

    static func slugify(_ title: String) -> String {
        let lowered = title.lowercased()
        let normalized = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }

            if CharacterSet.whitespacesAndNewlines.contains(scalar) || scalar == "-" {
                return "-"
            }

            return "-"
        }

        let collapsed = String(normalized)
            .split(separator: "-")
            .filter { $0.isEmpty == false }
            .joined(separator: "-")

        return collapsed.isEmpty ? "section" : collapsed
    }

    private static func parseATXHeading(_ line: String) -> (title: String, level: Int)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let level = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else {
            return nil
        }

        let remainder = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
        guard remainder.isEmpty == false else {
            return nil
        }

        let title = remainder.replacingOccurrences(of: #"[\s#]+$"#, with: "", options: .regularExpression)
        return (title, level)
    }

    private static func parseSetextHeading(titleLine: String, underlineLine: String) -> (title: String, level: Int)? {
        let title = titleLine.trimmingCharacters(in: .whitespaces)
        let underline = underlineLine.trimmingCharacters(in: .whitespaces)
        guard title.isEmpty == false, underline.isEmpty == false else {
            return nil
        }

        if underline.allSatisfy({ $0 == "=" }) {
            return (title, 1)
        }

        if underline.allSatisfy({ $0 == "-" }) {
            return (title, 2)
        }

        return nil
    }

    private static func uniqueAnchor(for title: String, counts: inout [String: Int]) -> String {
        let slug = slugify(title)
        let currentCount = counts[slug, default: 0]
        counts[slug] = currentCount + 1
        return currentCount == 0 ? slug : "\(slug)-\(currentCount)"
    }
}
