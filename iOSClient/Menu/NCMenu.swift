//
//  NCMainMenuTableViewController.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 16.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//  Copyright © 2021 Henrik Storch All rights reserved.
//
//  Author Philippe Weidmann <philippe.weidmann@infomaniak.com>
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

import UIKit
import FloatingPanel

class NCMenu: UITableViewController {

    var actions = [NCMenuAction]()

    static func makeNCMenu(with actions: [NCMenuAction]) -> NCMenu? {
        let menuViewController = UIStoryboard(name: "NCMenu", bundle: nil).instantiateInitialViewController() as? NCMenu
        menuViewController?.actions = actions
        return menuViewController
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let menuAction = actions[indexPath.row] as? NCMenuButton {
            self.dismiss(animated: true, completion: nil)
            menuAction.action?(menuAction)
        } else if let toggleCell = tableView.cellForRow(at: indexPath) as? NCMenuToggleCell {
            toggleCell.toggle.setOn(!toggleCell.toggle.isOn, animated: true)
            toggleCell.toggle(sender: self)
        } else if let textFieldCell = tableView.cellForRow(at: indexPath) as? NCMenuTextFIeldCell {
            textFieldCell.textField.becomeFirstResponder()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let action = actions[indexPath.row] as? NCMenuToggle,
           let toggleCell = tableView.dequeueReusableCell(withIdentifier: "menuToggleCell", for: indexPath) as? NCMenuToggleCell {
            toggleCell.setup(with: action)
            cell = toggleCell
        } else if let action = actions[indexPath.row] as? NCMenuTextField,
                  let textCell = tableView.dequeueReusableCell(withIdentifier: "menuTextFieldCell", for: indexPath) as? NCMenuTextFIeldCell {
            textCell.setup(with: action)
            cell = textCell
        } else if let action = actions[indexPath.row] as? NCMenuButton,
                  let buttonCell = tableView.dequeueReusableCell(withIdentifier: "menuButtonCell", for: indexPath) as? NCMenuButtonCell {
            buttonCell.setup(with: action)
            cell = buttonCell
        } else { cell = UITableViewCell() }

        cell.tintColor = NCBrandColor.shared.customer

        return cell
    }

    // MARK: - Tabel View Layout

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if actions[indexPath.row] is NCMenuTextField {
            return 95
        }
        return 60
    }
}
extension NCMenu: FloatingPanelControllerDelegate {

    func floatingPanel(_ fpc: FloatingPanelController, layoutFor size: CGSize) -> FloatingPanelLayout {
        return NCMenuFloatingPanelLayout(numberOfActions: self.actions.count)
    }

    func floatingPanel(_ fpc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout {
        return NCMenuFloatingPanelLayout(numberOfActions: self.actions.count)
    }

    func floatingPanel(_ fpc: FloatingPanelController, animatorForDismissingWith velocity: CGVector) -> UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: 0.1, curve: .easeInOut)
    }

    func floatingPanel(_ fpc: FloatingPanelController, animatorForPresentingTo state: FloatingPanelState) -> UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: 0.3, curve: .easeInOut)
    }

    func floatingPanelWillEndDragging(_ fpc: FloatingPanelController, withVelocity velocity: CGPoint, targetState: UnsafeMutablePointer<FloatingPanelState>) {
        guard velocity.y > 750 else { return }
        fpc.dismiss(animated: true, completion: nil)
    }
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

protocol NCMenuAction {
    var title: String { get }
    var icon: UIImage { get }
}
