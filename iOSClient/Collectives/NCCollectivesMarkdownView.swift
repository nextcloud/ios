// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import MarkdownKit

/// Read-only rendering of a page's Markdown with selectable text and tappable links.
struct NCCollectivesMarkdownView: UIViewRepresentable {
    let markdown: String
    /// Returns `true` if the link was handled in the app; otherwise the system opens it.
    let openLink: (URL) -> Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.openLink = openLink
        guard context.coordinator.renderedMarkdown != markdown else { return }
        context.coordinator.renderedMarkdown = markdown

        let parser = MarkdownParser(font: UIFont.preferredFont(forTextStyle: .body), color: .label)
        parser.header.font = UIFont.systemFont(ofSize: 24)
        parser.code.textBackgroundColor = .secondarySystemFill
        parser.code.textHighlightColor = .label
        parser.link.color = textView.tintColor
        parser.quote.indicator = "▎"
        parser.quote.separator = ""
        parser.quote.color = .secondaryLabel
        textView.attributedText = parser.parse(markdown)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(openLink: openLink)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var openLink: (URL) -> Bool
        var renderedMarkdown: String?

        init(openLink: @escaping (URL) -> Bool) {
            self.openLink = openLink
        }

        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            guard case .link(let url) = textItem.content else { return defaultAction }
            return UIAction { [weak self] _ in
                if self?.openLink(url) != true {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}
