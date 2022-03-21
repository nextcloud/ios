//
//  UIToolbar+Extension.swift
//  Nextcloud
//
//  Created by Henrik Storch on 18.03.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

extension UIToolbar {
    static func toolbar(onClear: (() -> Void)?, completion: @escaping () -> Void) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        var buttons: [UIBarButtonItem] = []
        let doneButton = UIBarButtonItem(title: NSLocalizedString("_done_", comment: ""), style: .done) {
            completion()
        }
        buttons.append(doneButton)

        if let onClear = onClear {
            let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
            let clearButton = UIBarButtonItem(title: NSLocalizedString("_clear_", comment: ""), style: .plain) {
                onClear()
            }
            buttons.append(contentsOf: [spaceButton, clearButton])
        }
        toolbar.setItems(buttons, animated: false)
        return toolbar
    }
}
