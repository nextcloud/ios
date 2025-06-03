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

    // MARK: -

    func cancelTask(metadata: tableMetadata) {

        /// FAVORITE
        ///
        if metadata.status == global.metadataStatusWaitFavorite {
            let favorite = (metadata.storeFlag as? NSString)?.boolValue ?? false
            database.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite, saveOldFavorite: nil, status: global.metadataStatusNormal)

            NCNetworking.shared.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: metadata.serverUrl)
            }
            return
        }

        /// COPY
        ///
        if metadata.status == global.metadataStatusWaitCopy {
            database.setMetadataCopyMove(ocId: metadata.ocId, serverUrlTo: "", overwrite: nil, status: global.metadataStatusNormal)

            NCNetworking.shared.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: metadata.serverUrl)
            }
            return
        }

        /// MOVE
        ///
        if metadata.status == global.metadataStatusWaitMove {
            database.setMetadataCopyMove(ocId: metadata.ocId, serverUrlTo: "", overwrite: nil, status: global.metadataStatusNormal)

            NCNetworking.shared.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: metadata.serverUrl)
            }
            return
        }

        /// DELETE
        ///
        if metadata.status == global.metadataStatusWaitDelete {
            let metadata = database.setMetadataStatus(metadata: metadata,
                                                      status: global.metadataStatusNormal)

            NCNetworking.shared.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: metadata.serverUrl)
            }
            return
        }

        /// RENAME
        ///
        if metadata.status == global.metadataStatusWaitRename {
            database.restoreMetadataFileName(ocId: metadata.ocId)

            NCNetworking.shared.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: metadata.serverUrl)
            }
            return
        }

        /// CREATE FOLDER
        ///
        if metadata.status == global.metadataStatusWaitCreateFolder {
            let metadatas = database.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND status != 0", metadata.account, metadata.serverUrl))
            for metadata in metadatas {
                database.deleteMetadataOcId(metadata.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            }

            NCNetworking.shared.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: metadata.serverUrl)
            }
            return
        }

        /// NO SESSION
        ///
        if metadata.session.isEmpty {
            self.database.deleteMetadataOcId(metadata.ocId)
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))

            NCNetworking.shared.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: metadata.serverUrl)
            }
            return
        }

        /// DOWNLOAD
        ///
        if metadata.session.contains("download") {

            if metadata.session == sessionDownload {
                cancelDownloadTasks(metadata: metadata)
            } else if metadata.session == sessionDownloadBackground {
                cancelDownloadBackgroundTask(metadata: metadata)
            }

            self.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusDownloadCancel,
                                        metadata: tableMetadata(value: metadata),
                                        error: .success)
            }
        }

        /// UPLOAD
        ///
        if metadata.session.contains("upload") {
            if metadata.session == NextcloudKit.shared.nkCommonInstance.identifierSessionUpload {
                cancelUploadTasks(metadata: metadata)
            } else {
                cancelUploadBackgroundTask(metadata: metadata)
            }
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            self.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusUploadCancel,
                                        metadata: tableMetadata(value: metadata),
                                        error: .success)
            }
        }
    }

    func cancelAllWaitTask() {
        let metadatas = database.getMetadatas(predicate: NSPredicate(format: "status IN %@", global.metadataStatusWaitWebDav))
        for metadata in metadatas {
            cancelTask(metadata: metadata)
        }

        NCNetworking.shared.notifyAllDelegates { delegate in
            delegate.transferReloadData(serverUrl: nil)
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
        NextcloudKit.shared.nkCommonInstance.nksessions.forEach { session in
            session.sessionData.session.getTasksWithCompletionHandler { _, _, downloadTasks in
                downloadTasks.forEach { task in
                    if metadata == nil || (task.taskIdentifier == metadata?.sessionTaskIdentifier) {
                        task.cancel()
                    }
                }
            }
        }

        if let metadata {
            self.database.clearMetadataSession(metadata: metadata)
        } else if let results = self.database.getResultsMetadatas(predicate: NSPredicate(format: "(status == %d || status == %d || status == %d) AND session == %@",
                                                                                         self.global.metadataStatusWaitDownload,
                                                                                         self.global.metadataStatusDownloading,
                                                                                         self.global.metadataStatusDownloadError,
                                                                                         sessionDownload)) {
            self.database.clearMetadataSession(metadatas: Array(results))
        }
    }

    func cancelDownloadBackgroundTask(metadata: tableMetadata? = nil) {
        NextcloudKit.shared.nkCommonInstance.nksessions.forEach { session in
            Task {
                let tasksBackground = await session.sessionDownloadBackground.tasks

                for task in tasksBackground.2 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                    if metadata == nil || (task.taskIdentifier == metadata?.sessionTaskIdentifier) {
                        task.cancel()
                    }
                }

                if let metadata {
                    self.database.clearMetadataSession(metadata: metadata)
                } else if let results = self.database.getResultsMetadatas(predicate: NSPredicate(format: "(status == %d || status == %d || status == %d) AND session == %@",
                                                                                                 self.global.metadataStatusWaitDownload,
                                                                                                 self.global.metadataStatusDownloading,
                                                                                                 self.global.metadataStatusDownloadError,
                                                                                                 sessionDownloadBackground)) {
                    self.database.clearMetadataSession(metadatas: Array(results))
                }
            }
        }
    }

    // MARK: -

    func cancelUploadTasks(metadata: tableMetadata? = nil) {
        NextcloudKit.shared.nkCommonInstance.nksessions.forEach { nkSession in
            nkSession.sessionData.session.getTasksWithCompletionHandler { _, uploadTasks, _ in
                uploadTasks.forEach { task in
                    if metadata == nil || (metadata?.account == nkSession.account && metadata?.sessionTaskIdentifier == task.taskIdentifier) {
                        task.cancel()
                    }
                }
            }
        }

        if let metadata {
            self.database.deleteMetadataOcId(metadata.ocId)
        } else if let results = self.database.getResultsMetadatas(predicate: NSPredicate(format: "(status == %d || status == %d || status == %d) AND session == %@",
                                                                                         self.global.metadataStatusWaitUpload,
                                                                                         self.global.metadataStatusUploading,
                                                                                         self.global.metadataStatusUploadError,
                                                                                         sessionUpload)) {
            self.database.deleteMetadatas(Array(results))
        }
    }

    func cancelUploadBackgroundTask(metadata: tableMetadata? = nil) {
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
                    self.database.deleteMetadataOcId(metadata.ocId)
                } else if let results = self.database.getResultsMetadatas(predicate: NSPredicate(format: "(status == %d || status == %d || status == %d) AND (session == %@ || session == %@ || session == %@)",
                                                                                                 self.global.metadataStatusWaitUpload,
                                                                                                 self.global.metadataStatusUploading,
                                                                                                 self.global.metadataStatusUploadError,
                                                                                                 sessionUploadBackground,
                                                                                                 sessionUploadBackgroundWWan,
                                                                                                 sessionUploadBackgroundExt)) {
                    self.database.deleteMetadatas(Array(results))
                }
            }
        }
    }

    // MARK: -

    func getAllDataTask() async -> [URLSessionDataTask] {
        guard let nkSessions = NextcloudKit.shared.nkCommonInstance.nksessions.getArray() else { return [] }
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
        var metadatas: [tableMetadata] = []

        /// UPLOADING-FOREGROUND
        ///
        metadatas = self.database.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                      sessionUpload,
                                                                      self.global.metadataStatusUploading))

        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                self.database.deleteMetadataOcId(metadata.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
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
                    self.database.setMetadataSession(metadata: metadata,
                                                     sessionError: "",
                                                     status: self.global.metadataStatusWaitUpload)
                } else {
                    self.database.deleteMetadataOcId(metadata.ocId)
                }
            }
        }

        /// UPLOADING-BACKGROUND
        ///
        metadatas = self.database.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d",
                                                                      sessionUploadBackground,
                                                                      sessionUploadBackgroundWWan,
                                                                      sessionUploadBackgroundExt,
                                                                      self.global.metadataStatusUploading))

        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                self.database.deleteMetadataOcId(metadata.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
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
                self.database.deleteMetadataOcId(metadata.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                continue
            }

            for task in tasks {
                if metadata.sessionTaskIdentifier == task.taskIdentifier {
                    foundTask = true
                }
            }

            if !foundTask {
                if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
                    self.database.setMetadataSession(metadata: metadata,
                                                     sessionError: "",
                                                     status: self.global.metadataStatusWaitUpload)
                } else {
                    self.database.deleteMetadataOcId(metadata.ocId)
                }
            }
        }

        /// DOWNLOADING-FOREGROUND
        ///
        metadatas = self.database.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                      sessionDownload,
                                                                      self.global.metadataStatusDownloading))

        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                self.database.deleteMetadataOcId(metadata.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
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
                self.database.setMetadataSession(metadata: metadata,
                                                 session: "",
                                                 sessionError: "",
                                                 selector: "",
                                                 status: self.global.metadataStatusNormal)
            }
        }

        /// DOWNLOADING-BACKGROUND
        ///
        metadatas = self.database.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                      sessionDownloadBackground,
                                                                      self.global.metadataStatusDownloading))
        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                self.database.deleteMetadataOcId(metadata.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
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
                self.database.setMetadataSession(metadata: metadata,
                                                 session: "",
                                                 sessionError: "",
                                                 selector: "",
                                                 status: self.global.metadataStatusNormal)
            }
        }
    }
}
