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
        NCNetworking.shared.cancelDownloadTasks()
        NCNetworking.shared.cancelDownloadBackgroundTask()
    }

    func cancelAllUploadTask() {
        NCNetworking.shared.cancelUploadTasks()
        NCNetworking.shared.cancelUploadBackgroundTask()
    }

    func cancelAllDownloadUploadTask() {
        cancelAllDownloadTask()
        cancelAllUploadTask()
    }

    func cancelTask(metadata: tableMetadata) {
        utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))

        // No session found
        if metadata.session.isEmpty {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
            return
        }

        /// DOWNLOAD
        ///
        if metadata.session.contains("download") {

            if metadata.session == NCNetworking.shared.sessionDownload {
                NCNetworking.shared.cancelDownloadTasks(metadata: metadata)
            } else if metadata.session == NCNetworking.shared.sessionDownloadBackground {
                NCNetworking.shared.cancelDownloadBackgroundTask(metadata: metadata)
            }

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadCancelFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account],
                                                        second: 0.2)
        }

        /// UPLOAD
        ///
        if metadata.session.contains("upload") {

            if metadata.session == NextcloudKit.shared.nkCommonInstance.identifierSessionUpload {
                NCNetworking.shared.cancelUploadTasks(metadata: metadata)
            } else {
                NCNetworking.shared.cancelUploadBackgroundTask(metadata: metadata)
            }

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account],
                                                        second: 0.2)
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

    func verifyZombie() async {
        var metadatas: [tableMetadata] = []

        /// UPLOADING-FOREGROUND -> DELETE
        ///
        metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                                NCNetworking.shared.sessionUpload,
                                                                                NCGlobal.shared.metadataStatusUploading))

        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                               sessionError: "",
                                                               status: NCGlobal.shared.metadataStatusWaitUpload)
                } else {
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                }
            }
        }

        /// UPLOADING-BACKGROUND -> STATUS: WAIT UPLOAD
        ///
        metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d",
                                                                                NCNetworking.shared.sessionUploadBackground,
                                                                                NCNetworking.shared.sessionUploadBackgroundWWan,
                                                                                NCNetworking.shared.sessionUploadBackgroundExt,
                                                                                NCGlobal.shared.metadataStatusUploading))

        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                continue
            }
            var session: URLSession?

            if metadata.session == NCNetworking.shared.sessionUploadBackground {
                session = nkSession.sessionUploadBackground
            } else if metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan {
                session = nkSession.sessionUploadBackgroundWWan
            } else if metadata.session == NCNetworking.shared.sessionUploadBackgroundExt {
                session = nkSession.sessionUploadBackgroundExt
            }

            var foundTask = false
            guard let tasks = await session?.allTasks else {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                               sessionError: "",
                                                               status: NCGlobal.shared.metadataStatusWaitUpload)
                } else {
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                }
            }
        }

        /// DOWNLOADING-FOREGROUND -> STATUS: NORMAL
        ///
        metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                                NCNetworking.shared.sessionDownload,
                                                                                NCGlobal.shared.metadataStatusDownloading))

        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           session: "",
                                                           sessionError: "",
                                                           selector: "",
                                                           status: NCGlobal.shared.metadataStatusNormal)
            }
        }

        /// DOWNLOADING-BACKGROUND -> STATUS: NORMAL
        ///
        metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d",
                                                                                NCNetworking.shared.sessionDownloadBackground,
                                                                                NCGlobal.shared.metadataStatusDownloading))
        for metadata in metadatas {
            guard let nkSession = NextcloudKit.shared.getSession(account: metadata.account) else {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
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
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           session: "",
                                                           sessionError: "",
                                                           selector: "",
                                                           status: NCGlobal.shared.metadataStatusNormal)
            }
        }
    }
}
