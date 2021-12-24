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
        if let menuAction = actions[indexPath.section] as? NCMenuButton {
            guard let action = menuAction.action else { return }
            action(menuAction)
            dismiss(animated: true)
        } else if let menuAction = actions[indexPath.section] as? NCMenuButtonGroup {
            menuAction.shouldSelect(buttonIx: indexPath.row)
        } else if let toggleCell = tableView.cellForRow(at: indexPath) as? NCMenuToggleCell {
            toggleCell.toggle.setOn(!toggleCell.toggle.isOn, animated: true)
            toggleCell.toggle(sender: self)
        } else if let textFieldCell = tableView.cellForRow(at: indexPath) as? NCMenuTextFieldCell {
            textFieldCell.textField.becomeFirstResponder()
        } else {
            print(#function, "[ERROR] No menu action found")
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return actions.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (actions[section] as? NCMenuButtonGroup)?.actions.count ?? 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let action = actions[indexPath.section] as? NCMenuToggle,
           let toggleCell = tableView.dequeueReusableCell(withIdentifier: "menuToggleCell", for: indexPath) as? NCMenuToggleCell {
            toggleCell.setup(with: action)
            cell = toggleCell
        } else if let action = actions[indexPath.section] as? NCMenuTextField,
                  let textCell = tableView.dequeueReusableCell(withIdentifier: "menuTextFieldCell", for: indexPath) as? NCMenuTextFieldCell {
            textCell.setup(with: action)
            cell = textCell
        } else if let action = actions[indexPath.section] as? NCMenuButton,
                  let buttonCell = tableView.dequeueReusableCell(withIdentifier: "menuButtonCell", for: indexPath) as? NCMenuButtonCell {
            buttonCell.setup(with: action)
            cell = buttonCell
        } else if let action = actions[indexPath.section] as? NCMenuButtonGroup,
                  let buttonCell = tableView.dequeueReusableCell(withIdentifier: "menuButtonCell", for: indexPath) as? NCMenuButtonCell {
            action.cells.append(buttonCell)
            buttonCell.setup(with: action.actions[indexPath.row])
            cell = buttonCell
        } else { cell = UITableViewCell() }

        cell.tintColor = NCBrandColor.shared.customer

        return cell
    }

    // MARK: - Tabel View Layout

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if actions[indexPath.section] is NCMenuTextField {
            return 95
        }
        return 60
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        actions[section] is NCMenuButtonGroup ? 20 : 0
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { nil }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        (actions[section] as? NCMenuButtonGroup)?.title
    }
}
extension NCMenu: FloatingPanelControllerDelegate {

    func floatingPanel(_ fpc: FloatingPanelController, layoutFor size: CGSize) -> FloatingPanelLayout {
        return NCMenuFloatingPanelLayout(numberOfActions: self.actions.actionCount)
    }

    func floatingPanel(_ fpc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout {
        return NCMenuFloatingPanelLayout(numberOfActions: self.actions.actionCount)
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
