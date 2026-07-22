// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

extension NCNetworking {
    func cancelAllTask() {
        Task {
            await NCTransferCoordinator.shared.cancelAll()
        }
        cancelAllDataTask()
        cancelAllWaitTask()
        cancelDownloadTasks()
        cancelDownloadBackgroundTask()
        cancelUploadTasks()
        cancelUploadBackgroundTask()
    }

    // MARK: -

    func cancelTask(metadata: tableMetadata) async {
        var serverUrls = Set<String>()
        let networking = NCNetworking.shared
        let database = NCManageDatabase.shared

        switch metadata.status {
        // FAVORITE
        case global.metadataStatusWaitFavorite:
            let favorite = (metadata.storeFlag as? NSString)?.boolValue ?? false
            await database.setMetadataFavoriteAsync(ocId: metadata.ocId, favorite: favorite, saveOldFavorite: nil, status: global.metadataStatusNormal)
            serverUrls.insert(metadata.serverUrl)
        // COPY MOVE
        case global.metadataStatusWaitCopy, global.metadataStatusWaitMove:
            await database.setMetadataCopyMoveAsync(ocId: metadata.ocId, destination: "", overwrite: nil, status: global.metadataStatusNormal)
            serverUrls.insert(metadata.serverUrl)
        // DELETE
        case global.metadataStatusWaitDelete:
            await database.setMetadataSessionAsync(ocId: metadata.ocId, status: global.metadataStatusNormal)
            serverUrls.insert(metadata.serverUrl)
        // RENAME
        case global.metadataStatusWaitRename:
            await database.restoreMetadataFileNameAsync(ocId: metadata.ocId)
            serverUrls.insert(metadata.serverUrl)
        // CREATE FOLDER
        case global.metadataStatusWaitCreateFolder:
            if let metadatas = await database.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND status != 0", metadata.account, metadata.serverUrl)) {
                for metadata in metadatas {
                    await database.deleteMetadataAsync(id: metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                    serverUrls.insert(metadata.serverUrl)
                }
            }
        default:
            // DOWNLOAD
            if metadata.session.contains("download") || global.metadataStatusDownloadingAllMode.contains(metadata.status) {
                if metadata.session == sessionDownload {
                    cancelDownloadTasks(metadata: metadata)
                } else if metadata.session == sessionDownloadBackground {
                    cancelDownloadBackgroundTask(metadata: metadata)
                } else {
                    await NCManageDatabase.shared.clearMetadatasSessionAsync(metadatas: [metadata])
                }
                await networking.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(networkingStatus: self.global.networkingStatusDownloadCancel,
                                            account: metadata.account,
                                            fileName: metadata.fileName,
                                            serverUrl: metadata.serverUrl,
                                            selector: metadata.sessionSelector,
                                            ocId: metadata.ocId,
                                            destination: nil,
                                            error: .success)
                }
            // UPLOAD
            } else if metadata.session.contains("upload") || global.metadataStatusUploadingAllMode.contains(metadata.status) {
                if metadata.session == nkComm.identifierSessionUpload {
                    cancelUploadTasks(metadata: metadata)
                } else {
                    cancelUploadBackgroundTask(metadata: metadata)
                }
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
            }
        }

        await networking.transferDispatcher.notifyAllDelegates { delegate in
            serverUrls.forEach { serverUrl in
                delegate.transferReloadDataSource(serverUrl: serverUrl, requestData: false, status: nil)
            }
        }
    }

    func cancelAllWaitTask() {
        Task {
            if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "status IN %@", global.metadataStatusWaitWebDav)) {
                for metadata in metadatas {
                    await cancelTask(metadata: metadata)
                }
            }
        }
    }

    func cancelAllDataTask() {
        nkComm.nksessions.forEach { session in
            session.sessionData.session.getTasksWithCompletionHandler { dataTasks, _, _ in
                dataTasks.forEach { task in
                    task.cancel()
                }
            }
        }
    }

    // MARK: -

    func cancelDownloadTasks(metadata: tableMetadata? = nil) {
        let targetTaskId = metadata?.sessionTaskIdentifier
        let predicate = NSPredicate(format: "(status == %d || status == %d || status == %d) AND session == %@",
                                    self.global.metadataStatusWaitDownload,
                                    self.global.metadataStatusDownloading,
                                    self.global.metadataStatusDownloadError,
                                    sessionDownload)
        Task {
            nkComm.nksessions.forEach { session in
                session.sessionData.session.getTasksWithCompletionHandler { _, _, downloadTasks in
                    downloadTasks.forEach { task in
                        if targetTaskId == nil || (task.taskIdentifier == targetTaskId) {
                            task.cancel()
                        }
                    }
                }
            }

            if let metadata {
                await NCManageDatabase.shared.clearMetadatasSessionAsync(metadatas: [metadata])
            } else if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicate) {
                await NCManageDatabase.shared.clearMetadatasSessionAsync(metadatas: metadatas)
            }
        }
    }

    func cancelDownloadBackgroundTask(metadata: tableMetadata? = nil) {
        let predicate = NSPredicate(format: "(status == %d || status == %d || status == %d) AND session == %@",
                                    self.global.metadataStatusWaitDownload,
                                    self.global.metadataStatusDownloading,
                                    self.global.metadataStatusDownloadError,
                                    sessionDownloadBackground)

        nkComm.nksessions.forEach { session in
            Task {
                let tasksBackground = await session.sessionDownloadBackground.tasks

                for task in tasksBackground.2 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                    if metadata == nil || (task.taskIdentifier == metadata?.sessionTaskIdentifier) {
                        task.cancel()
                    }
                }

                if let metadata {
                    await NCManageDatabase.shared.clearMetadatasSessionAsync(metadatas: [metadata])
                } else if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicate) {
                    await NCManageDatabase.shared.clearMetadatasSessionAsync(metadatas: metadatas)
                }
            }
        }
    }

    // MARK: -

    func cancelUploadTasks(metadata: tableMetadata? = nil) {
        let targetTaskId = metadata?.sessionTaskIdentifier
        let account = metadata?.account
        let predicate = NSPredicate(format: "(status == %d || status == %d || status == %d) AND session == %@",
                                    self.global.metadataStatusWaitUpload,
                                    self.global.metadataStatusUploading,
                                    self.global.metadataStatusUploadError,
                                    sessionUpload)

        Task {
            nkComm.nksessions.forEach { nkSession in
                nkSession.sessionData.session.getTasksWithCompletionHandler { _, uploadTasks, _ in
                    uploadTasks.forEach { task in
                        if targetTaskId == nil || (account == nkSession.account && targetTaskId == task.taskIdentifier) {
                            task.cancel()
                        }
                    }
                }
            }

            if let metadata {
                await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
            } else if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicate) {
                await NCManageDatabase.shared.deleteMetadatasAsync(metadatas)
            }
        }
    }

    func cancelUploadBackgroundTask(metadata: tableMetadata? = nil) {
        let predicate = NSPredicate(format: "(status == %d || status == %d || status == %d) AND (session == %@ || session == %@ || session == %@)",
                                    self.global.metadataStatusWaitUpload,
                                    self.global.metadataStatusUploading,
                                    self.global.metadataStatusUploadError,
                                    sessionUploadBackground,
                                    sessionUploadBackgroundWWan,
                                    sessionUploadBackgroundExt)

        nkComm.nksessions.forEach { nkSession in
            Task {
                var nkSession = nkSession
                let tasksBackground = await nkSession.sessionUploadBackground.tasks
                for task in tasksBackground.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                    if metadata == nil || (metadata?.account == nkSession.account &&
                                           metadata?.session == sessionUploadBackground &&
                                           metadata?.sessionTaskIdentifier == task.taskIdentifier) {
                        task.cancel()
                    }
                }

                let tasksBackgroundWWan = await nkSession.sessionUploadBackgroundWWan.tasks
                for task in tasksBackgroundWWan.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                    if metadata == nil || (metadata?.account == nkSession.account &&
                                           metadata?.session == sessionUploadBackgroundWWan &&
                                           metadata?.sessionTaskIdentifier == task.taskIdentifier) {
                        task.cancel()
                    }
                }

                let tasksBackgroundExt = await nkSession.sessionUploadBackgroundExt.tasks
                for task in tasksBackgroundExt.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                    if metadata == nil || (metadata?.account == nkSession.account &&
                                           metadata?.session == sessionUploadBackgroundExt &&
                                           metadata?.sessionTaskIdentifier == task.taskIdentifier) {
                        task.cancel()
                    }
                }

                if let metadata {
                    await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                } else if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicate) {
                    await NCManageDatabase.shared.deleteMetadatasAsync(metadatas)
                }
            }
        }
    }

    // MARK: -

    func getAllDataTask() async -> [URLSessionDataTask] {
        let nkSessions = nkComm.nksessions.all
        var taskArray: [URLSessionDataTask] = []

        for nkSession in nkSessions {
            let tasks = await nkSession.sessionData.session.tasks
            for task in tasks.0 {
                taskArray.append(task)
            }
        }
        return taskArray
    }

    // MARK: -

    func verifyZombie() async {
        func removeMetadataAndLocalFile(_ metadata: tableMetadata) async {
            await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                                   userId: metadata.userId,
                                                                                                   urlBase: metadata.urlBase))
        }

        func restoreUploadIfPossible(_ metadata: tableMetadata) async {
            guard NCUtilityFileSystem().fileProviderStorageExists(metadata) else {
                await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                return
            }

            await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                  sessionError: "",
                                                                  status: self.global.metadataStatusWaitUpload)
        }

        func restoreDownload(_ metadata: tableMetadata) async {
            await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                  session: "",
                                                                  sessionError: "",
                                                                  selector: "",
                                                                  status: self.global.metadataStatusNormal)
        }

        // UPLOADING-FOREGROUND
        //
        if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(
            predicate: NSPredicate(format: "session == %@ AND status == %d",
                                   sessionUpload,
                                   global.metadataStatusUploading)) {
            let metadatasByAccount = Dictionary(grouping: metadatas, by: \.account)

            for (account, accountMetadatas) in metadatasByAccount {
                guard let nkSession = nkComm.nksessions.session(forAccount: account) else {
                    for metadata in accountMetadatas {
                        await removeMetadataAndLocalFile(metadata)
                    }
                    continue
                }

                let tasks = await nkSession.sessionData.session.tasks
                let taskIdentifiers = Set(tasks.1.map(\.taskIdentifier))

                for metadata in accountMetadatas {
                    guard await !metadataUploadTranfersSuccess.exists(serverUrlFileName: metadata.serverUrlFileName) else {
                        continue
                    }

                    guard taskIdentifiers.contains(metadata.sessionTaskIdentifier) else {
                        await restoreUploadIfPossible(metadata)
                        continue
                    }
                }
            }
        }

        // UPLOADING-BACKGROUND
        //
        if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(
            predicate: NSPredicate(format: "session IN %@ AND status == %d",
                                   [sessionUploadBackground,
                                    sessionUploadBackgroundWWan],
                                   global.metadataStatusUploading)) {
            let metadatasByAccount = Dictionary(grouping: metadatas, by: \.account)

            for (account, accountMetadatas) in metadatasByAccount {
                guard let nkSession = nkComm.nksessions.session(forAccount: account) else {
                    for metadata in accountMetadatas {
                        await removeMetadataAndLocalFile(metadata)
                    }
                    continue
                }

                let backgroundTaskIdentifiers = Set((await nkSession.sessionUploadBackground.allTasks).map(\.taskIdentifier))
                let backgroundWWanTaskIdentifiers = Set((await nkSession.sessionUploadBackgroundWWan.allTasks).map(\.taskIdentifier))

                for metadata in accountMetadatas {
                    guard await !metadataUploadTranfersSuccess.exists(serverUrlFileName: metadata.serverUrlFileName) else {
                        continue
                    }

                    let taskIdentifiers: Set<Int>
                    switch metadata.session {
                    case sessionUploadBackground:
                        taskIdentifiers = backgroundTaskIdentifiers
                    case sessionUploadBackgroundWWan:
                        taskIdentifiers = backgroundWWanTaskIdentifiers
                    default:
                        taskIdentifiers = []
                    }

                    guard taskIdentifiers.contains(metadata.sessionTaskIdentifier) else {
                        await restoreUploadIfPossible(metadata)
                        continue
                    }
                }
            }
        }

        // DOWNLOADING-FOREGROUND
        //
        if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(
            predicate: NSPredicate(format: "session == %@ AND status IN %@",
                                   sessionDownload,
                                   global.metadataStatusDownloadingAllMode)) {
            let metadatasByAccount = Dictionary(grouping: metadatas, by: \.account)

            for (account, accountMetadatas) in metadatasByAccount {
                guard let nkSession = nkComm.nksessions.session(forAccount: account) else {
                    for metadata in accountMetadatas {
                        await removeMetadataAndLocalFile(metadata)
                    }
                    continue
                }

                let tasks = await nkSession.sessionData.session.tasks
                let taskIdentifiers = Set(tasks.2.map(\.taskIdentifier))

                for metadata in accountMetadatas where !taskIdentifiers.contains(metadata.sessionTaskIdentifier) {
                    guard await !metadataDownloadTranfersSuccess.exists(serverUrlFileName: metadata.serverUrlFileName) else {
                        continue
                    }
                    await restoreDownload(metadata)
                }
            }
        }

        // DOWNLOADING-BACKGROUND
        //
        if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(
            predicate: NSPredicate(format: "session == %@ AND status == %d",
                                   sessionDownloadBackground,
                                   global.metadataStatusDownloading)) {
            let metadatasByAccount = Dictionary(grouping: metadatas, by: \.account)

            for (account, accountMetadatas) in metadatasByAccount {
                guard let nkSession = nkComm.nksessions.session(forAccount: account) else {
                    for metadata in accountMetadatas {
                        await removeMetadataAndLocalFile(metadata)
                    }
                    continue
                }

                let taskIdentifiers = Set((await nkSession.sessionDownloadBackground.allTasks).map(\.taskIdentifier))

                for metadata in accountMetadatas where !taskIdentifiers.contains(metadata.sessionTaskIdentifier) {
                    guard await !metadataDownloadTranfersSuccess.exists(serverUrlFileName: metadata.serverUrlFileName) else {
                        continue
                    }
                    await restoreDownload(metadata)
                }
            }
        }
    }
}
