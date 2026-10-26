// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
@testable import Nextcloud

@Suite("Context menu full name preview")
@MainActor
struct NCContextMenuPreviewTests {
    private let listSize = CGSize(width: 390, height: 60)
    private let gridSize = CGSize(width: 120, height: 180)
    private let longName = String(repeating: "ExportBlock-52f1c0de-", count: 8) + "Part-1.zip"

    @Test("List cell keeps its height when the name already fits")
    func listShortName() throws {
        let cell = try makeListCell(fileName: "Report.pdf")

        cell.showFullName()

        #expect(cell.bounds.height == listSize.height)
        #expect(plainText(cell.labelTitle) == "Report.pdf")
        #expect(cell.labelExtension.isHidden)
    }

    @Test("List cell grows so a long name shows in full")
    func listLongName() throws {
        let cell = try makeListCell(fileName: longName)

        cell.showFullName()

        #expect(cell.bounds.height > listSize.height)
        #expect(plainText(cell.labelTitle) == longName)
        #expect(cell.bounds.contains(cell.labelTitle.convert(cell.labelTitle.bounds, to: cell).insetBy(dx: 1, dy: 1)))
    }

    @Test("Grid cell grows below the image so a long name shows in full")
    func gridLongName() throws {
        let cell = try makeGridCell(fileName: longName)
        cell.layoutIfNeeded()
        let imageSize = cell.imageItem.bounds.size

        cell.showFullName()

        #expect(cell.bounds.height > gridSize.height)
        #expect(cell.imageItem.bounds.size == imageSize)
        #expect(plainText(cell.labelTitle) == longName)
        #expect(cell.bounds.contains(cell.labelTitle.convert(cell.labelTitle.bounds, to: cell).insetBy(dx: 1, dy: 1)))
    }

    private func makeListCell(fileName: String) throws -> NCListCell {
        let cell = try makeCell(NCListCell.self, size: listSize)
        cell.setBidiSafeFilename(fileName, isDirectory: false, titleLabel: cell.labelTitle, extensionLabel: cell.labelExtension)

        return cell
    }

    private func makeGridCell(fileName: String) throws -> NCGridCell {
        let cell = try makeCell(NCGridCell.self, size: gridSize)
        cell.setBidiSafeFilename(fileName, isDirectory: false, titleLabel: cell.labelTitle, extensionLabel: cell.labelExtension)

        return cell
    }

    /// The title without the isolates `setBidiSafeWrappingFilename` adds around base and extension.
    private func plainText(_ label: UILabel) -> String? {
        label.text?.filter { !"\u{2068}\u{2069}".contains($0) }
    }

    private func makeCell<Cell: UICollectionViewCell>(_ type: Cell.Type, size: CGSize) throws -> Cell {
        let nib = UINib(nibName: String(describing: type), bundle: Bundle(for: type))
        let cell = try #require(nib.instantiate(withOwner: nil).first as? Cell)
        cell.frame = CGRect(origin: .zero, size: size)

        return cell
    }
}
