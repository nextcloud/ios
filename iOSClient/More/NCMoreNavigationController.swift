// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI

class NCMoreNavigationController: NCMainNavigationController {
    override func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController is NCCollectionViewCommon || viewController is NCActivity || viewController is NCTrash {
            setNavigationBarAppearance()
        } else {
            setNavigationBarAppearance(backgroundColor: .systemGray6)
        }
    }

    // MARK: - Right

    override func createRightMenu() async -> UIMenu? {
        if collectionViewCommon?.layoutKey == global.layoutViewRecent, let items = await self.createRightMenuActions() {
            return UIMenu(children: [items.select, items.viewStyleSubmenu])
        } else if collectionViewCommon?.layoutKey == global.layoutViewOffline, let items = await self.createRightMenuActions() {
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu])
        } else if collectionViewCommon?.layoutKey == global.layoutViewShares, let items = await self.createRightMenuActions() {
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu])
        } else if collectionViewCommon?.layoutKey == global.layoutViewGroupfolders, let items = await self.createRightMenuActions() {
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu])
        } else if collectionViewCommon?.layoutKey == global.layoutViewFiles, let items = await self.createRightMenuActions() {
            let additionalSettings = UIMenu(title: "", options: .displayInline, children: [items.showDescription])
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSettings])
        } else if trashViewController != nil, let items = await self.createTrashRightMenuActions() {
            return UIMenu(children: items)
        }

        return nil
    }
}
