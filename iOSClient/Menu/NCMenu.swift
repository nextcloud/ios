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

    var actions: [NCMenuAction]
    var headerActions: [NCMenuAction]?

    var actionsHeight: CGFloat {
        let listHeight = (actions + (headerActions ?? [])).listHeight
        guard #available(iOS 13, *) else { return listHeight }
        return listHeight + 30
    }

    init(actions: [NCMenuAction]) {
        self.actions = actions
        super.init(nibName: nil, bundle: nil)

        let splitActions = actions.split(whereSeparator: { $0.title == NCMenuAction.seperatorIdentifier })
        guard splitActions.count == 2, #available(iOS 13, *) else { return }
        self.actions = Array(splitActions[1])
        self.headerActions = Array(splitActions[0])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "NCMenuCell", bundle: nil), forCellReuseIdentifier: "menuActionCell")
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        tableView.alwaysBounceVertical = false
    }

    func setupCell(_ cell: UIView, with action: NCMenuAction) {
        let actionIconView = cell.viewWithTag(1) as? UIImageView
        let actionNameLabel = cell.viewWithTag(2) as? UILabel
        let actionDetailLabel = cell.viewWithTag(3) as? UILabel
        cell.tintColor = NCBrandColor.shared.customer

        if let details = action.details {
            actionDetailLabel?.text = details
            actionNameLabel?.isHidden = false
        } else { actionDetailLabel?.isHidden = true }

        if action.isOn {
            actionIconView?.image = action.onIcon
            actionNameLabel?.text = action.onTitle
        } else {
            actionIconView?.image = action.icon
            actionNameLabel?.text = action.title
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return headerActions?.listHeight ?? 0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerActions = headerActions else { return nil }

        let headerView = UIStackView()
        headerView.distribution = .fillProportionally
        headerView.axis = .vertical
        headerView.backgroundColor = tableView.backgroundColor

        for action in headerActions {
            guard let cell = Bundle.main.loadNibNamed("NCMenuCell", owner: self, options: nil)?[0] as? UIView else { continue }
            setupCell(cell, with: action)
            cell.backgroundColor = tableView.backgroundColor
            headerView.addArrangedSubview(cell)
            let separator = UIView()
            separator.heightAnchor.constraint(equalToConstant: NCMenuAction.seperatorHeight).isActive = true
            separator.backgroundColor = NCBrandColor.shared.separator
            headerView.addArrangedSubview(separator)
        }
        return headerView
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
            cell.backgroundColor = NCBrandColor.shared.separator
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "menuActionCell", for: indexPath)
        if action.action == nil {
            cell.selectionStyle = .none
        }
        setupCell(cell, with: action)

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
        return NCMenuFloatingPanelLayout(actionsHeight: self.actionsHeight)
    }

    func floatingPanel(_ fpc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout {
        return NCMenuFloatingPanelLayout(actionsHeight: self.actionsHeight)
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
