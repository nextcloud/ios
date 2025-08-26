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
                .full: FloatingPanelLayoutAnchor(
                    absoluteInset: finalPanelHeight,
                    edge: .bottom,
                    referenceGuide: .superview
                )
            ]
        }
    private let panelHeight: CGFloat
    private let finalPanelHeight: CGFloat

    init(panelHeight: CGFloat, controller: NCMainTabBarController?) {
        self.panelHeight = panelHeight
        var window: UIWindow?

        if let controller {
            window = controller.window
        } else if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene {
            window = windowScene.windows.first(where: { $0.isKeyWindow })
        }

        let safeBottom = controller?.viewIfLoaded?.safeAreaInsets.bottom ?? 0
        let requestedHeight = panelHeight + safeBottom

        // ✅ Limite massimo: finestra - topMargin
        let topMargin: CGFloat = 64
        let windowHeight = window?.bounds.height ?? UIScreen.main.bounds.height
        let maxHeight = windowHeight - topMargin

        // ✅ Imposta finalPanelHeight con limite
        self.finalPanelHeight = min(requestedHeight, maxHeight)
    }

    func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
        return [
            surfaceView.leftAnchor.constraint(equalTo: view.leftAnchor),
            surfaceView.rightAnchor.constraint(equalTo: view.rightAnchor)
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

        surfaceView.appearance = {
            let appearance = SurfaceAppearance.transparent()
            return appearance
        }()

        surfaceView.grabberHandle.accessibilityLabel = NSLocalizedString("_cart_controller_", comment: "")

        let collapseName = NSLocalizedString("_dismiss_menu_", comment: "")
        let collapseAction = UIAccessibilityCustomAction(name: collapseName, target: self, selector: #selector(accessibilityActionCollapsePanel(_:)))

        surfaceView.grabberHandle.accessibilityCustomActions = [collapseAction]
        surfaceView.grabberHandle.isAccessibilityElement = true

        contentInsetAdjustmentBehavior = .never
    }

    @objc private func accessibilityActionCollapsePanel(_ sender: Any?) {
        self.dismiss(animated: true)
     }
}
