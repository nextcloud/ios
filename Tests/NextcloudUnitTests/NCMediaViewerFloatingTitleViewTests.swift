// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
@testable import Nextcloud

@Suite("Media viewer floating title")
@MainActor
struct NCMediaViewerFloatingTitleViewTests {
    @Test("Preserves the system foreground color")
    func preservesSystemForegroundColor() throws {
        let titleView = NCMediaViewerFloatingTitleView()

        titleView.update(
            primaryText: "Photo.jpg",
            secondaryText: "13 Aug 2026 at 09:17"
        )

        let titleButton = try #require(
            titleView.subviews.first as? UIButton
        )
        titleView.frame = CGRect(x: 0, y: 0, width: 300, height: 44)
        titleView.layoutIfNeeded()

        let configuration = try #require(titleButton.configuration)
        let transformer = try #require(
            configuration.titleTextAttributesTransformer
        )
        var incoming = AttributeContainer()
        incoming.uiKit.foregroundColor = .white
        let outgoing = transformer(incoming)

        #expect(configuration.baseForegroundColor == nil)
        #expect(titleButton.isEnabled)
        #expect(titleButton.isUserInteractionEnabled)
        #expect(titleButton.state == .normal)
        #expect(titleButton.tintAdjustmentMode == .normal)
        #expect(
            titleView.hitTest(
                CGPoint(x: titleView.bounds.midX, y: titleView.bounds.midY),
                with: nil
            ) == nil
        )
        #expect(titleButton.titleLabel?.text == "Photo.jpg")
        #expect(titleButton.subtitleLabel?.text == "13 Aug 2026 at 09:17")
        #expect(outgoing.uiKit.foregroundColor == .white)
        #expect(
            outgoing.uiKit.font == UIFont.systemFont(
                ofSize: 13,
                weight: .semibold
            )
        )

        let normalTextColor = titleButton.titleLabel?.textColor
        titleView.tintAdjustmentMode = .dimmed
        titleView.layoutIfNeeded()

        #expect(titleButton.isEnabled)
        #expect(titleButton.state == .normal)
        #expect(titleButton.tintAdjustmentMode == .normal)
        #expect(titleButton.titleLabel?.text == "Photo.jpg")
        #expect(titleButton.titleLabel?.textColor == normalTextColor)
    }
}
