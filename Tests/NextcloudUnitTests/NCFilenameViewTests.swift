// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 feather2222
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
@testable import Nextcloud

@Suite("NCFilenameView")
@MainActor
struct NCFilenameViewTests {

    private let font = UIFont.preferredFont(forTextStyle: .body)

    @Test("Short text is not truncated")
    func shortTextUntouched() {
        let text = "photo"
        let width = (text as NSString).size(withAttributes: [.font: font]).width

        let result = NCFilenameView.middleTruncated(text, font: font, maxWidth: width + 10)

        #expect(result == text)
    }

    @Test("Long text is middle-truncated and fits the available width")
    func longTextFits() {
        let text = "Combo 01x01 very long file name manuale"
        let maxWidth: CGFloat = 120

        let result = NCFilenameView.middleTruncated(text, font: font, maxWidth: maxWidth)
        let resultWidth = (result as NSString).size(withAttributes: [.font: font]).width

        #expect(result.contains("…"))
        #expect(resultWidth <= maxWidth)
        #expect(result.hasPrefix("Combo"))
        #expect(result.hasSuffix("manuale"))
    }

    @Test("Truncation keeps as much text as fits")
    func truncationIsMaximal() {
        let text = "Combo 01x01 very long file name manuale"
        let maxWidth: CGFloat = 120

        let result = NCFilenameView.middleTruncated(text, font: font, maxWidth: maxWidth)
        // One more kept character must no longer fit.
        let keptCount = result.count - 1
        let headCount = keptCount - keptCount / 2 + 1
        let tailCount = keptCount / 2
        let longer = String(text.prefix(headCount)) + "…" + String(text.suffix(tailCount))
        let longerWidth = (longer as NSString).size(withAttributes: [.font: font]).width

        #expect(longerWidth > maxWidth)
    }

    @Test("Very narrow width still returns an ellipsis-only result")
    func tinyWidth() {
        let result = NCFilenameView.middleTruncated("some long name", font: font, maxWidth: 1)

        #expect(result == "…")
    }

    @Test("Extension label sits immediately after the truncated title glyphs")
    func extensionIsTightAfterTitle() {
        let view = NCFilenameView(frame: CGRect(x: 0, y: 0, width: 120, height: 24))
        let titleLabel = UILabel()
        let extensionLabel = UILabel()
        titleLabel.font = font
        extensionLabel.font = font
        view.titleLabel = titleLabel
        view.extensionLabel = extensionLabel
        view.addSubview(titleLabel)
        view.addSubview(extensionLabel)

        titleLabel.text = "Combo 01x01 very long file name manuale"
        extensionLabel.text = ".avi"
        extensionLabel.isHidden = false

        view.layoutSubviews()

        let extWidth = extensionLabel.intrinsicContentSize.width
        #expect(titleLabel.frame.width <= 120 - extWidth)
        #expect(extensionLabel.frame.minX == titleLabel.frame.maxX)
        // The title is truncated, so it must use nearly all of its available width.
        #expect(titleLabel.frame.width > (120 - extWidth) * 0.8)
    }

    @Test("Hidden extension gives the title the full width")
    func hiddenExtension() {
        let view = NCFilenameView(frame: CGRect(x: 0, y: 0, width: 120, height: 24))
        let titleLabel = UILabel()
        let extensionLabel = UILabel()
        titleLabel.font = font
        extensionLabel.font = font
        view.titleLabel = titleLabel
        view.extensionLabel = extensionLabel
        view.addSubview(titleLabel)
        view.addSubview(extensionLabel)

        titleLabel.text = "folder"
        extensionLabel.isHidden = true

        view.layoutSubviews()

        #expect(extensionLabel.frame.width == 0)
        #expect(titleLabel.frame.width == ceil(("folder" as NSString).size(withAttributes: [.font: font]).width))
    }
}

private extension String {
    func size(withAttributes font: UIFont) -> CGFloat {
        (self as NSString).size(withAttributes: [.font: font]).width
    }
}
