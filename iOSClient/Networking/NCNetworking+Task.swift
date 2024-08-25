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
import Alamofire
import RealmSwift

extension NCNetworking {
    func cancelAllTask() {
        cancelAllQueue()
        cancelAllDataTask()
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
        utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))

        /// No session found
        if metadata.session.isEmpty {
            self.database.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
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

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account],
                                                        second: 0.5)
        }

        /// UPLOAD
        ///
        if metadata.session.contains("upload") {

            if metadata.session == NextcloudKit.shared.nkCommonInstance.identifierSessionUpload {
                cancelUploadTasks(metadata: metadata)
            } else {
                cancelUploadBackgroundTask(metadata: metadata)
            }

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account],
                                                        second: 0.5)
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
                                                                                                   NCGlobal.shared.metadataStatusWaitDownload,
                                                                                                   NCGlobal.shared.metadataStatusDownloading,
                                                                                                   NCGlobal.shared.metadataStatusDownloadError,
                                                                                                   sessionDownload)) {
            self.database.clearMetadataSession(metadatas: results)
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
                } else if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "(status == %d || status == %d || status == %d) AND session == %@",
                                                                                                           NCGlobal.shared.metadataStatusWaitDownload,
                                                                                                           NCGlobal.shared.metadataStatusDownloading,
                                                                                                           NCGlobal.shared.metadataStatusDownloadError,
                                                                                                           sessionDownloadBackground)) {
                    self.database.clearMetadataSession(metadatas: results)
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
            self.database.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        } else if let results = self.database.getResultsMetadatas(predicate: NSPredicate(format: "(status == %d || status == %d || status == %d) AND session == %@",
                                                                                                   NCGlobal.shared.metadataStatusWaitUpload,
                                                                                                   NCGlobal.shared.metadataStatusUploading,
                                                                                                   NCGlobal.shared.metadataStatusUploadError,
                                                                                                   sessionUpload)) {
            self.database.deleteMetadata(results: results)
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
                    self.database.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                } else if let results = self.database.getResultsMetadatas(predicate: NSPredicate(format: "(status == %d || status == %d || status == %d) AND (session == %@ || session == %@ || session == %@)",
                                                                                                           NCGlobal.shared.metadataStatusWaitUpload,
                                                                                                           NCGlobal.shared.metadataStatusUploading,
                                                                                                           NCGlobal.shared.metadataStatusUploadError,
                                                                                                           sessionUploadBackground,
                                                                                                           sessionUploadBackgroundWWan,
                                                                                                           sessionUploadBackgroundExt
                                                                                                          )) {
                    self.database.deleteMetadata(results: results)
                }
            }
        }
    }

    // MARK: - Zombie

    func verifyZombie() async {
        var metadatas: [tableMetadata] = []

        /// UPLOADING-FOREGROUND
        ///
        metadatas = self.database.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                      sessionUpload,
                                                                      NCGlobal.shared.metadataStatusUploading))

        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                self.database.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                    self.database.setMetadataSession(ocId: metadata.ocId,
                                                     sessionError: "",
                                                     status: NCGlobal.shared.metadataStatusWaitUpload)
                } else {
                    self.database.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                }
            }
        }

        /// UPLOADING-BACKGROUND
        ///
        metadatas = self.database.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d",
                                                                      sessionUploadBackground,
                                                                      sessionUploadBackgroundWWan,
                                                                      sessionUploadBackgroundExt,
                                                                      NCGlobal.shared.metadataStatusUploading))

        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                self.database.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                self.database.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                    self.database.setMetadataSession(ocId: metadata.ocId,
                                                     sessionError: "",
                                                     status: NCGlobal.shared.metadataStatusWaitUpload)
                } else {
                    self.database.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                }
            }
        }

        /// DOWNLOADING-FOREGROUND
        ///
        metadatas = self.database.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                      sessionDownload,
                                                                      NCGlobal.shared.metadataStatusDownloading))

        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                self.database.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                self.database.setMetadataSession(ocId: metadata.ocId,
                                                 session: "",
                                                 sessionError: "",
                                                 selector: "",
                                                 status: NCGlobal.shared.metadataStatusNormal)
            }
        }

        /// DOWNLOADING-BACKGROUND
        ///
        metadatas = self.database.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                      sessionDownloadBackground,
                                                                      NCGlobal.shared.metadataStatusDownloading))
        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                self.database.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                self.database.setMetadataSession(ocId: metadata.ocId,
                                                 session: "",
                                                 sessionError: "",
                                                 selector: "",
                                                 status: NCGlobal.shared.metadataStatusNormal)
            }
        }
    }
}
