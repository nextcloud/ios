//
//  NSMutableAttributedString+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/05/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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

extension NSMutableAttributedString {

    func setColor(color: UIColor, font: UIFont? = nil, forText stringValue: String) {

        let range: NSRange = self.mutableString.range(of: stringValue, options: .caseInsensitive)

        self.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
        if let font = font {
            self.addAttribute(NSAttributedString.Key.font, value: font, range: range)
        }
    }
}
