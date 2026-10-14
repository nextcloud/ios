// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Splits page Markdown into `NCCollectivesMarkdownNode` blocks, covering what Nextcloud Text writes.
enum NCCollectivesMarkdownParser {
    static func parse(_ markdown: String) -> [NCCollectivesMarkdownNode] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\t", with: "    ")
            .components(separatedBy: "\n")
        return parse(lines: lines[...])
    }

    // MARK: - Blocks

    private static func parse(lines: ArraySlice<String>) -> [NCCollectivesMarkdownNode] {
        var nodes: [NCCollectivesMarkdownNode] = []
        var index = lines.startIndex

        while index < lines.endIndex {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
            } else if let fence = codeFence(trimmed) {
                var end = index + 1
                while end < lines.endIndex, !lines[end].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    end += 1
                }
                let language = String(trimmed.dropFirst(fence.count)).trimmingCharacters(in: .whitespaces)
                nodes.append(.code(language: language.isEmpty ? nil : language, text: lines[(index + 1)..<end].joined(separator: "\n")))
                index = min(end + 1, lines.endIndex)
            } else if trimmed.hasPrefix(":::"), trimmed.count > 3 {
                let end = closingIndex(of: lines, from: index, opens: { $0.hasPrefix(":::") && $0.count > 3 }, closes: { $0 == ":::" })
                let kind = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                nodes.append(.callout(kind: kind, children: parse(lines: lines[(index + 1)..<end])))
                index = min(end + 1, lines.endIndex)
            } else if trimmed.lowercased().hasPrefix("<details") {
                let end = closingIndex(of: lines, from: index,
                                       opens: { $0.lowercased().hasPrefix("<details") },
                                       closes: { $0.lowercased().hasPrefix("</details") })
                nodes.append(details(lines: lines[index..<end], isOpen: trimmed.lowercased().contains(" open")))
                index = min(end + 1, lines.endIndex)
            } else if let heading = heading(trimmed) {
                nodes.append(heading)
                index += 1
            } else if isRule(trimmed) {
                nodes.append(.rule)
                index += 1
            } else if index + 1 < lines.endIndex, trimmed.contains("|"), isTableSeparator(lines[index + 1]) {
                var end = index + 2
                while end < lines.endIndex, lines[end].contains("|"), !lines[end].trimmingCharacters(in: .whitespaces).isEmpty {
                    end += 1
                }
                nodes.append(table(header: trimmed, separator: lines[index + 1], rows: lines[(index + 2)..<end]))
                index = end
            } else if trimmed.hasPrefix(">") {
                var quoted: [String] = []
                while index < lines.endIndex, case let current = lines[index].trimmingCharacters(in: .whitespaces), current.hasPrefix(">") {
                    let content = current.dropFirst()
                    quoted.append(String(content.hasPrefix(" ") ? content.dropFirst() : content))
                    index += 1
                }
                nodes.append(.quote(parse(lines: quoted[...])))
            } else if listMarker(line) != nil {
                let (list, end) = self.list(lines: lines, from: index)
                nodes.append(list)
                index = end
            } else if let embed = embed(trimmed) {
                nodes.append(embed)
                index += 1
            } else {
                var paragraph: [String] = []
                while index < lines.endIndex, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty,
                      paragraph.isEmpty || !startsBlock(lines, at: index) {
                    paragraph.append(lines[index])
                    index += 1
                }
                nodes.append(.paragraph(joinParagraph(paragraph)))
            }
        }
        return nodes
    }

    private static func startsBlock(_ lines: ArraySlice<String>, at index: Int) -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        return codeFence(trimmed) != nil || trimmed.hasPrefix(":::") || trimmed.lowercased().hasPrefix("<details")
            || heading(trimmed) != nil || isRule(trimmed) || trimmed.hasPrefix(">") || listMarker(lines[index]) != nil
            || embed(trimmed) != nil
            || (index + 1 < lines.endIndex && trimmed.contains("|") && isTableSeparator(lines[index + 1]))
    }

    /// Finds the line closing the block opened at `start`, respecting nested blocks of the same kind.
    private static func closingIndex(of lines: ArraySlice<String>, from start: Int,
                                     opens: (String) -> Bool, closes: (String) -> Bool) -> Int {
        var depth = 0
        var index = start
        while index < lines.endIndex {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if index > start, closes(trimmed) {
                depth -= 1
                if depth < 0 { return index }
            } else if index > start, opens(trimmed) {
                depth += 1
            }
            index += 1
        }
        return lines.endIndex
    }

    private static func codeFence(_ trimmed: String) -> String? {
        if trimmed.hasPrefix("```") { return "```" }
        if trimmed.hasPrefix("~~~") { return "~~~" }
        return nil
    }

    private static func heading(_ trimmed: String) -> NCCollectivesMarkdownNode? {
        let level = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(level), trimmed.dropFirst(level).first == " " else { return nil }
        let text = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
        return .heading(level: level, text: text)
    }

    private static func isRule(_ trimmed: String) -> Bool {
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private static func embed(_ trimmed: String) -> NCCollectivesMarkdownNode? {
        let pattern = #"^!\[([^\]]*)\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let alt = Range(match.range(at: 1), in: trimmed),
              let source = Range(match.range(at: 2), in: trimmed) else {
            return nil
        }
        return .embed(alt: String(trimmed[alt]), source: String(trimmed[source]))
    }

    /// Joins paragraph lines; a trailing backslash or two spaces mark a hard line break.
    private static func joinParagraph(_ lines: [String]) -> String {
        var text = ""
        for (offset, line) in lines.enumerated() {
            var content = line.trimmingCharacters(in: .whitespaces)
            let isLast = offset == lines.count - 1
            if isLast {
                text += content
            } else if content.hasSuffix("\\") {
                content.removeLast()
                text += content + "\n"
            } else if line.hasSuffix("  ") {
                text += content + "\n"
            } else {
                text += content + " "
            }
        }
        return text
    }

    // MARK: - Details

    private static func details(lines: ArraySlice<String>, isOpen: Bool) -> NCCollectivesMarkdownNode {
        var body = Array(lines)
        // Drop the opening tag but keep anything written after it on the same line.
        body[0] = body[0].replacingOccurrences(of: #"^\s*<details[^>]*>"#, with: "", options: [.regularExpression, .caseInsensitive])
        var summary = ""
        let joined = body.joined(separator: "\n")
        if let range = joined.range(of: #"<summary[^>]*>([\s\S]*?)</summary>"#, options: [.regularExpression, .caseInsensitive]) {
            summary = String(joined[range])
                .replacingOccurrences(of: #"</?summary[^>]*>"#, with: "", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            body = joined.replacingCharacters(in: range, with: "").components(separatedBy: "\n")
        }
        return .details(summary: summary, isOpen: isOpen, children: parse(lines: body[...]))
    }

    // MARK: - Tables

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(line)
        return !cells.isEmpty && cells.allSatisfy { cell in
            let core = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return !core.isEmpty && core.allSatisfy { $0 == "-" }
        }
    }

    private static func tableCells(_ line: String) -> [String] {
        var row = line.trimmingCharacters(in: .whitespaces)
        if row.hasPrefix("|") { row.removeFirst() }
        if row.hasSuffix("|"), !row.hasSuffix("\\|") { row.removeLast() }
        var cells: [String] = []
        var current = ""
        var previous: Character?
        for character in row {
            if character == "|", previous != "\\" {
                cells.append(current)
                current = ""
            } else {
                current.append(character)
            }
            previous = character
        }
        cells.append(current)
        return cells.map {
            $0.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "\\|", with: "|")
                .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        }
    }

    private static func table(header: String, separator: String, rows: ArraySlice<String>) -> NCCollectivesMarkdownNode {
        let headerCells = tableCells(header)
        let alignments: [NCCollectivesMarkdownNode.ColumnAlignment] = tableCells(separator).map { cell in
            switch (cell.hasPrefix(":"), cell.hasSuffix(":")) {
            case (true, true): .center
            case (false, true): .trailing
            default: .leading
            }
        }
        let columns = headerCells.count
        let bodyRows = rows.map { line -> [String] in
            let cells = tableCells(line)
            return Array((cells + Array(repeating: "", count: max(0, columns - cells.count))).prefix(columns))
        }
        return .table(header: headerCells,
                      alignments: Array((alignments + Array(repeating: .leading, count: max(0, columns - alignments.count))).prefix(columns)),
                      rows: bodyRows)
    }

    // MARK: - Lists

    private struct ListMarker {
        let indent: Int
        let ordered: Bool
        let number: Int
        /// Column where the item's text starts; continuation lines are indented to here.
        let contentIndent: Int
        let content: String
    }

    private static func listMarker(_ line: String) -> ListMarker? {
        let indent = line.prefix { $0 == " " }.count
        let rest = line.dropFirst(indent)
        if let first = rest.first, "-*+".contains(first), rest.dropFirst().first == " " {
            let content = rest.dropFirst(2)
            let extra = content.prefix { $0 == " " }.count
            return ListMarker(indent: indent, ordered: false, number: 0, contentIndent: indent + 2 + extra,
                              content: String(content.dropFirst(extra)))
        }
        let digits = rest.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 9 else { return nil }
        let afterDigits = rest.dropFirst(digits.count)
        guard let delimiter = afterDigits.first, delimiter == "." || delimiter == ")",
              afterDigits.dropFirst().first == " " else { return nil }
        let content = afterDigits.dropFirst(2)
        let extra = content.prefix { $0 == " " }.count
        return ListMarker(indent: indent, ordered: true, number: Int(digits) ?? 1,
                          contentIndent: indent + digits.count + 2 + extra, content: String(content.dropFirst(extra)))
    }

    private static func list(lines: ArraySlice<String>, from start: Int) -> (NCCollectivesMarkdownNode, Int) {
        guard let first = listMarker(lines[start]) else { return (.paragraph(lines[start]), start + 1) }
        var items: [NCCollectivesMarkdownNode.ListItem] = []
        var index = start

        while index < lines.endIndex, let marker = listMarker(lines[index]),
              marker.indent <= first.indent + 1, marker.ordered == first.ordered {
            var itemLines = [marker.content]
            index += 1
            // Lines indented past the marker belong to this item, also across blank lines.
            while index < lines.endIndex {
                let line = lines[index]
                let indent = line.prefix { $0 == " " }.count
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    guard let next = lines[(index + 1)...].first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
                          next.prefix(while: { $0 == " " }).count > first.indent else { break }
                    itemLines.append("")
                } else if indent > first.indent {
                    itemLines.append(String(line.dropFirst(min(indent, marker.contentIndent))))
                } else if listMarker(line) == nil, !startsBlock(lines, at: index), itemLines.count == 1 {
                    // Lazy continuation of the item's first paragraph.
                    itemLines.append(line)
                } else {
                    break
                }
                index += 1
            }

            var isChecked: Bool?
            if let task = itemLines.first, let state = taskState(task) {
                isChecked = state
                itemLines[0] = String(task.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            items.append(.init(isChecked: isChecked, children: parse(lines: itemLines[...])))

            // A blank line between items keeps the list going.
            if index < lines.endIndex, lines[index].trimmingCharacters(in: .whitespaces).isEmpty,
               let next = lines[index...].firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
               let nextMarker = listMarker(lines[next]), nextMarker.indent <= first.indent + 1, nextMarker.ordered == first.ordered {
                index = next
            }
        }
        return (.list(ordered: first.ordered, start: first.number, items: items), index)
    }

    private static func taskState(_ text: String) -> Bool? {
        let prefix = text.prefix(3).lowercased()
        guard text.count == 3 || text.dropFirst(3).first == " " else { return nil }
        switch prefix {
        case "[ ]": return false
        case "[x]": return true
        default: return nil
        }
    }
}
