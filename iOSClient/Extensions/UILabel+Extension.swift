//
//  UILabel+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/05/23.
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

//
// https://stackoverflow.com/questions/67317975/how-can-i-make-a-padded-uilabel-with-rounded-border-in-ios
//
@IBDesignable class PaddedAndBorderedLabel: UILabel {

    @IBInspectable var topInset: CGFloat = 5.0
    @IBInspectable var bottomInset: CGFloat = 5.0
    @IBInspectable var leftInset: CGFloat = 7.0
    @IBInspectable var rightInset: CGFloat = 7.0
    @IBInspectable var borderColor: UIColor = UIColor.black
    @IBInspectable var borderWidth: CGFloat = 1
    @IBInspectable var cornerRadius: CGFloat = 5

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + leftInset + rightInset,
              height: size.height + topInset + bottomInset)
    }

    override func textRect(forBounds bounds: CGRect,
                           limitedToNumberOfLines n: Int) -> CGRect {
        let b = bounds
        let UIEI = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        let tr = b.inset(by: UIEI)
        let ctr = super.textRect(forBounds: tr, limitedToNumberOfLines: 0)
        // that line of code MUST be LAST in this function, NOT first
        return ctr
    }

    override func draw(_ rect: CGRect) {
        layer.borderColor = borderColor.cgColor
        layer.borderWidth = borderWidth
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true
        super.draw(rect)
    }
}
