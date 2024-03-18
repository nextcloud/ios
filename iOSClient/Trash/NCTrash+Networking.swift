//
//  NCTrash+Networking.swift
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

import Realm
import UIKit
import NextcloudKit

extension NCTrash {
    @objc func loadListingTrash() {

        NextcloudKit.shared.listingTrash(showHiddenFiles: false) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        } completion: { account, items, _, error in
            self.refreshControl.endRefreshing()
            if account == self.appDelegate.account {
                NCManageDatabase.shared.deleteTrash(filePath: self.getTrashPath(), account: account)
                NCManageDatabase.shared.addTrash(account: account, items: items)
            }
            self.reloadDataSource()
            if error != .success {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    func restoreItem(with fileId: String) {
        guard let tableTrash = NCManageDatabase.shared.getTrashItem(fileId: fileId, account: appDelegate.account) else { return }
        let fileNameFrom = tableTrash.filePath + tableTrash.fileName
        let fileNameTo = appDelegate.urlBase + "/" + NextcloudKit.shared.nkCommonInstance.dav + "/trashbin/" + appDelegate.userId + "/restore/" + tableTrash.fileName

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: true) { account, error in
            guard error == .success, account == self.appDelegate.account else {
                NCContentPresenter().showError(error: error)
                return
            }
            NCManageDatabase.shared.deleteTrash(fileId: fileId, account: account)
            self.reloadDataSource()
        }
    }

    func emptyTrash() {
        let serverUrlFileName = appDelegate.urlBase + "/" + NextcloudKit.shared.nkCommonInstance.dav + "/trashbin/" + appDelegate.userId + "/trash"

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName) { account, error in
            guard error == .success, account == self.appDelegate.account else {
                NCContentPresenter().showError(error: error)
                return
            }
            NCManageDatabase.shared.deleteTrash(fileId: nil, account: self.appDelegate.account)
            self.reloadDataSource()
        }
    }

    func deleteItem(with fileId: String) {
        guard let tableTrash = NCManageDatabase.shared.getTrashItem(fileId: fileId, account: appDelegate.account) else { return }
        let serverUrlFileName = tableTrash.filePath + tableTrash.fileName

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName) { account, error in
            guard error == .success, account == self.appDelegate.account else {
                NCContentPresenter().showError(error: error)
                return
            }
            NCManageDatabase.shared.deleteTrash(fileId: fileId, account: account)
            self.reloadDataSource()
        }
    }

    func downloadThumbnail(with tableTrash: tableTrash, indexPath: IndexPath) {
        let fileNamePreviewLocalPath = utilityFileSystem.getDirectoryProviderStoragePreviewOcId(tableTrash.fileId, etag: tableTrash.fileName)
        let fileNameIconLocalPath = utilityFileSystem.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)

        NextcloudKit.shared.downloadPreview(fileNamePathOrFileId: tableTrash.fileId,
                                            fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                                            widthPreview: NCGlobal.shared.sizePreview,
                                            heightPreview: NCGlobal.shared.sizePreview,
                                            fileNameIconLocalPath: fileNameIconLocalPath,
                                            sizeIcon: NCGlobal.shared.sizeIcon,
                                            etag: nil,
                                            endpointTrashbin: true) { account, _, imageIcon, _, _, error in
            guard error == .success, let imageIcon = imageIcon, account == self.appDelegate.account,
                let cell = self.collectionView.cellForItem(at: indexPath) else { return }
            if let cell = cell as? NCTrashListCell {
                cell.imageItem.image = imageIcon
            } else if let cell = cell as? NCGridCell {
                cell.imageItem.image = imageIcon
            } // else: undefined cell
        }
    }
}
