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

import UIKit
import NextcloudKit
import Queuer
import RealmSwift

extension NCTrash {
    @objc func loadListingTrash() {
        NextcloudKit.shared.listingTrash(filename: filename, showHiddenFiles: false, account: appDelegate.account) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        } completion: { account, items, _, error in
            self.refreshControl.endRefreshing()
            if account == self.appDelegate.account {
                NCManageDatabase.shared.deleteTrash(filePath: self.getFilePath(), account: account)
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

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: true, account: appDelegate.account) { account, error in
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

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: appDelegate.account) { account, error in
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

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: appDelegate.account) { account, error in
            guard error == .success, account == self.appDelegate.account else {
                NCContentPresenter().showError(error: error)
                return
            }
            NCManageDatabase.shared.deleteTrash(fileId: fileId, account: account)
            self.reloadDataSource()
        }
    }
}

class NCOperationDownloadThumbnailTrash: ConcurrentOperation {

    var tableTrash: tableTrash
    var fileId: String
    var collectionView: UICollectionView?
    var cell: NCTrashCellProtocol?
    var account: String

    init(tableTrash: tableTrash, fileId: String, account: String, cell: NCTrashCellProtocol?, collectionView: UICollectionView?) {
        self.tableTrash = tableTrash
        self.fileId = fileId
        self.account = account
        self.cell = cell
        self.collectionView = collectionView
    }

    override func start() {
        guard !isCancelled else { return self.finish() }
        let fileNamePreviewLocalPath = NCUtilityFileSystem().getDirectoryProviderStoragePreviewOcId(tableTrash.fileId, etag: tableTrash.fileName)
        let fileNameIconLocalPath = NCUtilityFileSystem().getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)

        NextcloudKit.shared.downloadTrashPreview(fileId: tableTrash.fileId,
                                                 fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                                                 fileNameIconLocalPath: fileNameIconLocalPath,
                                                 widthPreview: NCGlobal.shared.sizePreview,
                                                 heightPreview: NCGlobal.shared.sizePreview,
                                                 sizeIcon: NCGlobal.shared.sizeIcon,
                                                 account: account,
                                                 options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, imagePreview, _, _, _, error in

            if error == .success, let imagePreview = imagePreview {
                DispatchQueue.main.async {
                    if self.fileId == self.cell?.objectId, let imageView = self.cell?.imageItem {
                        UIView.transition(with: imageView,
                                          duration: 0.75,
                                          options: .transitionCrossDissolve,
                                          animations: { imageView.image = imagePreview },
                                          completion: nil)
                    } else {
                        self.collectionView?.reloadData()
                    }
                }
            }
            self.finish()
        }
    }
}
