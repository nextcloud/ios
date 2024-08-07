//
//  NCNetworkingProcess.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/06/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

import UIKit
import NextcloudKit
import Photos
import JGProgressHUD
import RealmSwift

class NCNetworkingProcess: NSObject {
    public static let shared: NCNetworkingProcess = {
        let instance = NCNetworkingProcess()
        return instance
    }()

    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    var notificationToken: NotificationToken?
    var timerProcess: Timer?
    var hud: JGProgressHUD?
    var pauseProcess: Bool = false

    func startTimer(scene: UIScene) {
        self.timerProcess?.invalidate()
        self.timerProcess = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { _ in
            guard !self.appDelegate.account.isEmpty,
                  !self.pauseProcess else { return }

            // In Downloading or Uploading [TEST]
            /*
            if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "account == %@ AND (status == %d || status == %d)", self.appDelegate.account, NCGlobal.shared.metadataStatusDownloading, NCGlobal.shared.metadataStatusUploading)) {
                if !results.isEmpty {
                   return
                }
            }
            */

            guard let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "account == %@ AND status != %d", self.appDelegate.account, NCGlobal.shared.metadataStatusNormal)) else { return }

            if results.isEmpty {
                //
                // Remove Photo CameraRoll
                //
                if NCKeychain().removePhotoCameraRoll,
                   UIApplication.shared.applicationState == .active,
                   let localIdentifiers = NCManageDatabase.shared.getAssetLocalIdentifiersUploaded(account: self.appDelegate.account),
                   !localIdentifiers.isEmpty {
                    self.pauseProcess = true
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil) as NSFastEnumeration)
                    }, completionHandler: { _, _ in
                        NCManageDatabase.shared.clearAssetLocalIdentifiers(localIdentifiers, account: self.appDelegate.account)
                        self.pauseProcess = false
                    })
                }
                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUpdateBadgeNumber), object: nil, userInfo: ["counterDownload": 0, "counterUpload": 0])
            } else {
                Task {
                    let results = await self.start(scene: scene)
                    let counterDownload = await NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "account == %@ AND session == %@ AND (status == %d || status == %d)", self.appDelegate.account, NCNetworking.shared.sessionDownloadBackground, NCGlobal.shared.metadataStatusWaitDownload, NCGlobal.shared.metadataStatusDownloading))?.count ?? 0
                    let counterUpload = await NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "account == %@ AND session == %@ AND (status == %d || status == %d)", self.appDelegate.account, NCNetworking.shared.sessionUploadBackground, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploading))?.count ?? 0
                    print("[INFO] PROCESS Download: \(results.counterDownloading)/\(counterDownload) Upload: \(results.counterUploading)/\(counterUpload)")
                    NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUpdateBadgeNumber), object: nil, userInfo: ["counterDownload": counterDownload, "counterUpload": counterUpload])
                }
            }
        })
    }

    func stopTimer() {
        self.timerProcess?.invalidate()
    }

    @discardableResult
    func start(scene: UIScene?) async -> (counterDownloading: Int, counterUploading: Int) {
        self.pauseProcess = true
        let hudView = await SceneManager.shared.getController(scene: scene)?.view
        let applicationState = await checkApplicationState()
        let maxConcurrentOperationDownload = NCBrandOptions.shared.maxConcurrentOperationDownload
        var maxConcurrentOperationUpload = NCBrandOptions.shared.maxConcurrentOperationUpload
        var filesNameLocalPath: [String] = []
        let sessionUploadSelectors = [NCGlobal.shared.selectorUploadFileNODelete, NCGlobal.shared.selectorUploadFile, NCGlobal.shared.selectorUploadAutoUpload, NCGlobal.shared.selectorUploadAutoUploadAll]
        let metadatasDownloading = await NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND status == %d", self.appDelegate.account, NCGlobal.shared.metadataStatusDownloading))
        let metadatasUploading = await NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND status == %d", self.appDelegate.account, NCGlobal.shared.metadataStatusUploading))
        let metadatasUploadError: [tableMetadata] = await NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND status == %d", self.appDelegate.account, NCGlobal.shared.metadataStatusUploadError), sorted: "sessionDate", ascending: true) ?? []
        let isWiFi = NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi
        var counterDownloading = metadatasDownloading.count
        var counterUploading = metadatasUploading.count
        if applicationState == .active {
            self.hud = await JGProgressHUD()
        }

        // ------------------------ DOWNLOAD

        let limitDownload = maxConcurrentOperationDownload - counterDownloading
        let metadatasWaitDownload = await NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session == %@ AND status == %d", self.appDelegate.account, NCNetworking.shared.sessionDownloadBackground, NCGlobal.shared.metadataStatusWaitDownload), numItems: limitDownload, sorted: "sessionDate", ascending: true)
        for metadata in metadatasWaitDownload where counterDownloading < maxConcurrentOperationDownload {
            counterDownloading += 1
            NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
        }
        if counterDownloading == 0 {
            let metadatasDownloadError: [tableMetadata] = await NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session == %@ AND status == %d", self.appDelegate.account, NCNetworking.shared.sessionDownloadBackground, NCGlobal.shared.metadataStatusDownloadError), sorted: "sessionDate", ascending: true) ?? []
            for metadata in metadatasDownloadError {
                // Verify COUNTER ERROR
                if let counter = NCNetworking.shared.transferInError[metadata.ocId],
                   counter > 3 {
                    continue
                }
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           sessionError: "",
                                                           status: NCGlobal.shared.metadataStatusWaitDownload)
            }
        }

        // ------------------------ UPLOAD

        // E2EE - only one for time
        for metadata in metadatasUploading.unique(map: { $0.serverUrl }) {
            if metadata.isDirectoryE2EE {
                self.pauseProcess = false
                return (counterDownloading, counterUploading)
            }
        }

        // CHUNK - only one for time
        if !metadatasUploading.filter({ $0.chunk > 0 }).isEmpty {
            self.pauseProcess = false
            return (counterDownloading, counterUploading)
        }

        // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
        let tasksBackground = await NCNetworking.shared.sessionManagerUploadBackground.tasks
        for task in tasksBackground.1 {
            filesNameLocalPath.append(task.description)
        }
        let tasksBackgroundWWan = await NCNetworking.shared.sessionManagerUploadBackgroundWWan.tasks
        for task in tasksBackgroundWWan.1 {
            filesNameLocalPath.append(task.description)
        }

        for sessionSelector in sessionUploadSelectors where counterUploading < maxConcurrentOperationUpload {
            let limitUpload = maxConcurrentOperationUpload - counterUploading
            let metadatasWaitUpload = await NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND sessionSelector == %@ AND status == %d", self.appDelegate.account, sessionSelector, NCGlobal.shared.metadataStatusWaitUpload), numItems: limitUpload, sorted: "sessionDate", ascending: true)
            if !metadatasWaitUpload.isEmpty {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] PROCESS (UPLOAD) find \(metadatasWaitUpload.count) items")
            }
            for metadata in metadatasWaitUpload where counterUploading < maxConcurrentOperationUpload {
                // Is already in upload background? skipped
                let fileNameLocalPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
                if filesNameLocalPath.contains(fileNameLocalPath) {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Process auto upload skipped file: \(metadata.serverUrl)/\(metadata.fileNameView), because is already in session.")
                    continue
                }
                // Session Extension ? skipped
                if metadata.session == NCNetworking.shared.sessionUploadBackgroundExtension {
                    continue
                }
                let metadatas = await NCCameraRoll().extractCameraRoll(from: metadata)
                if metadatas.isEmpty {
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                }
                for metadata in metadatas where counterUploading < maxConcurrentOperationUpload {
                    // isE2EE
                    let isInDirectoryE2EE = metadata.isDirectoryE2EE
                    // NO WiFi
                    if !isWiFi && metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan { continue }
                    if applicationState != .active && (isInDirectoryE2EE || metadata.chunk > 0) { continue }
                    if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusUploading) {
                        NCNetworking.shared.upload(metadata: metadata, hudView: hudView, hud: self.hud)
                        if isInDirectoryE2EE || metadata.chunk > 0 {
                            maxConcurrentOperationUpload = 1
                        }
                        counterUploading += 1
                    }
                }
            }
        }

        // No upload available ? --> Retry Upload in Error
        if counterUploading == 0 {
            for metadata in metadatasUploadError {
                // Verify COUNTER ERROR
                if let counter = NCNetworking.shared.transferInError[metadata.ocId],
                   counter > 3 {
                    continue
                }
                // Verify QUOTA
                if metadata.sessionError.contains("\(NCGlobal.shared.errorQuota)") {
                    NextcloudKit.shared.getUserProfile(account: metadata.account) { _, userProfile, _, error in
                        if error == .success, let userProfile, userProfile.quotaFree > 0, userProfile.quotaFree > metadata.size {
                            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                                       session: NCNetworking.shared.sessionUploadBackground,
                                                                       sessionError: "",
                                                                       status: NCGlobal.shared.metadataStatusWaitUpload)
                        }
                    }
                } else {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                               session: NCNetworking.shared.sessionUploadBackground,
                                                               sessionError: "",
                                                               status: NCGlobal.shared.metadataStatusWaitUpload)
                }
            }
        }

        self.pauseProcess = false
        return (counterDownloading, counterUploading)
    }

    func checkApplicationState() async -> UIApplication.State {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let appState = UIApplication.shared.applicationState
                continuation.resume(returning: appState)
            }
        }
    }

    // MARK: -

    func createProcessUploads(metadatas: [tableMetadata], verifyAlreadyExists: Bool = false, completion: @escaping (_ items: Int) -> Void = {_ in}) {
        var metadatasForUpload: [tableMetadata] = []
        for metadata in metadatas {
            if verifyAlreadyExists {
                if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && serverUrl == %@ && fileName == %@ && session != ''", metadata.account, metadata.serverUrl, metadata.fileName)) != nil {
                    continue
                }
            }
            metadatasForUpload.append(metadata)
        }
        NCManageDatabase.shared.addMetadatas(metadatasForUpload)
        completion(metadatasForUpload.count)
    }

    // MARK: -

    func verifyZombie() async {
        // selectorUploadFileShareExtension (FOREGROUND)
        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "session == %@ AND sessionSelector == %@", NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload, NCGlobal.shared.selectorUploadFileShareExtension)) {
            for metadata in results {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            }
        }

        // metadataStatusUploading (FOREGROUND)
        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload, NCGlobal.shared.metadataStatusUploading)) {
            if results.isEmpty { NCNetworking.shared.transferInForegorund = nil }
            for metadata in results {
                let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
                if NCNetworking.shared.uploadRequest[fileNameLocalPath] == nil {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                               status: NCGlobal.shared.metadataStatusWaitUpload)
                }
            }
        }

        // metadataStatusDownloading (FOREGROUND)
        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload, NCGlobal.shared.metadataStatusDownloading)) {
            for metadata in results {
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           session: "",
                                                           sessionError: "",
                                                           selector: "",
                                                           status: NCGlobal.shared.metadataStatusNormal)
            }
        }

        // metadataStatusUploading (BACKGROUND)
        let resultsUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "(session == %@ OR session == %@ OR session == %@) AND status == %d", NCNetworking.shared.sessionUploadBackground, NCNetworking.shared.sessionUploadBackgroundWWan, NCNetworking.shared.sessionUploadBackgroundExtension, NCGlobal.shared.metadataStatusUploading))
        for metadata in resultsUpload {
            var taskUpload: URLSessionTask?
            var session: URLSession?
            if metadata.session == NCNetworking.shared.sessionUploadBackground {
                session = NCNetworking.shared.sessionManagerUploadBackground
            } else if metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan {
                session = NCNetworking.shared.sessionManagerUploadBackgroundWWan
            }
            if let tasks = await session?.allTasks {
                for task in tasks {
                    if task.taskIdentifier == metadata.sessionTaskIdentifier { taskUpload = task }
                }
                if taskUpload == nil, let metadata = NCManageDatabase.shared.getResultMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d", metadata.ocId, NCGlobal.shared.metadataStatusUploading)) {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                               session: NCNetworking.shared.sessionUploadBackground,
                                                               sessionError: "",
                                                               status: NCGlobal.shared.metadataStatusWaitUpload)
                }
            }
        }

        // metadataStatusDowloading (BACKGROUND)
        let resultsDownload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", NCNetworking.shared.sessionDownloadBackground, NCGlobal.shared.metadataStatusDownloading))
        for metadata in resultsDownload {
            var taskDownload: URLSessionTask?
            let session: URLSession? = NCNetworking.shared.sessionManagerDownloadBackground
            if let tasks = await session?.allTasks {
                for task in tasks {
                    if task.taskIdentifier == metadata.sessionTaskIdentifier { taskDownload = task }
                }
                if taskDownload == nil, let metadata = NCManageDatabase.shared.getResultMetadata(predicate: NSPredicate(format: "ocId == %@ AND status == %d", metadata.ocId, NCGlobal.shared.metadataStatusDownloading)) {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                               session: NCNetworking.shared.sessionDownloadBackground,
                                                               sessionError: "",
                                                               status: NCGlobal.shared.metadataStatusWaitDownload)
                }
            }
        }
    }
}
