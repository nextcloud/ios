//
//  UIBarButton+Extension.swift
//  Nextcloud
//
//  Created by Henrik Storch on 27.01.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
import UIKit

private var actionKey: Void?

extension UIBarButtonItem {
    // https://stackoverflow.com/a/36983811/9506784
    private var _action: () -> Void {
        get {
            return objc_getAssociatedObject(self, &actionKey) as? () -> Void ?? { }
        }
        set {
            objc_setAssociatedObject(self, &actionKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    convenience init(title: String?, style: UIBarButtonItem.Style, action: @escaping () -> Void) {
        self.init(title: title, style: style, target: nil, action: #selector(pressed))
        self.target = self
        self._action = action
    }

    convenience init(image: UIImage?, style: UIBarButtonItem.Style, action: @escaping () -> Void) {
        self.init(image: image, style: style, target: nil, action: #selector(pressed))
        self.target = self
        self._action = action
    }

    @objc private func pressed(sender: UIBarButtonItem) {
        _action()
    }
}
