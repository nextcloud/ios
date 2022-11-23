//
//  NCMenu+FloatingPanel.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 16.12.21.
//  Copyright © 2021 Henrik Storch All rights reserved.
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
import FloatingPanel
import UIKit

class NCMenuFloatingPanelLayout: FloatingPanelLayout {
    var position: FloatingPanelPosition = .bottom

    var initialState: FloatingPanelState = .full

    var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] {
        [
            .full: FloatingPanelLayoutAnchor(absoluteInset: topInset, edge: .top, referenceGuide: .superview)
        ]
    }

    let topInset: CGFloat

    init(actionsHeight: CGFloat) {
        // sometimes UIScreen.main.bounds.size.height is not updated correctly
        // this ensures we use the correct height value
        // can't use `layoutFor size` since menu is dieplayed on top of the whole screen not just the VC
        let screenHeight = UIApplication.shared.isLandscape
        ? min(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
        : max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
        let window = UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.first { $0.isKeyWindow }
        let bottomInset = window?.rootViewController?.view.safeAreaInsets.bottom ?? 0
        let panelHeight = CGFloat(actionsHeight) + bottomInset

        topInset = max(48, screenHeight - panelHeight)
    }

    func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
        return [
            surfaceView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            surfaceView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0)
        ]
    }

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return 0.2
    }
}

class NCMenuPanelController: FloatingPanelController {

    var parentPresenter: UIViewController?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.surfaceView.backgroundColor = .systemBackground
        self.isRemovalInteractionEnabled = true
        self.backdropView.dismissalTapGestureRecognizer.isEnabled = true
        self.surfaceView.layer.cornerRadius = 16
        self.surfaceView.clipsToBounds = true

        surfaceView.grabberHandle.accessibilityLabel = NSLocalizedString("_cart_controller_", comment: "")

        let collapseName = NSLocalizedString("_dismiss_menu_", comment: "")
        let collapseAction = UIAccessibilityCustomAction(name: collapseName, target: self, selector: #selector(accessibilityActionCollapsePanel))

        surfaceView.grabberHandle.accessibilityCustomActions = [collapseAction]
        surfaceView.grabberHandle.isAccessibilityElement = true
    }

    @objc private func accessibilityActionCollapsePanel() {
        self.dismiss(animated: true)
     }
}
