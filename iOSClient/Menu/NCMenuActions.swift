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
    var icon: UIImage? { get }
}

extension Array where Element == NCMenuAction {
    var actionCount: Int {
        self.reduce(0, {
            if let gropuActions = ($1 as? NCMenuButtonGroup)?.actions.count { return $0 + gropuActions + 1 }
            else { return $0 + 1 }
        })
    }
}

class NCMenuButtonGroup: NCMenuAction {
    var title: String
    var selectedIx: Int
    var actions: [NCMenuButton]
    var cells: [NCMenuButtonCell] = []
    var icon: UIImage?

    internal init(title: String, selectedIx: Int, actions: [NCMenuButton], cells: [NCMenuButtonCell] = [], icon: UIImage? = nil) {
        self.title = title
        self.selectedIx = selectedIx
        self.actions = actions
        self.cells = cells
        self.icon = icon
        
        for buttonIx in 0..<self.actions.count {
            actions[buttonIx].selectable = true
            actions[buttonIx].selected = buttonIx == selectedIx
        }
    }

    func shouldSelect(buttonIx: Int) {
        guard buttonIx != selectedIx else { return }
        selectedIx = buttonIx
        for cellIx in 0..<cells.count {
            cells[cellIx].action?.selected = cellIx == selectedIx
            cells[cellIx].updateUI()
        }
        actions[selectedIx].action?(actions[selectedIx])
    }
}

class NCMenuButton: NCMenuAction {
    let title: String
    let icon: UIImage?
    var selectable: Bool
    var onTitle: String?
    var onIcon: UIImage?
    var selected: Bool = false
    var isOn: Bool = false
    var action: ((NCMenuButton) -> Void)?

    init(title: String, icon: UIImage?, action: ((NCMenuButton) -> Void)?) {
        self.title = NSLocalizedString(title, comment: "")
        self.icon = icon
        self.action = action
        self.selectable = false
    }

    init(title: String, icon: UIImage?, onTitle: String? = nil, onIcon: UIImage? = nil, selected: Bool, isOn: Bool, action: ((NCMenuButton) -> Void)?) {
        self.title = NSLocalizedString(title, comment: "")
        self.icon = icon
        self.onTitle = onTitle ?? self.title
        self.onIcon = onIcon ?? icon
        self.action = action
        self.selected = selected
        self.isOn = isOn
        self.selectable = true
    }
}

class NCMenuToggle: NCMenuAction {
    let title: String
    let icon: UIImage?
    var isOn: Bool {
        didSet { onChange?(isOn) }
    }
    let onChange: ((_ newValue: Bool) -> Void)?

    init(title: String, icon: UIImage?, isOn: Bool, onChange: ((_ isOn: Bool) -> Void)?) {
        self.title = NSLocalizedString(title, comment: "")
        self.icon = icon
        self.isOn = isOn
        self.onChange = onChange
    }
}

class NCMenuTextField: NCMenuAction {
    var title: String
    var icon: UIImage?
    var text: String {
        didSet { onCommit?(text) }
    }
    var placeholder: String
    let onCommit: ((_ text: String) -> Void)?

    init(title: String, icon: UIImage?, text: String, placeholder: String, onCommit: ((String) -> Void)?) {
        self.title = NSLocalizedString(title, comment: "")
        self.icon = icon
        self.text = text
        self.placeholder = NSLocalizedString(placeholder, comment: "")
        self.onCommit = onCommit
    }
}
