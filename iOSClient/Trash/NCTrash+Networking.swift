// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

extension NCTrash {
    func loadListingTrash() async {
        defer {
            self.refreshControl.endRefreshing()
        }

        // If is already in-flight, do nothing
        if await NCNetworking.shared.networkingTasks.isReading(identifier: "NCTrash") {
            return
        }

        let resultsListingTrash = await NextcloudKit.shared.listingTrashAsync(filename: filename, showHiddenFiles: false, account: session.account) { task in
            Task {
                await NCNetworking.shared.networkingTasks.track(identifier: "NCTrash", task: task)
                await self.collectionView.reloadData()
            }
        }

        if let items = resultsListingTrash.items {
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
        let results = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: serverUrlFileName, account: session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "deleteFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        if results.error != .success {
            await showErrorBanner(windowScene: self.windowScene, text: results.error.errorDescription, errorCode: results.error.errorCode)
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
            let results = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: serverUrlFileName, account: session.account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                                path: serverUrlFileName,
                                                                                                name: "deleteFileOrFolder")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            if results.error != .success {
                await showErrorBanner(windowScene: self.windowScene, text: results.error.errorDescription, errorCode: results.error.errorCode)
            }
            await self.database.deleteTrashAsync(fileId: fileId, account: session.account)
            await self.reloadDataSource()
        }
    }
}
