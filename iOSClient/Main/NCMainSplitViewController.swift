// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

/// Lets UIKit size the sidebar column beside the existing tab controller on iPad.
@MainActor
final class NCMainSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    let mainController: NCMainTabBarController
    private var sidebarController: UIHostingController<NCSidebarView>?

    init(mainController: NCMainTabBarController) {
        self.mainController = mainController
        super.init(style: .doubleColumn)
        delegate = self
        preferredSplitBehavior = .tile
        preferredDisplayMode = .oneBesideSecondary
        displayModeButtonVisibility = .never
        showsSecondaryOnlyButton = false

        let hostingController = UIHostingController(rootView: mainController.makeSidebarView(isDocked: true))
        hostingController.view.backgroundColor = .clear
        sidebarController = hostingController
        // Keep our SwiftUI header in the sidebar instead of using a navigation toolbar.
        let navigationController = UINavigationController(rootViewController: hostingController)
        navigationController.setNavigationBarHidden(true, animated: false)
        setViewController(navigationController, for: .primary)
        setViewController(mainController, for: .secondary)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSidebar() {
        // Refresh account and notification availability when the user opens the column.
        sidebarController?.rootView = mainController.makeSidebarView(isDocked: true)
        // Request two adjacent columns explicitly, rather than only revealing the primary.
        preferredDisplayMode = .oneBesideSecondary
        show(.primary)
    }

    func hideSidebar() {
        preferredDisplayMode = .secondaryOnly
        hide(.primary)
    }

    func splitViewController(
        _ splitViewController: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
    ) -> UISplitViewController.Column {
        // Compact windows keep the tabs visible; their opener presents our existing overlay.
        .secondary
    }

    func splitViewControllerDidExpand(_ splitViewController: UISplitViewController) {
        mainController.removeSidebarOverlay()
    }
}
