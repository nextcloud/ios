// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

extension UINavigationItem {
    /// Sets the navigation title using a custom titleView with two labels (base + extension)
    /// to prevent Unicode bidi override attacks from visually disguising the real file extension.
    func setBidiSafeTitle(_ filename: String) {
        let nsName = filename as NSString
        let ext = nsName.pathExtension
        let base = nsName.deletingPathExtension

        if ext.isEmpty || base.isEmpty {
            self.titleView = nil
            self.title = filename
        } else {
            let baseLabel = UILabel()
            baseLabel.text = base
            baseLabel.font = .systemFont(ofSize: 17, weight: .semibold)
            baseLabel.lineBreakMode = .byTruncatingMiddle
            baseLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            baseLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let extLabel = UILabel()
            extLabel.text = "." + ext
            extLabel.font = .systemFont(ofSize: 17, weight: .semibold)
            extLabel.setContentHuggingPriority(.required, for: .horizontal)
            extLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

            let stack = UIStackView(arrangedSubviews: [baseLabel, extLabel])
            stack.axis = .horizontal
            stack.alignment = .firstBaseline
            stack.spacing = 0

            self.titleView = stack
            self.title = nil
        }
    }
}
