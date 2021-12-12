//
//  NCMenuCells.swift
//  Nextcloud
//
//  Created by Henrik Storch on 10.12.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

class NCMenuTextFIeldCell: UITableViewCell, NCMenuCell, UITextFieldDelegate {
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

extension UIView {
    // https://stackoverflow.com/a/24590678
    var parentViewController: UIViewController? {
        // Starts from next (As we know self is not a UIViewController).
        var parentResponder: UIResponder? = self.next
        while parentResponder != nil {
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
            parentResponder = parentResponder?.next
        }
        return nil
    }
}
