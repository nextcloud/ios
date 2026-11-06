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

    /// The last truncated text this view wrote into the title label.
    /// Anything else found in the label is a fresh full text set from outside.
    private var renderedTitle: String?
    /// The full (untruncated) title text, captured before this view truncates it.
    private var fullTitle: NSAttributedString?

    override var intrinsicContentSize: CGSize {
        // Report the full title width (not the currently rendered truncation) so
        // the enclosing stack always sizes this view from complete content.
        let titleSize = fullTitle?.size() ?? titleLabel?.intrinsicContentSize ?? .zero
        let extSize = extensionLabel?.intrinsicContentSize ?? .zero
        return CGSize(width: titleSize.width + extSize.width,
                      height: max(titleSize.height, extSize.height))
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Behave like the title label this view replaces: let enclosing stacks and
        // constraints stretch or squeeze the view to the available width, so
        // layoutSubviews always measures the truncation against the real width.
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // This view truncates the title itself; the label must render it as-is.
        titleLabel?.lineBreakMode = .byClipping
    }

    /// Re-measures after the label contents change; called from setBidiSafeFilename.
    func invalidateContentSize() {
        titleLabel?.invalidateIntrinsicContentSize()
        extensionLabel?.invalidateIntrinsicContentSize()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
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

        // UILabel synthesizes attributedText from text/font/color when only text
        // was set, so both assignment styles are covered here.
        if let current = titleLabel.attributedText {
            if current.string != renderedTitle {
                // Fresh text from outside: capture as the new full title.
                fullTitle = current
                titleLabel.lineBreakMode = .byClipping
            } else if let full = fullTitle, current.string == full.string, !current.isEqual(full) {
                // Same untruncated text with changed attributes (e.g. search highlight).
                fullTitle = current
            }
        }

        var titleWidth: CGFloat = 0
        if let fullTitle {
            let truncated = Self.middleTruncated(fullTitle, maxWidth: availableTitleWidth)
            if truncated.string != titleLabel.attributedText?.string {
                titleLabel.attributedText = truncated
            }
            renderedTitle = truncated.string
            titleWidth = min(ceil(truncated.size().width), availableTitleWidth)
        }

        titleLabel.frame = CGRect(x: 0, y: 0, width: titleWidth, height: bounds.height)
        extensionLabel?.frame = CGRect(x: titleWidth, y: 0, width: extWidth, height: bounds.height)
    }

    /// Middle-truncates an attributed string so that it fits into `maxWidth`,
    /// preserving the attributes of the kept head and tail fragments.
    /// Returns the original string when it already fits.
    static func middleTruncated(_ text: NSAttributedString, maxWidth: CGFloat) -> NSAttributedString {
        if text.size().width <= maxWidth {
            return text
        }
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
