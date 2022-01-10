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
        let cell = tableView.dequeueReusableCell(withIdentifier: "menuActionCell", for: indexPath)
        cell.tintColor = NCBrandColor.shared.customer
        let action = actions[indexPath.row]
        let actionIconView = cell.viewWithTag(1) as? UIImageView
        let actionNameLabel = cell.viewWithTag(2) as? UILabel

        if action.action == nil {
            cell.selectionStyle = .none
        }

        if action.isOn {
            actionIconView?.image = action.onIcon
            actionNameLabel?.text = action.onTitle
        } else {
            actionIconView?.image = action.icon
            actionNameLabel?.text = action.title
        }

        cell.accessoryType = action.selectable && action.selected ? .checkmark : .none

        return cell
    }

    // MARK: - Tabel View Layout

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
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

class NCMenuAction {

    let title: String
    let icon: UIImage
    let selectable: Bool
    var onTitle: String?
    var onIcon: UIImage?
    var selected: Bool = false
    var isOn: Bool = false
    var action: ((_ menuAction: NCMenuAction) -> Void)?

    init(title: String, icon: UIImage, action: ((_ menuAction: NCMenuAction) -> Void)?) {
        self.title = title
        self.icon = icon
        self.action = action
        self.selectable = false
    }

    init(title: String, icon: UIImage, onTitle: String? = nil, onIcon: UIImage? = nil, selected: Bool, on: Bool, action: ((_ menuAction: NCMenuAction) -> Void)?) {
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
