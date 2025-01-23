// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCMoreNavigationController: NCMainNavigationController {
    override func setNavigationRightItems() {
        guard let collectionViewCommon else {
            return
        }
        let session = NCSession.shared.getSession(controller: controller)
        let isTabBarHidden = self.tabBarController?.tabBar.isHidden ?? true
        let isTabBarSelectHidden = collectionViewCommon.tabBarSelect.isHidden()

        func createMenuActions() -> [UIMenuElement] {
            guard let layoutForView = database.getLayoutForView(account: session.account, key: collectionViewCommon.layoutKey, serverUrl: collectionViewCommon.serverUrl) else { return [] }

            let select = UIAction(title: NSLocalizedString("_select_", comment: ""),
                                  image: utility.loadImage(named: "checkmark.circle"),
                                  attributes: (collectionViewCommon.dataSource.isEmpty() || NCNetworking.shared.isOffline) ? .disabled : []) { _ in
                collectionViewCommon.setEditMode(true)
                collectionViewCommon.collectionView.reloadData()
            }

            let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: utility.loadImage(named: "list.bullet"), state: layoutForView.layout == global.layoutList ? .on : .off) { _ in

                layoutForView.layout = self.global.layoutList

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": collectionViewCommon.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: utility.loadImage(named: "square.grid.2x2"), state: layoutForView.layout == global.layoutGrid ? .on : .off) { _ in

                layoutForView.layout = self.global.layoutGrid

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": collectionViewCommon.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let mediaSquare = UIAction(title: NSLocalizedString("_media_square_", comment: ""), image: utility.loadImage(named: "square.grid.3x3"), state: layoutForView.layout == global.layoutPhotoSquare ? .on : .off) { _ in

                layoutForView.layout = self.global.layoutPhotoSquare

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": collectionViewCommon.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let mediaRatio = UIAction(title: NSLocalizedString("_media_ratio_", comment: ""), image: utility.loadImage(named: "rectangle.grid.3x2"), state: layoutForView.layout == self.global.layoutPhotoRatio ? .on : .off) { _ in

                layoutForView.layout = self.global.layoutPhotoRatio

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": collectionViewCommon.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid, mediaSquare, mediaRatio])

            let ascending = layoutForView.ascending
            let ascendingChevronImage = utility.loadImage(named: ascending ? "chevron.up" : "chevron.down")
            let isName = layoutForView.sort == "fileName"
            let isDate = layoutForView.sort == "date"
            let isSize = layoutForView.sort == "size"

            let byName = UIAction(title: NSLocalizedString("_name_", comment: ""), image: isName ? ascendingChevronImage : nil, state: isName ? .on : .off) { _ in

                if isName { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "fileName"

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": collectionViewCommon.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""), image: isDate ? ascendingChevronImage : nil, state: isDate ? .on : .off) { _ in

                if isDate { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "date"

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": collectionViewCommon.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""), image: isSize ? ascendingChevronImage : nil, state: isSize ? .on : .off) { _ in

                if isSize { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "size"

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": collectionViewCommon.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""), options: .displayInline, children: [byName, byNewest, byLargest])

            let foldersOnTop = UIAction(title: NSLocalizedString("_directory_on_top_no_", comment: ""), image: utility.loadImage(named: "folder"), state: layoutForView.directoryOnTop ? .on : .off) { _ in

                layoutForView.directoryOnTop = !layoutForView.directoryOnTop

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeLayout,
                                                            object: nil,
                                                            userInfo: ["account": session.account,
                                                                       "serverUrl": collectionViewCommon.serverUrl,
                                                                       "layoutForView": layoutForView])
            }

            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop])

            if collectionViewCommon.layoutKey == global.layoutViewRecent {
                return [select, viewStyleSubmenu]
            } else if collectionViewCommon.layoutKey == global.layoutViewOffline {
                return [select, viewStyleSubmenu]
            } else {
                return [select, viewStyleSubmenu, sortSubmenu, additionalSubmenu]
            }
        }

        if collectionViewCommon.isEditMode {
            collectionViewCommon.tabBarSelect.update(fileSelect: collectionViewCommon.fileSelect, metadatas: collectionViewCommon.getSelectedMetadatas(), userId: session.userId)
            collectionViewCommon.tabBarSelect.show()

            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                collectionViewCommon.setEditMode(false)
                collectionViewCommon.collectionView.reloadData()
            }

            self.collectionViewCommon?.navigationItem.rightBarButtonItems = [select]
        } else if self.collectionViewCommon?.navigationItem.rightBarButtonItems == nil || (!collectionViewCommon.isEditMode && !collectionViewCommon.tabBarSelect.isHidden()) {
            collectionViewCommon.tabBarSelect.hide()

            let menuButton = UIBarButtonItem(image: utility.loadImage(named: "ellipsis.circle"), menu: UIMenu(children: createMenuActions()))
            menuButton.tag = menuButtonTag
            menuButton.tintColor = NCBrandColor.shared.iconImageColor

            self.collectionViewCommon?.navigationItem.rightBarButtonItems = [menuButton]
        } else {
            self.collectionViewCommon?.navigationItem.rightBarButtonItems?.first?.menu = self.collectionViewCommon?.navigationItem.rightBarButtonItems?.first?.menu?.replacingChildren(createMenuActions())
        }

        // fix, if the tabbar was hidden before the update, set it in hidden
        if isTabBarHidden, isTabBarSelectHidden {
            self.tabBarController?.tabBar.isHidden = true
        }
    }
}
