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
import UIKit

extension NCTrash: NCTrashSelectTabBarDelegate {
    func onListSelected() {
        if layoutForView?.layout == NCGlobal.shared.layoutGrid {
            layoutForView?.layout = NCGlobal.shared.layoutList
            self.database.setLayoutForView(account: session.account, key: layoutKey, serverUrl: "", layout: layoutForView?.layout)

            self.collectionView.reloadData()
            self.collectionView.setCollectionViewLayout(self.listLayout, animated: true)
        }
    }

    func onGridSelected() {
        if layoutForView?.layout == NCGlobal.shared.layoutList {
            layoutForView?.layout = NCGlobal.shared.layoutGrid
            self.database.setLayoutForView(account: session.account, key: layoutKey, serverUrl: "", layout: layoutForView?.layout)

            self.collectionView.reloadData()
            self.collectionView.setCollectionViewLayout(self.gridLayout, animated: true)
        }
    }

    func selectAll() {
        guard let datasource else { return }
        if !selectOcId.isEmpty, datasource.count == selectOcId.count {
            selectOcId = []
        } else {
            selectOcId = datasource.compactMap({ $0.fileId })
        }
        tabBarSelect.update(selectOcId: selectOcId)
        collectionView.reloadData()
    }

    func recover() {
        selectOcId.forEach(restoreItem)
        setEditMode(false)
    }

    func delete() {
        selectOcId.forEach(deleteItem)
        setEditMode(false)
    }

    func setEditMode(_ editMode: Bool) {
        isEditMode = editMode
        selectOcId.removeAll()

        navigationItem.hidesBackButton = editMode
        navigationController?.interactivePopGestureRecognizer?.isEnabled = !editMode

        (self.navigationController as? NCMainNavigationController)?.setNavigationRightItems()

        collectionView.reloadData()
    }
}
