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

extension Array where Element == NCMenuAction {
    var listHeight: CGFloat { reduce(0, { $0 + $1.rowHeight }) }
}

class NCMenu: UITableViewController {

    var actions = [NCMenuAction]()
    var menuColor = UIColor.systemBackground
    var textColor = UIColor.label

    static func makeNCMenu(with actions: [NCMenuAction], menuColor: UIColor, textColor: UIColor) -> NCMenu? {
        let menuViewController = UIStoryboard(name: "NCMenu", bundle: nil).instantiateInitialViewController() as? NCMenu
        menuViewController?.actions = actions
        menuViewController?.menuColor = menuColor
        menuViewController?.textColor = textColor
        return menuViewController
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        self.view.backgroundColor = menuColor
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let menuAction = actions[indexPath.row]
        if let action = menuAction.action {
            self.dismiss(animated: true, completion: nil)
            action(menuAction)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let action = actions[indexPath.row]
        guard action.title != NCMenuAction.seperatorIdentifier else {
            let cell = UITableViewCell()
            cell.backgroundColor = .separator
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "menuActionCell", for: indexPath)
        cell.tintColor = NCBrandColor.shared.customer
        cell.backgroundColor = menuColor
        let actionIconView = cell.viewWithTag(1) as? UIImageView
        let actionNameLabel = cell.viewWithTag(2) as? UILabel
        let actionDetailLabel = cell.viewWithTag(3) as? UILabel

        if action.action == nil {
            cell.selectionStyle = .none
        }
        if let details = action.details {
            actionDetailLabel?.text = details
            actionDetailLabel?.textColor = textColor
            actionNameLabel?.isHidden = false
        } else { actionDetailLabel?.isHidden = true }

        if action.isOn {
            actionIconView?.image = action.onIcon
            actionNameLabel?.text = action.onTitle
            actionNameLabel?.textColor = textColor
        } else {
            actionIconView?.image = action.icon
            actionNameLabel?.text = action.title
            actionNameLabel?.textColor = textColor
        }

        cell.accessoryType = action.selectable && action.selected ? .checkmark : .none

        return cell
    }

    // MARK: - Tabel View Layout

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        actions[indexPath.row].title == NCMenuAction.seperatorIdentifier ? NCMenuAction.seperatorHeight : UITableView.automaticDimension
    }
}
extension NCMenu: FloatingPanelControllerDelegate {

    func floatingPanel(_ fpc: FloatingPanelController, layoutFor size: CGSize) -> FloatingPanelLayout {
        return NCMenuFloatingPanelLayout(actionsHeight: self.actions.listHeight)
    }

    func floatingPanel(_ fpc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout {
        return NCMenuFloatingPanelLayout(actionsHeight: self.actions.listHeight)
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
