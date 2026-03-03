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
