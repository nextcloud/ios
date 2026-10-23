// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 feather2222
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

/// A view that renders a filename as basename + extension in two separate labels,
/// keeping the extension isolated from any bidirectional-control characters in the
/// basename (see `setBidiSafeFilename`).
///
/// Unlike two labels stretched by Auto Layout, this view measures the truncated
/// basename itself and shrinks the title label to the rendered text width, so the
/// extension label always sits immediately after the last visible glyph instead of
/// after the label frame (which left a variable, space-like gap).
final class NCFilenameView: UIView {
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var extensionLabel: UILabel?

    override var intrinsicContentSize: CGSize {
        let titleSize = titleLabel?.intrinsicContentSize ?? .zero
        let extSize = extensionLabel?.intrinsicContentSize ?? .zero
        return CGSize(width: titleSize.width + extSize.width,
                      height: max(titleSize.height, extSize.height))
    }

    /// Baseline alignment is forwarded to the title label so the view behaves like
    /// the labels it replaces inside a baseline-aligned stack view.
    override var forFirstBaselineLayout: UIView {
        titleLabel ?? self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let titleLabel else { return }

        let extHidden = extensionLabel?.isHidden ?? true
        let extWidth = extHidden ? 0 : (extensionLabel?.intrinsicContentSize.width ?? 0)
        let availableTitleWidth = max(bounds.width - extWidth, 0)

        let titleWidth: CGFloat
        if let attributed = titleLabel.attributedText, attributed.length > 0 {
            titleWidth = ceil(Self.truncatedWidth(of: attributed, maxWidth: availableTitleWidth))
        } else if let text = titleLabel.text, let font = titleLabel.font {
            let truncated = Self.middleTruncated(text, font: font, maxWidth: availableTitleWidth)
            titleWidth = ceil((truncated as NSString).size(withAttributes: [.font: font]).width)
        } else {
            titleWidth = 0
        }

        titleLabel.frame = CGRect(x: 0, y: 0, width: titleWidth, height: bounds.height)
        extensionLabel?.frame = CGRect(x: titleWidth, y: 0, width: extWidth, height: bounds.height)
    }

    /// Width of the string as it would be rendered with middle truncation applied,
    /// always capped at `maxWidth`.
    static func truncatedWidth(of text: NSAttributedString, maxWidth: CGFloat) -> CGFloat {
        if text.size().width <= maxWidth {
            return text.size().width
        }
        return middleTruncated(text, maxWidth: maxWidth).size().width
    }

    /// Middle-truncates an attributed string so that it fits into `maxWidth`,
    /// preserving the attributes of the kept head and tail fragments.
    static func middleTruncated(_ text: NSAttributedString, maxWidth: CGFloat) -> NSAttributedString {
        let ellipsis: NSAttributedString
        if text.length > 0 {
            ellipsis = NSAttributedString(string: "…", attributes: text.attributes(at: 0, effectiveRange: nil))
        } else {
            ellipsis = NSAttributedString(string: "…")
        }
        let result = NSMutableAttributedString()

        // Binary search for the longest keepable character count.
        var low = 0
        var high = text.length
        var best = 0
        while low <= high {
            let keep = (low + high) / 2
            let headCount = keep - keep / 2
            let tailCount = keep / 2
            result.replaceCharacters(in: NSRange(location: 0, length: result.length), with: "")
            result.append(text.attributedSubstring(from: NSRange(location: 0, length: headCount)))
            result.append(ellipsis)
            result.append(text.attributedSubstring(from: NSRange(location: text.length - tailCount, length: tailCount)))
            if result.size().width <= maxWidth {
                best = keep
                low = keep + 1
            } else {
                high = keep - 1
            }
        }

        let headCount = best - best / 2
        let tailCount = best / 2
        result.replaceCharacters(in: NSRange(location: 0, length: result.length), with: "")
        result.append(text.attributedSubstring(from: NSRange(location: 0, length: headCount)))
        result.append(ellipsis)
        result.append(text.attributedSubstring(from: NSRange(location: text.length - tailCount, length: tailCount)))
        return NSAttributedString(attributedString: result)
    }

    /// Middle-truncates a plain string so that it fits into `maxWidth` when rendered
    /// with `font`. Returns the original string when it already fits.
    static func middleTruncated(_ text: String, font: UIFont, maxWidth: CGFloat) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        if (text as NSString).size(withAttributes: attributes).width <= maxWidth {
            return text
        }
        let truncated = middleTruncated(NSAttributedString(string: text, attributes: attributes), maxWidth: maxWidth)
        return truncated.string
    }
}
