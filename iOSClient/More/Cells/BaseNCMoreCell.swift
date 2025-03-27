//
//  BaseNCMoreCell.swift
//  Nextcloud
//
//  Created by Milen on 15.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

class BaseNCMoreCell: UITableViewCell {
    let selectionColor: UIView = UIView()
    let defaultCornerRadius: CGFloat = 10.0

    override var frame: CGRect {
        get {
            return super.frame
        }
        set (newFrame) {
            var frame = newFrame
            let newWidth = frame.width * 0.90
            let space = (frame.width - newWidth) / 2
            frame.size.width = newWidth
            frame.origin.x += space
            super.frame = frame
        }
    }

    open func setupCell(account: String, controller: NCMainTabBarController?) {}

    override func awakeFromNib() {
        super.awakeFromNib()

        selectedBackgroundView = selectionColor
        backgroundColor = .secondarySystemGroupedBackground
        applyCornerRadius()
    }

    func applyCornerRadius() {
        layer.cornerRadius = defaultCornerRadius
    }

    func removeCornerRadius() {
        layer.cornerRadius = 0
    }
}
