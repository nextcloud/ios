// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCMoreNavigationController: NCMainNavigationController {
    override func setNavigationRightItems() {
        guard let collectionViewCommon else {
            return
        }

        func createMenu() -> [UIMenuElement] {
            guard let items = self.createMenuActions()
            else {
                return []
            }

            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [items.foldersOnTop])

            if collectionViewCommon.layoutKey == global.layoutViewRecent {
                return [items.select, items.viewStyleSubmenu]
            } else if collectionViewCommon.layoutKey == global.layoutViewOffline {
                return [items.select, items.viewStyleSubmenu]
            } else {
                return [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSubmenu]
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

            let menuButton = UIBarButtonItem(image: utility.loadImage(named: "ellipsis.circle"), menu: UIMenu(children: createMenu()))
            menuButton.tag = menuButtonTag
            menuButton.tintColor = NCBrandColor.shared.iconImageColor

            self.collectionViewCommon?.navigationItem.rightBarButtonItems = [menuButton]

        } else {

            self.collectionViewCommon?.navigationItem.rightBarButtonItems?.first?.menu = self.collectionViewCommon?.navigationItem.rightBarButtonItems?.first?.menu?.replacingChildren(createMenu())
        }

        // fix, if the tabbar was hidden before the update, set it in hidden
        if self.tabBarController?.tabBar.isHidden ?? true,
           collectionViewCommon.tabBarSelect?.isHidden() ?? true {
            self.tabBarController?.tabBar.isHidden = true
        }
    }
}
