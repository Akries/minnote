import Foundation

struct PlainNote: Identifiable, Equatable {
    let id: UUID
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var fileURL: URL?
    var format: NoteFormat
    var tag: NoteTag?

    var title: String {
        guard let firstLine = firstContentLine
        else {
            return "无标题"
        }

        let cleaned = cleanTitle(firstLine)
        return cleaned.isEmpty ? "无标题" : String(cleaned.prefix(40))
    }

    var filenameTitle: String? {
        guard let firstLine = firstContentLine else {
            return nil
        }

        let cleaned = cleanTitle(firstLine)
        return cleaned.isEmpty ? nil : cleaned
    }

    var preview: String {
        let lines = text.components(separatedBy: .newlines)
        let firstContentIndex = lines.firstIndex {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let bodyLines = lines.enumerated()
            .filter { index, line in
                index != firstContentIndex
                    && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .map(\.element)

        let compactText = bodyLines
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !compactText.isEmpty else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "空白便笺" : "无正文"
        }

        return String(compactText.prefix(54))
    }

    var characterCount: Int {
        text.count
    }

    private var firstContentLine: String? {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private func cleanTitle(_ line: String) -> String {
        var cleaned = line

        while cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct NoteOutlineItem: Identifiable, Equatable {
    let id: String
    let title: String
    let level: Int
    let location: Int
}

struct NoteOutlineNavigationTarget: Identifiable, Equatable {
    let id = UUID()
    let location: Int
}

extension PlainNote {
    var outlineItems: [NoteOutlineItem] {
        NoteOutlineParser.outlineItems(in: text, format: format)
    }
}

private enum NoteOutlineParser {
    private struct TextHeadingRule {
        let expression: NSRegularExpression
        let level: Int
        let titleCaptureIndex: Int

        init(_ pattern: String, level: Int, titleCaptureIndex: Int = 1) {
            self.expression = try! NSRegularExpression(pattern: pattern)
            self.level = level
            self.titleCaptureIndex = titleCaptureIndex
        }
    }

    private static let textHeadingRules: [TextHeadingRule] = [
        TextHeadingRule(#"^\s*(第[0-9零〇一二三四五六七八九十百千万两]+[章篇卷部][^\n]*)\s*$"#, level: 1),
        TextHeadingRule(#"^\s*(第[0-9零〇一二三四五六七八九十百千万两]+[节条款][^\n]*)\s*$"#, level: 2),
        TextHeadingRule(#"^\s*\d+\.\d+\.\d+[\.、]?\s+(.+?)\s*$"#, level: 3),
        TextHeadingRule(#"^\s*\d+\.\d+[\.、]?\s+(.+?)\s*$"#, level: 2),
        TextHeadingRule(#"^\s*\d+[\.、]\s+(.+?)\s*$"#, level: 1),
        TextHeadingRule(#"^\s*[（(][0-9零〇一二三四五六七八九十]+[）)]\s*(.+?)\s*$"#, level: 2),
        TextHeadingRule(#"^\s*[零〇一二三四五六七八九十]+[、.]\s*(.+?)\s*$"#, level: 1)
    ]

    static func outlineItems(in text: String, format: NoteFormat) -> [NoteOutlineItem] {
        let nsText = text as NSString
        var items: [NoteOutlineItem] = []

        nsText.enumerateSubstrings(
            in: NSRange(location: 0, length: nsText.length),
            options: [.byLines, .substringNotRequired]
        ) { _, range, _, _ in
            let line = nsText.substring(with: range)

            guard let heading = heading(in: line, format: format) else {
                return
            }

            items.append(
                NoteOutlineItem(
                    id: "\(range.location)-\(heading.level)-\(heading.title)",
                    title: heading.title,
                    level: heading.level,
                    location: range.location
                )
            )
        }

        return items
    }

    private static func heading(in line: String, format: NoteFormat) -> (level: Int, title: String)? {
        if let heading = markdownHeading(in: line) {
            return heading
        }

        guard format == .text else {
            return nil
        }

        return textHeading(in: line)
    }

    private static func markdownHeading(in line: String) -> (level: Int, title: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let level = trimmed.prefix { $0 == "#" }.count

        guard (1...3).contains(level) else {
            return nil
        }

        let contentStart = trimmed.index(trimmed.startIndex, offsetBy: level)
        guard contentStart < trimmed.endIndex,
              trimmed[contentStart].isWhitespace
        else {
            return nil
        }

        let rawTitle = trimmed[contentStart...]
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(
                of: #"\s+#+\s*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespaces)

        return normalizedHeading(level: level, title: rawTitle)
    }

    private static func textHeading(in line: String) -> (level: Int, title: String)? {
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        for rule in textHeadingRules {
            guard let match = rule.expression.firstMatch(in: line, range: fullRange),
                  let rawTitle = capturedText(in: nsLine, match: match, index: rule.titleCaptureIndex)
            else {
                continue
            }

            return normalizedHeading(level: rule.level, title: rawTitle)
        }

        return nil
    }

    private static func capturedText(
        in line: NSString,
        match: NSTextCheckingResult,
        index: Int
    ) -> String? {
        let range = match.range(at: index)

        guard range.location != NSNotFound,
              range.length > 0
        else {
            return nil
        }

        return line.substring(with: range)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedHeading(level: Int, title: String) -> (level: Int, title: String)? {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedTitle.isEmpty,
              cleanedTitle.count <= 120
        else {
            return nil
        }

        return (min(max(level, 1), 3), cleanedTitle)
    }
}
