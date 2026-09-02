// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension UIView {
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
}
