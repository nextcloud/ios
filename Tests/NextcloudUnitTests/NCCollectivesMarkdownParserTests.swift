// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

@Suite("Collectives Markdown parser")
struct NCCollectivesMarkdownParserTests {
    private typealias Node = NCCollectivesMarkdownNode

    @Test("Headings, paragraphs with hard breaks and rules")
    func basicBlocks() {
        let nodes = NCCollectivesMarkdownParser.parse("""
        # Title
        First line\\
        second line
        same paragraph

        ---
        """)

        #expect(nodes == [.heading(level: 1, text: "Title"),
                          .paragraph("First line\nsecond line same paragraph"),
                          .rule])
    }

    @Test("Nested bullet, ordered and task lists")
    func lists() {
        let nodes = NCCollectivesMarkdownParser.parse("""
        * One
          * Nested
        * Two

        3. Third
        4. Fourth

        - [ ] Open task
        - [x] Done task
        """)

        #expect(nodes.count == 3)
        #expect(nodes[0] == .list(ordered: false, start: 0, items: [
            .init(isChecked: nil, children: [.paragraph("One"), .list(ordered: false, start: 0, items: [.init(isChecked: nil, children: [.paragraph("Nested")])])]),
            .init(isChecked: nil, children: [.paragraph("Two")])
        ]))
        #expect(nodes[1] == .list(ordered: true, start: 3, items: [
            .init(isChecked: nil, children: [.paragraph("Third")]),
            .init(isChecked: nil, children: [.paragraph("Fourth")])
        ]))
        #expect(nodes[2] == .list(ordered: false, start: 0, items: [
            .init(isChecked: false, children: [.paragraph("Open task")]),
            .init(isChecked: true, children: [.paragraph("Done task")])
        ]))
    }

    @Test("Tables keep alignment, escaped pipes and pad short rows")
    func table() {
        let nodes = NCCollectivesMarkdownParser.parse("""
        | Name | Count | Note |
        |:-----|:-----:|-----:|
        | **A** | 1 | a \\| b |
        | B | 2 |
        """)

        #expect(nodes == [.table(header: ["Name", "Count", "Note"],
                                 alignments: [.leading, .center, .trailing],
                                 rows: [["**A**", "1", "a | b"], ["B", "2", ""]])])
    }

    @Test("Details boxes and callouts contain their own blocks")
    func detailsAndCallouts() {
        let nodes = NCCollectivesMarkdownParser.parse("""
        <details>
        <summary>More info</summary>

        Hidden **text**

        - item

        </details>

        ::: warn
        Careful
        :::
        """)

        #expect(nodes == [
            .details(summary: "More info", isOpen: false, children: [
                .paragraph("Hidden **text**"),
                .list(ordered: false, start: 0, items: [.init(isChecked: nil, children: [.paragraph("item")])])
            ]),
            .callout(kind: "warn", children: [.paragraph("Careful")])
        ])
    }

    @Test("Images become embeds, also inside lists, but not inside code")
    func embeds() {
        let nodes = NCCollectivesMarkdownParser.parse("""
        ![Berg](.attachments.83/Berg%20Panorama.png)

        ```swift
        ![not an image](code.png)
        ```

        - ![report](.attachments.83/report.pdf "Report")
        """)

        #expect(nodes[0] == .embed(alt: "Berg", source: ".attachments.83/Berg%20Panorama.png"))
        #expect(nodes[1] == .code(language: "swift", text: "![not an image](code.png)"))
        #expect(Node.embedSources(in: nodes) == [".attachments.83/Berg%20Panorama.png", ".attachments.83/report.pdf"])
    }

    @Test("Inline formatting and links are kept")
    func inline() {
        let text = NCCollectivesMarkdownContentView.inline("**bold** and [link](https://nextcloud.com)")
        #expect(String(text.characters) == "bold and link")
        #expect(text.runs.contains { $0.link == URL(string: "https://nextcloud.com") })
    }
}
