// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI

class NCMoreNavigationController: NCMainNavigationController {
    override func createRightMenu() -> UIMenu? {
        guard let items = self.createMenuActions(),
              let collectionViewCommon
        else {
            return nil
        }

        if collectionViewCommon.layoutKey == global.layoutViewRecent {
            return UIMenu(children: [items.select, items.viewStyleSubmenu])
        } else if collectionViewCommon.layoutKey == global.layoutViewOffline {
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu])
        } else if collectionViewCommon.layoutKey == global.layoutViewShares {
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu])
        } else {
            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [items.foldersOnTop, items.personalFilesOnlyAction, items.showDescription])
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSubmenu])
        }
    }

    override func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController is NCCollectionViewCommon || viewController is NCActivity || viewController is NCTrash {
            setNavigationBarAppearance()
        } else {
            setGroupAppearance()
        }
    }
}
