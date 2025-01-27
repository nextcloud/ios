// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCMoreNavigationController: NCMainNavigationController {
    override func setNavigationRightItems() {
        guard let collectionViewCommon else {
            return
        }

        func createMenu() -> UIMenu? {
            guard let items = self.createMenuActions()
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

        if collectionViewCommon.isEditMode {
            collectionViewCommon.tabBarSelect?.update(fileSelect: collectionViewCommon.fileSelect, metadatas: collectionViewCommon.getSelectedMetadatas(), userId: session.userId)
            collectionViewCommon.tabBarSelect?.show()

            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                collectionViewCommon.setEditMode(false)
                collectionViewCommon.collectionView.reloadData()
            }

            self.collectionViewCommon?.navigationItem.rightBarButtonItems = [select]

        } else if self.collectionViewCommon?.navigationItem.rightBarButtonItems == nil || (!collectionViewCommon.isEditMode && !(collectionViewCommon.tabBarSelect?.isHidden() ?? true)) {
            collectionViewCommon.tabBarSelect?.hide()

            let menuButton = UIBarButtonItem(image: utility.loadImage(named: "ellipsis.circle"), menu: createMenu())
            menuButton.tag = menuButtonTag
            menuButton.tintColor = NCBrandColor.shared.iconImageColor

            self.collectionViewCommon?.navigationItem.rightBarButtonItems = [menuButton]

        } else {

            if let rightBarButtonItems = self.collectionViewCommon?.navigationItem.rightBarButtonItems,
               let menuBarButtonItem = rightBarButtonItems.first(where: { $0.tag == menuButtonTag }) {
                menuBarButtonItem.menu = createMenu()
            }
        }

        // fix, if the tabbar was hidden before the update, set it in hidden
        if self.tabBarController?.tabBar.isHidden ?? true,
           collectionViewCommon.tabBarSelect?.isHidden() ?? true {
            self.tabBarController?.tabBar.isHidden = true
        }
    }
}
