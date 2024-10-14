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
        NextcloudKit.shared.listingTrash(filename: filename, showHiddenFiles: false, account: session.account) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        } completion: { account, items, _, error in
            self.refreshControl.endRefreshing()
            if let items {
                self.database.deleteTrash(filePath: self.getFilePath(), account: account)
                self.database.addTrash(account: account, items: items)
            }
            self.reloadDataSource()
            if error != .success {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    func restoreItem(with fileId: String) {
        guard let resultTableTrash = self.database.getResultTrashItem(fileId: fileId, account: session.account) else { return }
        let fileNameFrom = resultTableTrash.filePath + resultTableTrash.fileName
        let fileNameTo = session.urlBase + "/remote.php/dav/trashbin/" + session.userId + "/restore/" + resultTableTrash.fileName

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: true, account: session.account) { account, _, error in
            guard error == .success else {
                NCContentPresenter().showError(error: error)
                return
            }
            self.database.deleteTrash(fileId: fileId, account: account)
            self.reloadDataSource()
        }
    }

    func emptyTrash() {
        let serverUrlFileName = session.urlBase + "/remote.php/dav/trashbin/" + session.userId + "/trash"

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: session.account) { account, _, error in
            guard error == .success else {
                NCContentPresenter().showError(error: error)
                return
            }
            self.database.deleteTrash(fileId: nil, account: account)
            self.reloadDataSource()
        }
    }

    func deleteItem(with fileId: String) {
        guard let resultTableTrash = self.database.getResultTrashItem(fileId: fileId, account: session.account) else { return }
        let serverUrlFileName = resultTableTrash.filePath + resultTableTrash.fileName

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: session.account) { account, _, error in
            guard error == .success else {
                NCContentPresenter().showError(error: error)
                return
            }
            self.database.deleteTrash(fileId: fileId, account: account)
            self.reloadDataSource()
        }
    }
}

class NCOperationDownloadThumbnailTrash: ConcurrentOperation, @unchecked Sendable {
    var fileId: String
    var fileName: String
    var collectionView: UICollectionView
    var account: String

    init(fileId: String, fileName: String, account: String, collectionView: UICollectionView) {
        self.fileId = fileId
        self.fileName = fileName
        self.account = account
        self.collectionView = collectionView
    }

    override func start() {
        guard !isCancelled else { return self.finish() }

        NextcloudKit.shared.downloadTrashPreview(fileId: fileId, account: account) { _, _, _, responseData, error in
            if error == .success, let data = responseData?.data {
                NCUtility().createImageFileFrom(data: data, ocId: self.fileId, etag: self.fileName)

                for case let cell as NCTrashCellProtocol in self.collectionView.visibleCells where cell.objectId == self.fileId {
                    cell.imageItem?.contentMode = .scaleAspectFill

                    UIView.transition(with: cell.imageItem,
                                      duration: 0.75,
                                      options: .transitionCrossDissolve,
                                      animations: { cell.imageItem.image = UIImage(data: data) },
                                      completion: nil)
                }
            }
            self.finish()
        }
    }
}
