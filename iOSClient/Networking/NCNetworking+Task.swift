// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

extension NCNetworking {
    func cancelAllQueue() {
        downloadThumbnailQueue.cancelAll()
        downloadThumbnailActivityQueue.cancelAll()
        downloadThumbnailTrashQueue.cancelAll()
        downloadAvatarQueue.cancelAll()
        unifiedSearchQueue.cancelAll()
        saveLivePhotoQueue.cancelAll()
    }

    func cancelAllTask() {
        cancelAllQueue()
        cancelAllDataTask()
        cancelAllWaitTask()
        cancelAllDownloadUploadTask()
    }

    func cancelAllDownloadTask() {
        cancelDownloadTasks()
        cancelDownloadBackgroundTask()
    }

    func cancelAllUploadTask() {
        cancelUploadTasks()
        cancelUploadBackgroundTask()
    }

    func cancelAllDownloadUploadTask() {
        cancelAllDownloadTask()
        cancelAllUploadTask()
    }

    func cancelAllTaskForGoInBackground() {
        cancelAllQueue()
        cancelDownloadTasks()
        cancelUploadTasks()
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
            if metadata.session.contains("download") {
                if metadata.session == sessionDownload {
                    cancelDownloadTasks(metadata: metadata)
                } else if metadata.session == sessionDownloadBackground {
                    cancelDownloadBackgroundTask(metadata: metadata)
                }
                await networking.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusDownloadCancel,
                                            metadata: metadata.detachedCopy(),
                                            error: .success)
                }
            // UPLOAD
            } else if metadata.session.contains("upload") {
                if metadata.session == NextcloudKit.shared.nkCommonInstance.identifierSessionUpload {
                    cancelUploadTasks(metadata: metadata)
                } else {
                    cancelUploadBackgroundTask(metadata: metadata)
                }
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                await networking.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusUploadCancel,
                                            metadata: metadata.detachedCopy(),
                                            error: .success)
                }
            }
        }

        await networking.transferDispatcher.notifyAllDelegates { delegate in
            serverUrls.forEach { serverUrl in
                delegate.transferReloadData(serverUrl: serverUrl, status: nil)
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
        NextcloudKit.shared.nkCommonInstance.nksessions.forEach { session in
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
            NextcloudKit.shared.nkCommonInstance.nksessions.forEach { session in
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

        NextcloudKit.shared.nkCommonInstance.nksessions.forEach { session in
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
            NextcloudKit.shared.nkCommonInstance.nksessions.forEach { nkSession in
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

        NextcloudKit.shared.nkCommonInstance.nksessions.forEach { nkSession in
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
        let nkSessions = NextcloudKit.shared.nkCommonInstance.nksessions.all
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
        // UPLOADING-FOREGROUND
        //
        if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                                                  sessionUpload,
                                                                                                  self.global.metadataStatusUploading)) {
            for metadata in metadatas {
                guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: metadata.account) else {
                    await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                    continue
                }
                var foundTask = false
                let tasks = await nkSession.sessionData.session.tasks

                for task in tasks.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                    if metadata.sessionTaskIdentifier == task.taskIdentifier {
                        foundTask = true
                    }
                }

                if !foundTask {
                    if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
                        await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                              sessionError: "",
                                                                              status: self.global.metadataStatusWaitUpload)
                    } else {
                        await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                    }
                }
            }
        }

        // UPLOADING-BACKGROUND, NO sessionUploadBackgroundExt
        //
        if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "(session == %@ OR session == %@) AND status == %d",
                                                                                                  sessionUploadBackground,
                                                                                                  sessionUploadBackgroundWWan)) {
            for metadata in metadatas {
                guard var nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: metadata.account) else {
                    await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                    continue
                }
                var session: URLSession?

                if metadata.session == sessionUploadBackground {
                    session = nkSession.sessionUploadBackground
                } else if metadata.session == sessionUploadBackgroundWWan {
                    session = nkSession.sessionUploadBackgroundWWan
                } else if metadata.session == sessionUploadBackgroundExt {
                    session = nkSession.sessionUploadBackgroundExt
                }

                var foundTask = false
                guard let tasks = await session?.allTasks else {
                    await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                    continue
                }

                for task in tasks {
                    if metadata.sessionTaskIdentifier == task.taskIdentifier {
                        foundTask = true
                    }
                }

                if !foundTask {
                    if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
                        await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                              sessionError: "",
                                                                              status: self.global.metadataStatusWaitUpload)
                    } else {
                        await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                    }
                }
            }
        }

        // DOWNLOADING-FOREGROUND
        //
        if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "session == %@ AND status IN %@",
                                                                                                  sessionDownload,
                                                                                                  self.global.metadataStatusDownloadingAllMode)) {

            for metadata in metadatas {
                guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: metadata.account) else {
                    await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                    continue
                }
                var foundTask = false
                let tasks = await nkSession.sessionData.session.tasks

                for task in tasks.2 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                    if metadata.sessionTaskIdentifier == task.taskIdentifier {
                        foundTask = true
                    }
                }

                if !foundTask {
                    await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                          session: "",
                                                                          sessionError: "",
                                                                          selector: "",
                                                                          status: self.global.metadataStatusNormal)
                }
            }
        }

        // DOWNLOADING-BACKGROUND
        //
        if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                                                  sessionDownloadBackground,
                                                                                                  self.global.metadataStatusDownloading)) {
            for metadata in metadatas {
                guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: metadata.account) else {
                    await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                    continue
                }
                var foundTask = false
                let tasks = await nkSession.sessionDownloadBackground.allTasks

                for task in tasks {
                    if metadata.sessionTaskIdentifier == task.taskIdentifier {
                        foundTask = true
                    }
                }

                if !foundTask {
                    await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                          session: "",
                                                                          sessionError: "",
                                                                          selector: "",
                                                                          status: self.global.metadataStatusNormal)
                }
            }
        }
    }
}
