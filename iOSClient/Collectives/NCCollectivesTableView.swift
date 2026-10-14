// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

/// A Markdown table with header, column alignment and borders; scrolls sideways when wider than the page.
struct NCCollectivesTableView: View {
    let header: [String]
    let alignments: [NCCollectivesMarkdownNode.ColumnAlignment]
    let rows: [[String]]

    private let cellPadding: CGFloat = 10

    /// Fixed column widths make long text wrap instead of growing the horizontal scroll view.
    private var columnWidths: [CGFloat] {
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let bold = UIFont.boldSystemFont(ofSize: font.pointSize)
        return header.indices.map { column in
            let texts = [(header[column], bold)] + rows.map { ($0[column], font) }
            let widest = texts.flatMap { text, font in
                String(NCCollectivesMarkdownContentView.inline(text).characters)
                    .components(separatedBy: "\n")
                    .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            }.max() ?? 0
            return min(max(ceil(widest) + 4, 44), 220) + cellPadding * 2
        }
    }

    var body: some View {
        let widths = columnWidths
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                row(header, widths: widths)
                    .font(.subheadline.bold())
                    .background(Color(.secondarySystemFill))
                ForEach(Array(rows.enumerated()), id: \.offset) { _, cells in
                    row(cells, widths: widths)
                        .font(.subheadline)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(.separator)))
        }
    }

    private func row(_ cells: [String], widths: [CGFloat]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { column, text in
                cell(text, column: column, width: widths[column])
            }
        }
        // Lets every cell stretch to the height of the tallest one in the row.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func cell(_ text: String, column: Int, width: CGFloat) -> some View {
        let alignment = alignments.indices.contains(column) ? alignments[column] : .leading
        let frameAlignment: Alignment = switch alignment {
        case .leading: .topLeading
        case .center: .top
        case .trailing: .topTrailing
        }
        let textAlignment: TextAlignment = switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
        return Text(NCCollectivesMarkdownContentView.inline(text))
            .multilineTextAlignment(textAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, cellPadding)
            .padding(.vertical, 8)
            .frame(width: width, alignment: frameAlignment)
            .frame(maxHeight: .infinity, alignment: frameAlignment)
            .border(Color(.separator), width: 0.5)
    }
}
