// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
