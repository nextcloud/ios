//
//  NCMenuActions.swift
//  Nextcloud
//
//  Created by Henrik Storch on 13.12.2021.
//  Copyright © 2021 Henrik Storch. All rights reserved.
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
import UIKit

protocol NCMenuAction {
    var title: String { get }
    var icon: UIImage { get }
}

class NCMenuButton: NCMenuAction {

    let title: String
    let icon: UIImage
    let selectable: Bool
    var onTitle: String?
    var onIcon: UIImage?
    var selected: Bool = false
    var isOn: Bool = false
    var action: ((_ menuAction: NCMenuButton) -> Void)?

    init(title: String, icon: UIImage, action: ((_ menuButton: NCMenuButton) -> Void)?) {
        self.title = title
        self.icon = icon
        self.action = action
        self.selectable = false
    }

    init(title: String, icon: UIImage, onTitle: String? = nil, onIcon: UIImage? = nil, selected: Bool, on: Bool, action: ((_ menuButton: NCMenuButton) -> Void)?) {
        self.title = title
        self.icon = icon
        self.onTitle = onTitle ?? title
        self.onIcon = onIcon ?? icon
        self.action = action
        self.selected = selected
        self.isOn = on
        self.selectable = true
    }
}

class NCMenuToggle: NCMenuAction {
    let title: String
    let icon: UIImage
    var isOn: Bool {
        didSet { onChange?(isOn) }
    }
    let onChange: ((_ isOn: Bool) -> Void)?

    init(title: String, icon: UIImage, isOn: Bool, onChange: ((_ isOn: Bool) -> Void)?) {
        self.title = title
        self.icon = icon
        self.isOn = isOn
        self.onChange = onChange
    }
}

class NCMenuTextField: NCMenuAction {
    var title: String
    var icon: UIImage
    var text: String {
        didSet { onCommit?(text) }
    }
    var placeholder: String
    let onCommit: ((_ text: String?) -> Void)?

    init(title: String, icon: UIImage, text: String, placeholder: String, onCommit: ((String?) -> Void)?) {
        self.title = title
        self.icon = icon
        self.text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }
}
