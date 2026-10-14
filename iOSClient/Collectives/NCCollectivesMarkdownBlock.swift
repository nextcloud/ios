// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A part of a page: Markdown text or an embedded image/attachment (`![alt](source)`).
///
/// Nextcloud Text stores every attachment, not only images, with the image syntax.
enum NCCollectivesMarkdownBlock: Hashable, Sendable {
    case text(String)
    case embed(alt: String, source: String)

    // `![alt](source "optional title")`; sources with spaces are percent-encoded or wrapped in `<>`.
    private static let embedPattern = #"!\[([^\]]*)\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)"#

    static func blocks(from markdown: String) -> [NCCollectivesMarkdownBlock] {
        guard let regex = try? NSRegularExpression(pattern: embedPattern) else { return [.text(markdown)] }
        let string = markdown as NSString
        let codeRanges = fencedCodeRanges(in: string)
        var blocks: [NCCollectivesMarkdownBlock] = []
        var location = 0

        func appendText(upTo end: Int) {
            let text = string.substring(with: NSRange(location: location, length: end - location))
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(text.trimmingCharacters(in: .newlines)))
            }
        }

        for match in regex.matches(in: markdown, range: NSRange(location: 0, length: string.length))
        where !codeRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
            appendText(upTo: match.range.location)
            blocks.append(.embed(alt: string.substring(with: match.range(at: 1)),
                                 source: string.substring(with: match.range(at: 2))))
            location = match.range.location + match.range.length
        }
        appendText(upTo: string.length)
        return blocks
    }

    private static func fencedCodeRanges(in string: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var start: Int?
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: .byLines) { line, range, _, _ in
            guard line?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true else { return }
            if let begin = start {
                ranges.append(NSRange(location: begin, length: range.location + range.length - begin))
                start = nil
            } else {
                start = range.location
            }
        }
        if let start {
            ranges.append(NSRange(location: start, length: string.length - start))
        }
        return ranges
    }
}
