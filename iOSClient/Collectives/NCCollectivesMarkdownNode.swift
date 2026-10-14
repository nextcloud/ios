// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A block of a page as written by Nextcloud Text: GitHub-flavored Markdown plus
/// `<details>` boxes and `::: info` callouts. Inline formatting stays as Markdown text.
indirect enum NCCollectivesMarkdownNode: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list(ordered: Bool, start: Int, items: [ListItem])
    case quote([NCCollectivesMarkdownNode])
    case code(language: String?, text: String)
    case table(header: [String], alignments: [ColumnAlignment], rows: [[String]])
    case details(summary: String, isOpen: Bool, children: [NCCollectivesMarkdownNode])
    case callout(kind: String, children: [NCCollectivesMarkdownNode])
    case embed(alt: String, source: String)
    case rule

    struct ListItem: Hashable, Sendable {
        /// `nil` for plain items, otherwise the state of the task checkbox.
        let isChecked: Bool?
        let children: [NCCollectivesMarkdownNode]
    }

    enum ColumnAlignment: Hashable, Sendable {
        case leading, center, trailing
    }

    /// Sources of all embedded files, including those inside lists, boxes and quotes.
    static func embedSources(in nodes: [NCCollectivesMarkdownNode]) -> [String] {
        nodes.flatMap { node -> [String] in
            switch node {
            case .embed(_, let source): [source]
            case .list(_, _, let items): items.flatMap { embedSources(in: $0.children) }
            case .quote(let children), .details(_, _, let children), .callout(_, let children): embedSources(in: children)
            default: []
            }
        }
    }
}
