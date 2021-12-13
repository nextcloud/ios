//
//  NCMenuCells.swift
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

class NCMenuTextFieldCell: UITableViewCell, NCMenuCell, UITextFieldDelegate {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var textField: UITextField!
    var action: NCMenuTextField?

    func setup(with action: NCMenuTextField) {
        self.action = action
        textField.text = action.text
        textField.placeholder = action.placeholder
        textField.delegate = self
        setupUI()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func keyboardWillShow(notification : Notification) {
        let frameEndUserInfoKey = UIResponder.keyboardFrameEndUserInfoKey
        
        guard let info = notification.userInfo,
              let centerObject = textField.superview?.convert(textField.center, to: nil),
              let keyboardFrame = info[frameEndUserInfoKey] as? CGRect
        else { return }
        
        let diff = keyboardFrame.origin.y - centerObject.y - textField.frame.height
        if diff < 0 {
            parentViewController?.view.frame.origin.y = diff
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        parentViewController?.view.frame.origin.y = 0
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        action?.text = textField.text ?? ""
        textField.resignFirstResponder()
        return true
    }
}

class NCMenuToggleCell: UITableViewCell, NCMenuCell {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var toggle: UISwitch!
    var action: NCMenuToggle?
    func setup(with action: NCMenuToggle) {
        self.action = action
        toggle.isOn = action.isOn
        toggle.addTarget(self, action: #selector(self.toggle(sender:)), for: .valueChanged)
        setupUI()
    }

    @objc func toggle(sender: Any) {
        print(#function, sender)
        action?.isOn = toggle.isOn
    }
}

class NCMenuButtonCell: UITableViewCell, NCMenuCell {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var icon: UIImageView!
    var action: NCMenuButton?

    func setup(with action: NCMenuButton) {
        self.action = action
        
        if action.action == nil {
            selectionStyle = .none
        }

        icon.image = action.isOn ? action.onIcon : action.icon
        label.text = action.isOn ? action.onTitle : action.title

        accessoryType = action.selectable && action.selected ? .checkmark : .none
    }
}

protocol NCMenuCell {
    associatedtype ActionType: NCMenuAction
    var label: UILabel! { get set }
    var icon: UIImageView! { get set }

    var action: ActionType? { get set }
    func setup(with action: ActionType)
}

extension NCMenuCell {
    func setupUI() {
        label.text = action?.title
        icon.image = action?.icon
    }
}

