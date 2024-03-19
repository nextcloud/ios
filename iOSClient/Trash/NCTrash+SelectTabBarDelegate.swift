//
//  NCTrash+SelectTabBarDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

extension NCTrash: NCTrashSelectTabBarDelegate {
    func setNavigationRightItems(enableMenu: Bool = false) {
        guard let tabBarSelect = tabBarSelect as? NCTrashSelectTabBar else { return }
        tabBarSelect.isSelectedEmpty = selectOcId.isEmpty

        if isEditMode {
            tabBarSelect.show()
            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                self.setEditMode(false)
            }
            navigationItem.rightBarButtonItems = [select]
        } else {
            tabBarSelect.hide()
            if navigationItem.rightBarButtonItems == nil || enableMenu {
                let menu = UIBarButtonItem(image: .init(systemName: "ellipsis.circle"), menu: UIMenu(children: createMenuActions()))
                navigationItem.rightBarButtonItems = [menu]
            } else {
                navigationItem.rightBarButtonItems?.first?.menu = navigationItem.rightBarButtonItems?.first?.menu?.replacingChildren(createMenuActions())
            }
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
        if let tabBarSelect = tabBarSelect as? NCTrashSelectTabBar {
            tabBarSelect.isSelectedEmpty = selectOcId.isEmpty
        }
        collectionView.reloadData()
    }

    func recover() {
        self.selectOcId.forEach(restoreItem)
    }

    func delete() {
        self.selectOcId.forEach(deleteItem)
    }

    func createMenuActions() -> [UIMenuElement] {
        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: layoutKey, serverUrl: "") else { return [] }

        let select = UIAction(title: NSLocalizedString("_select_", comment: ""), image: .init(systemName: "checkmark.circle"), attributes: self.datasource.isEmpty ? .disabled : []) { _ in
            self.setEditMode(true)
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
