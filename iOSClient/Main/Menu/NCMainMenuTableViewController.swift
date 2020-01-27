//
//  NCMainMenuTableViewController.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 16.01.20.
//  Copyright © 2020 TWS. All rights reserved.
//

import UIKit
import FloatingPanel

class NCMainMenuTableViewController: UITableViewController {

    var actions = [NCMenuAction]()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let menuAction = actions[indexPath.row]
        self.dismiss(animated: true, completion: nil)
        menuAction.action?(menuAction)
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
        cell.tintColor = NCBrandColor.sharedInstance.customer
        let action = actions[indexPath.row]
        let actionIconView = cell.viewWithTag(1) as! UIImageView
        let actionNameLabel = cell.viewWithTag(2) as! UILabel

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

}
extension NCMainMenuTableViewController: FloatingPanelControllerDelegate {

    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
        return NCMainMenuFloatingPanelLayout(height: min(self.actions.count * 60, Int(self.view.frame.height) - 48))
    }

    func floatingPanel(_ vc: FloatingPanelController, behaviorFor newCollection: UITraitCollection) -> FloatingPanelBehavior? {
        return NCMainMenuFloatingPanelBehavior()
    }

}

class NCMainMenuFloatingPanelLayout: FloatingPanelLayout {

    let height: CGFloat

    init(height: Int) {
        self.height = CGFloat(height)
    }

    var initialPosition: FloatingPanelPosition {
        return .tip
    }

    var supportedPositions: Set<FloatingPanelPosition> {
        return [.tip]
    }

    func insetFor(position: FloatingPanelPosition) -> CGFloat? {
        switch position {
        case .tip: return height
        default: return nil
        }
    }

    func backdropAlphaFor(position: FloatingPanelPosition) -> CGFloat {
        return 0.2
    }
}

public class NCMainMenuFloatingPanelBehavior: FloatingPanelBehavior {

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
