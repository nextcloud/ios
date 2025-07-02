//
//  NCNetworking+Task.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
        fileExistsQueue.cancelAll()
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
        cancelAllDataTask()
        cancelDownloadTasks()
        cancelUploadTasks()
    }

    // MARK: -

    func cancelTask(metadata: tableMetadata) {
        let serverUrl = metadata.serverUrl

        /// FAVORITE
        ///
        if metadata.status == global.metadataStatusWaitFavorite {
            Task {
                let favorite = (metadata.storeFlag as? NSString)?.boolValue ?? false
                await database.setMetadataFavoriteAsync(ocId: metadata.ocId, favorite: favorite, saveOldFavorite: nil, status: global.metadataStatusNormal)

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: serverUrl, status: nil)
                }
            }
        }

        /// COPY
        ///
        else if metadata.status == global.metadataStatusWaitCopy {
            Task {
                await database.setMetadataCopyMoveAsync(ocId: metadata.ocId, serverUrlTo: "", overwrite: nil, status: global.metadataStatusNormal)

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: serverUrl, status: nil)
                }
            }
        }

        /// MOVE
        ///
        else if metadata.status == global.metadataStatusWaitMove {
            Task {
                await database.setMetadataCopyMoveAsync(ocId: metadata.ocId, serverUrlTo: "", overwrite: nil, status: global.metadataStatusNormal)

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: serverUrl, status: nil)
                }
            }
        }

        /// DELETE
        ///
        else if metadata.status == global.metadataStatusWaitDelete {
            Task {
                await database.setMetadataStatusAsync(ocId: metadata.ocId, status: global.metadataStatusNormal)

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: serverUrl, status: nil)
                }
            }
        }

        /// RENAME
        ///
        else if metadata.status == global.metadataStatusWaitRename {
            Task {
                await database.restoreMetadataFileNameAsync(ocId: metadata.ocId)

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: serverUrl, status: nil)
                }
                return
            }
        }

        /// CREATE FOLDER
        ///
        else if metadata.status == global.metadataStatusWaitCreateFolder {
            Task {
                var serverUrls = Set<String>()

                if let metadatas = await database.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND status != 0", metadata.account, metadata.serverUrl)) {
                    for metadata in metadatas {
                        await database.deleteMetadataOcIdAsync(metadata.ocId)
                        utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                        serverUrls.insert(metadata.serverUrl)
                    }

                    NCNetworking.shared.notifyAllDelegates { delegate in
                        serverUrls.forEach { serverUrl in
                            delegate.transferReloadData(serverUrl: serverUrl, status: nil)
                        }
                    }
                }
            }
        }

        /// NO SESSION
        ///
        else if metadata.session.isEmpty {
            Task {
                await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: serverUrl, status: nil)
                }
            }
        }

        /// DOWNLOAD
        ///
        else if metadata.session.contains("download") {
                if metadata.session == sessionDownload {
                    cancelDownloadTasks(metadata: metadata)
                } else if metadata.session == sessionDownloadBackground {
                    cancelDownloadBackgroundTask(metadata: metadata)
                }

                self.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusDownloadCancel,
                                            metadata: metadata.detachedCopy(),
                                            error: .success)
            }
        }

        /// UPLOAD
        ///
        else if metadata.session.contains("upload") {
            if metadata.session == NextcloudKit.shared.nkCommonInstance.identifierSessionUpload {
                cancelUploadTasks(metadata: metadata)
            } else {
                cancelUploadBackgroundTask(metadata: metadata)
            }
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
            self.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusUploadCancel,
                                        metadata: metadata.detachedCopy(),
                                        error: .success)
            }
        }
    }

    func cancelAllWaitTask() {
        Task {
            if let metadatas = await database.getMetadatasAsync(predicate: NSPredicate(format: "status IN %@", global.metadataStatusWaitWebDav)) {
                for metadata in metadatas {
                    cancelTask(metadata: metadata)
                }

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: nil, status: global.metadataStatusNormal)
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
                await self.database.clearMetadataSessionAsync(metadata: metadata)
            } else if let metadatas = await self.database.getMetadatasAsync(predicate: predicate) {
                await self.database.clearMetadatasSessionAsync(metadatas: metadatas)
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
                    await self.database.clearMetadataSessionAsync(metadata: metadata)
                } else if let metadatas = await self.database.getMetadatasAsync(predicate: predicate) {
                    await self.database.clearMetadatasSessionAsync(metadatas: metadatas)
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
                await self.database.deleteMetadataOcIdAsync(metadata.ocId)
            } else if let metadatas = await self.database.getMetadatasAsync(predicate: predicate) {
                await self.database.deleteMetadatasAsync(metadatas)
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
                    await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                } else if let metadatas = await self.database.getMetadatasAsync(predicate: predicate) {
                    await self.database.deleteMetadatasAsync(metadatas)
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
        // NO SESSION
        //
        if let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "session == '' AND status != %d",
                                                                                        self.global.metadataStatusNormal)) {

            for metadata in metadatas {
                await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                            sessionError: "",
                                                            selector: "",
                                                            status: self.global.metadataStatusNormal)
            }
        }

        // UPLOADING-FOREGROUND
        //
        if let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                                        sessionUpload,
                                                                                        self.global.metadataStatusUploading)) {
            for metadata in metadatas {
                guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: metadata.account) else {
                    self.database.deleteMetadataOcId(metadata.ocId)
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
                        await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                    sessionError: "",
                                                                    status: self.global.metadataStatusWaitUpload)
                    } else {
                        await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                    }
                }
            }
        }

        // UPLOADING-BACKGROUND
        //
        if let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d",
                                                                                        sessionUploadBackground,
                                                                                        sessionUploadBackgroundWWan,
                                                                                        sessionUploadBackgroundExt,
                                                                                        self.global.metadataStatusUploading)) {

            for metadata in metadatas {
                guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: metadata.account) else {
                    await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,userId: metadata.userId, urlBase: metadata.urlBase))
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
                    await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,userId: metadata.userId, urlBase: metadata.urlBase))
                    continue
                }

                for task in tasks {
                    if metadata.sessionTaskIdentifier == task.taskIdentifier {
                        foundTask = true
                    }
                }

                if !foundTask {
                    if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
                        await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                    sessionError: "",
                                                                    status: self.global.metadataStatusWaitUpload)
                    } else {
                        await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                    }
                }
            }
        }

        // DOWNLOADING-FOREGROUND
        //
        if let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "session == %@ AND status IN %@",
                                                                                        sessionDownload,
                                                                                        self.global.metadataStatusDownloadingAllMode)) {

            for metadata in metadatas {
                guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: metadata.account) else {
                    await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,userId: metadata.userId, urlBase: metadata.urlBase))
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
                    await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                session: "",
                                                                sessionError: "",
                                                                selector: "",
                                                                status: self.global.metadataStatusNormal)
                }
            }
        }

        // DOWNLOADING-BACKGROUND
        //
        if let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                                        sessionDownloadBackground,
                                                                                        self.global.metadataStatusDownloading)) {
            for metadata in metadatas {
                guard let nkSession = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: metadata.account) else {
                    await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,userId: metadata.userId, urlBase: metadata.urlBase))
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
                    await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                session: "",
                                                                sessionError: "",
                                                                selector: "",
                                                                status: self.global.metadataStatusNormal)
                }
            }
        }
    }
}
