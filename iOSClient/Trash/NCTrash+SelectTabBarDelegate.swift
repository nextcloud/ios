// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
        let ids = selectOcId.map { $0 }
        setEditMode(false)

        Task {
            for id in ids {
                await restoreItem(with: id)
            }
        }
    }

    func delete() {
        let ids = selectOcId.map { $0 }
        setEditMode(false)

        Task {
            if ids.count > 0, ids.count == datasource?.count {
                await emptyTrash()
            } else {
                await self.deleteItems(with: ids)
            }
        }
    }

    func setEditMode(_ editMode: Bool) {
        Task {
            isEditMode = editMode
            selectOcId.removeAll()

            navigationItem.hidesBackButton = editMode
            navigationController?.interactivePopGestureRecognizer?.isEnabled = !editMode

            await (self.navigationController as? NCMainNavigationController)?.setNavigationRightItems()

            collectionView.reloadData()
        }
    }
}
