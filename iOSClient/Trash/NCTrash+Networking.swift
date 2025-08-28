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
    func loadListingTrash() async {
        defer {
            self.refreshControl.endRefreshing()
        }

        let resultsListingTrash = await NextcloudKit.shared.listingTrashAsync(filename: filename, showHiddenFiles: false, account: session.account) { task in
            Task {
                await NCNetworking.shared.networkingTasks.track(identifier: self.networkingTasksIdentifier, task: task)
            }
            self.collectionView.reloadData()
        }

        if let items = resultsListingTrash.items {
            await self.database.deleteTrashAsync(fileId: self.getFilePath(), account: self.session.account)
            await self.database.addTrashAsync(items: items, account: self.session.account)
        }

        await self.reloadDataSource()
    }

    func restoreItem(with fileId: String) async {
        guard let result = await self.database.getTableTrashAsync(fileId: fileId, account: session.account) else {
            return
        }
        let serverUrlFileNameSource = result.filePath + result.fileName
        let serverUrlFileNameDestination = session.urlBase + "/remote.php/dav/trashbin/" + session.userId + "/restore/" + result.fileName

        let resultsMoveFileOrFolder = await NextcloudKit.shared.moveFileOrFolderAsync(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: true, account: self.session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                            path: serverUrlFileNameSource,
                                                                                            name: "moveFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        guard resultsMoveFileOrFolder.error == .success else {
            return
        }

        await self.database.deleteTrashAsync(fileId: fileId, account: self.session.account)
        await self.reloadDataSource()
    }

    func emptyTrash() async {
        let serverUrlFileName = session.urlBase + "/remote.php/dav/trashbin/" + session.userId + "/trash"
        let response = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: serverUrlFileName, account: session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "deleteFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        if response.error != .success {
            NCContentPresenter().showError(error: response.error)
        }
        await self.database.deleteTrashAsync(fileId: nil, account: session.account)
        await self.reloadDataSource()
    }

    func deleteItems(with filesId: [String]) async {
        for fileId in filesId {
            guard let result = await self.database.getTableTrashAsync(fileId: fileId, account: session.account) else {
                continue
            }
            let serverUrlFileName = result.filePath + result.fileName
            let response = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: serverUrlFileName, account: session.account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                                path: serverUrlFileName,
                                                                                                name: "deleteFileOrFolder")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            if response.error != .success {
                NCContentPresenter().showError(error: response.error)
            }
            await self.database.deleteTrashAsync(fileId: fileId, account: session.account)
            await self.reloadDataSource()
        }
    }
}

class NCOperationDownloadThumbnailTrash: ConcurrentOperation, @unchecked Sendable {
    var fileId: String
    var fileName: String
    var collectionView: UICollectionView
    var session: NCSession.Session

    init(fileId: String, fileName: String, session: NCSession.Session, collectionView: UICollectionView) {
        self.fileId = fileId
        self.fileName = fileName
        self.session = session
        self.collectionView = collectionView
    }

    override func start() {
        guard !isCancelled else { return self.finish() }

        NextcloudKit.shared.downloadTrashPreview(fileId: fileId, account: session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                            path: self.fileId,
                                                                                            name: "DownloadPreview")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, _, _, responseData, error in
            if error == .success, let data = responseData?.data {
                NCUtility().createImageFileFrom(data: data, ocId: self.fileId, etag: self.fileName, userId: self.session.userId, urlBase: self.session.urlBase)

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
