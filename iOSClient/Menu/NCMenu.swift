//
//  NCMainMenuTableViewController.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 16.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//
//  Author Philippe Weidmann <philippe.weidmann@infomaniak.com>
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
        let actionIconView = cell.viewWithTag(1) as! UIImageView
        let actionNameLabel = cell.viewWithTag(2) as! UILabel

        if action.action == nil {
            cell.selectionStyle = .none
        }

        if (action.isOn) {
            actionIconView.image = action.onIcon
            actionNameLabel.text = action.onTitle
        } else {
            actionIconView.image = action.icon
            actionNameLabel.text = action.title
        }

        cell.accessoryType = action.selectable && action.selected ? .checkmark : .none

        return cell
    }

    // MARK: - Accessibility
    
    open override func accessibilityPerformEscape() -> Bool {
        dismiss(animated: true)
        return true
    }

}
extension NCMenu: FloatingPanelControllerDelegate {

    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
        return NCMenuFloatingPanelLayout(height: self.actions.count * 60 + Int((UIApplication.shared.keyWindow?.rootViewController!.view.safeAreaInsets.bottom)!))
    }
    
    func floatingPanel(_ vc: FloatingPanelController, behaviorFor newCollection: UITraitCollection) -> FloatingPanelBehavior? {
        return NCMenuFloatingPanelBehavior()
    }

    func floatingPanelDidEndDecelerating(_ vc: FloatingPanelController) {
        if vc.position == .hidden {
            vc.dismiss(animated: false, completion: nil)
        }
    }
}

class NCMenuFloatingPanelLayout: FloatingPanelLayout {

    let height: CGFloat

    init(height: Int) {
        self.height = CGFloat(height)
    }

    var initialPosition: FloatingPanelPosition {
        return .full
    }

    var supportedPositions: Set<FloatingPanelPosition> {
        return [.full, .hidden]
    }

    func insetFor(position: FloatingPanelPosition) -> CGFloat? {
        if (position == .full) {
            return max(48, UIScreen.main.bounds.size.height - height)
        } else {
            return nil
        }
    }

    var positionReference: FloatingPanelLayoutReference {
        return .fromSuperview
    }

    public func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
        return [
            surfaceView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            surfaceView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0),
        ]
    }

    func backdropAlphaFor(position: FloatingPanelPosition) -> CGFloat {
        return 0.2
    }
}

public class NCMenuFloatingPanelBehavior: FloatingPanelBehavior {

    public func addAnimator(_ fpc: FloatingPanelController, to: FloatingPanelPosition) -> UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: 0.3, curve: .easeInOut)
    }

    public func removeAnimator(_ fpc: FloatingPanelController, from: FloatingPanelPosition) -> UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: 0.1, curve: .easeInOut)
    }

    public func moveAnimator(_ fpc: FloatingPanelController, from: FloatingPanelPosition, to: FloatingPanelPosition) -> UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: 0.1, curve: .easeInOut)
    }

}

class NCMenuPanelController: FloatingPanelController {

    var parentPresenter: UIViewController?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.surfaceView.backgroundColor = NCBrandColor.shared.systemBackground
        self.isRemovalInteractionEnabled = true
        self.surfaceView.cornerRadius = 16
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
