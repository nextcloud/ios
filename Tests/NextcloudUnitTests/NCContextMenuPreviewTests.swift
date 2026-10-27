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
        #expect(cell.labelTitle.text == "Report.pdf")
        #expect(cell.labelExtension.isHidden)
    }

    @Test("List cell grows so a long name shows in full")
    func listLongName() throws {
        let cell = try makeListCell(fileName: longName)

        cell.showFullName()

        #expect(cell.bounds.height > listSize.height)
        #expect(cell.labelTitle.text == longName)
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
        #expect(cell.labelTitle.text == longName)
        #expect(cell.bounds.contains(cell.labelTitle.convert(cell.labelTitle.bounds, to: cell).insetBy(dx: 1, dy: 1)))
    }

    @Test("Every bidi attack from the bidi-safe filename tests keeps the standard preview", arguments: [
        "malware\u{202E}fdp.exe",                        // RLO
        "invoice\u{2067}cod.exe",                        // RLI
        "report\u{202D}exe.pdf",                         // LRO
        "\u{202E}\u{2066}safe_document\u{2069}cod.exe", // RLO + LRI + PDI
        "image\u{2066}exe.jpg\u{2069}.png",              // LRI + PDI
        "notes\u{2068}exe.bat",                          // FSI
        "folder\u{202E}exe.txt"                          // RLO in a folder name
    ])
    func bidiAttacksAreProblematic(name: String) {
        #expect(NCContextMenuPreviewView.isProblematic(name))
    }

    @Test("Names one label could reorder or break keep the standard preview", arguments: [
        "report\u{2069}\u{202E}fdp..exe",                 // stray PDI + RLO
        "file\u{200F}.exe",                              // RLM
        "file\u{061C}.exe",                              // ALM
        "Invoice\u{2029}\u{200F}payment.pdf.exe",        // paragraph separator + RLM
        "photo\n.exe",                                   // newline
        "שלום.txt",                                       // Hebrew
        "تقرير.pdf",                                      // Arabic
        "invoice \u{05D0}.pdf.exe"                       // Hebrew letter in a Latin name
    ])
    func reorderingNamesAreProblematic(name: String) {
        #expect(NCContextMenuPreviewView.isProblematic(name))
    }

    @Test("Plain names get the full name preview", arguments: [
        "photo.jpg",
        "document.pdf",
        "archive.tar.gz",
        "README",
        ".gitignore",
        "My Folder.backup",
        "ExportBlock-52f1c0de-a8b9-4c3d-9e2f-774cebeb-Part-1",
        "Résumé – final (2).docx",
        "😀 party.png",
        "日本語のファイル名.txt"
    ])
    func plainNamesAreNotProblematic(name: String) {
        #expect(!NCContextMenuPreviewView.isProblematic(name))
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

    private func makeCell<Cell: UICollectionViewCell>(_ type: Cell.Type, size: CGSize) throws -> Cell {
        let nib = UINib(nibName: String(describing: type), bundle: Bundle(for: type))
        let cell = try #require(nib.instantiate(withOwner: nil).first as? Cell)
        cell.frame = CGRect(origin: .zero, size: size)

        return cell
    }
}
