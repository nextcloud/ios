//
//  NCTrash+SelectTabBarDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

extension NCTrash: NCTrashSelectTabBarDelegate {
    var serverUrl: String {
        ""
    }

    func setNavigationRightItems() {
        guard let tabBarSelect = tabBarSelect as? NCTrashSelectTabBar else { return }

        tabBarSelect.isSelectedEmpty = selectOcId.isEmpty
        if isEditMode {
            tabBarSelect.show()
            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                self.isEditMode = true
                self.setNavigationRightItems()
                self.collectionView.reloadData()
            }
            navigationItem.rightBarButtonItems = [select]
        } else {
            tabBarSelect.hide()
            let menu = UIMenu(children: createMenuActions())
            let menuButton = UIBarButtonItem(image: .init(systemName: "ellipsis.circle"), menu: menu)
            menuButton.isEnabled = true
            navigationItem.rightBarButtonItems = [menuButton]
        }
    }

    func onListSelected() {
        if layoutForView?.layout == NCGlobal.shared.layoutGrid {
            // list layout
            layoutForView?.layout = NCGlobal.shared.layoutList
            NCManageDatabase.shared.setLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: "", layout: layoutForView?.layout)

            self.collectionView.reloadData()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setCollectionViewLayout(self.listLayout, animated: true)
        }
    }

    func onGridSelected() {
        if layoutForView?.layout == NCGlobal.shared.layoutList {
            // grid layout
            layoutForView?.layout = NCGlobal.shared.layoutGrid
            NCManageDatabase.shared.setLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: "", layout: layoutForView?.layout)

            self.collectionView.reloadData()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setCollectionViewLayout(self.gridLayout, animated: true)
        }
    }

    func selectAll() {
        selectOcId = self.datasource.compactMap({ $0.primaryKeyValue })
        collectionView.reloadData()
    }

    func recover() {
        self.selectOcId.forEach(restoreItem)
    }

    func delete() {
        self.selectOcId.forEach(deleteItem)
    }

    func createMenuActions() -> [UIMenuElement] {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: serverUrl) else { return [] }

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""), image: .init(systemName: "checkmark.circle"), attributes: self.datasource.isEmpty ? .disabled : []) { _ in
            self.setNavigationRightItems()
        }

        let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: .init(systemName: "list.bullet"), state: layoutForView.layout == NCGlobal.shared.layoutList ? .on : .off) { _ in
            self.onListSelected()
            self.setNavigationRightItems()
        }

        let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: .init(systemName: "square.grid.2x2"), state: layoutForView.layout == NCGlobal.shared.layoutGrid ? .on : .off) { _ in
            self.onGridSelected()
            self.setNavigationRightItems()
        }

        let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid])

        return [select, viewStyleSubmenu]
    }
}
