//
//  UIView+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/12/2022.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

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
