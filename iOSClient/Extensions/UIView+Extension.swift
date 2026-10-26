// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension UIView {
    private static let firstStrongIsolate = "\u{2068}"
    private static let popDirectionalIsolate = "\u{2069}"

    /// Bidi embeddings, overrides and isolates, the C0 separators and every newline: a stray PDI or a
    /// paragraph break would end the isolates of `setBidiSafeWrappingFilename` (UAX #9, X6a and X8).
    private static let isolateBreakingCharacters = CharacterSet(charactersIn: "\u{202A}"..."\u{202E}")
        .union(CharacterSet(charactersIn: "\u{2066}"..."\u{2069}"))
        .union(CharacterSet(charactersIn: "\u{001C}"..."\u{001E}"))
        .union(.newlines)

    func makeCircularBackground(withColor backgroundColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.layer.cornerRadius = self.frame.size.width / 2
        self.layer.masksToBounds = true
    }

    /// Splits a filename into base name + extension across two labels to prevent
    /// Unicode bidi override attacks from visually disguising the real file extension.
    func setBidiSafeFilename(
        _ filename: String,
        isDirectory: Bool,
        titleLabel: UILabel?,
        extensionLabel: UILabel?
    ) {
        let nsName = filename as NSString
        let ext = nsName.pathExtension
        let base = nsName.deletingPathExtension

        if isDirectory || ext.isEmpty || base.isEmpty {
            titleLabel?.text = filename
            extensionLabel?.text = ""
            extensionLabel?.isHidden = true
        } else {
            titleLabel?.text = base
            extensionLabel?.text = "." + ext
            extensionLabel?.isHidden = false
        }
    }

    /// Moves the extension back into `titleLabel` so the whole filename can wrap. Bidi formatting and line breaks
    /// are dropped, and base and extension each get their own Unicode isolate, so nothing in the name can move the
    /// extension and RTL names still end with it, just as with the two labels.
    func setBidiSafeWrappingFilename(titleLabel: UILabel, extensionLabel: UILabel) {
        let title = NSMutableAttributedString(attributedString: titleLabel.attributedText ?? NSAttributedString())

        while let range = title.string.rangeOfCharacter(from: Self.isolateBreakingCharacters) {
            title.deleteCharacters(in: NSRange(range, in: title.string))
        }

        if !extensionLabel.isHidden, title.length > 0 {
            let titleAttributes = title.attributes(at: 0, effectiveRange: nil)
            let ext = String((extensionLabel.text ?? "").unicodeScalars.filter { !Self.isolateBreakingCharacters.contains($0) })

            title.insert(NSAttributedString(string: Self.firstStrongIsolate, attributes: titleAttributes), at: 0)
            title.append(NSAttributedString(string: Self.popDirectionalIsolate, attributes: titleAttributes))
            title.append(NSAttributedString(string: Self.firstStrongIsolate + ext + Self.popDirectionalIsolate, attributes: [
                .font: extensionLabel.font as UIFont,
                .foregroundColor: extensionLabel.textColor as UIColor
            ]))
        }

        titleLabel.attributedText = title
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        extensionLabel.isHidden = true
    }
}

extension UIScrollView {
    func hideTopScrollEdgeEffect() {
        if #available(iOS 27.0, *) {
            topEdgeEffect.isHidden = true
        }
    }
}
