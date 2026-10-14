// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Renders page blocks close to how Nextcloud Text shows them. Links go through the `openURL` environment.
struct NCCollectivesMarkdownContentView: View {
    let nodes: [NCCollectivesMarkdownNode]
    let embed: (_ alt: String, _ source: String) -> AnyView
    var listDepth = 0
    var spacing: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                nodeView(node)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func nodeView(_ node: NCCollectivesMarkdownNode) -> some View {
        switch node {
        case .heading(let level, let text):
            Text(Self.inline(text))
                .font(Self.headingFont(level))
                .padding(.top, level <= 2 ? 8 : 4)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(Self.inline(text))
                .fixedSize(horizontal: false, vertical: true)
        case .list(let ordered, let start, let items):
            listView(ordered: ordered, start: start, items: items)
        case .quote(let children):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 4)
                NCCollectivesMarkdownContentView(nodes: children, embed: embed, listDepth: listDepth)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .code(_, let text):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .table(let header, let alignments, let rows):
            NCCollectivesTableView(header: header, alignments: alignments, rows: rows)
        case .details(let summary, let isOpen, let children):
            NCCollectivesDetailsView(summary: Self.inline(summary), isInitiallyOpen: isOpen) {
                NCCollectivesMarkdownContentView(nodes: children, embed: embed, listDepth: listDepth)
            }
        case .callout(let kind, let children):
            callout(kind: kind, children: children)
        case .embed(let alt, let source):
            embed(alt, source)
        case .rule:
            Divider()
                .padding(.vertical, 4)
        }
    }

    // MARK: - Lists

    private func listView(ordered: Bool, start: Int, items: [NCCollectivesMarkdownNode.ListItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    marker(ordered: ordered, number: start + offset, isChecked: item.isChecked)
                    NCCollectivesMarkdownContentView(nodes: item.children, embed: embed, listDepth: listDepth + 1, spacing: 6)
                        .foregroundStyle(item.isChecked == true ? .secondary : .primary)
                }
            }
        }
    }

    @ViewBuilder
    private func marker(ordered: Bool, number: Int, isChecked: Bool?) -> some View {
        if let isChecked {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .foregroundStyle(isChecked ? Color.accentColor : Color.secondary)
                .accessibilityLabel(Text(isChecked ? "✓" : "☐"))
        } else if ordered {
            Text("\(number).")
                .monospacedDigit()
                .frame(minWidth: 22, alignment: .trailing)
        } else {
            // Disc, circle and square, like the web editor.
            Image(systemName: ["circle.fill", "circle", "square.fill"][listDepth % 3])
                .font(.system(size: 6, weight: .bold))
                .frame(minWidth: 14)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                .accessibilityHidden(true)
        }
    }

    // MARK: - Callouts

    private func callout(kind: String, children: [NCCollectivesMarkdownNode]) -> some View {
        let (systemImage, color): (String, Color) = switch kind.lowercased() {
        case "success": ("checkmark.circle.fill", .green)
        case "warn", "warning": ("exclamationmark.triangle.fill", .orange)
        case "error", "danger": ("xmark.octagon.fill", .red)
        default: ("info.circle.fill", .blue)
        }
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            NCCollectivesMarkdownContentView(nodes: children, embed: embed, listDepth: listDepth)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Inline

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title.bold()
        case 2: .title2.bold()
        case 3: .title3.bold()
        case 4: .headline
        case 5: .subheadline.bold()
        default: .footnote.bold()
        }
    }

    /// Bold, italic, strikethrough, inline code and links; line breaks are kept.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace,
                                                              failurePolicy: .returnPartiallyParsedIfPossible)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
