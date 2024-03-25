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
    lazy var hudView = appDelegate.window?.rootViewController?.view
    var notificationToken: NotificationToken?
    var timerProcess: Timer?
    var hud: JGProgressHUD?
    var pauseProcess: Bool = false

    func startTimer() {
        self.timerProcess?.invalidate()
        self.timerProcess = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            guard !self.appDelegate.account.isEmpty, !self.pauseProcess else { return }
            if NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND status != %d", self.appDelegate.account, NCGlobal.shared.metadataStatusNormal)).isEmpty {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] PROCESS all normal status")
                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUpdateBadgeNumber), object: nil, userInfo: ["counterDownload": 0, "counterUpload": 0])
            } else {
                Task {
                    let results = await self.start()
                    print("[INFO] PROCESS (TIMER) Download: \(results.counterDownload) Upload: \(results.counterUpload)")
                    NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUpdateBadgeNumber), object: nil, userInfo: ["counterDownload": results.counterDownload, "counterUpload": results.counterUpload])
                }
            }
        })
    }

    func stopTimer() {
        self.timerProcess?.invalidate()
    }

    @discardableResult
    func start() async -> (counterDownload: Int, counterUpload: Int) {
        self.pauseProcess = true
        let applicationState = await UIApplication.shared.applicationState
        let maxConcurrentOperationDownload = NCBrandOptions.shared.maxConcurrentOperationDownload
        var maxConcurrentOperationUpload = NCBrandOptions.shared.maxConcurrentOperationUpload
        var filesNameLocalPath: [String] = []
        let sessionUploadSelectors = [NCGlobal.shared.selectorUploadFileNODelete, NCGlobal.shared.selectorUploadFile, NCGlobal.shared.selectorUploadAutoUpload, NCGlobal.shared.selectorUploadAutoUploadAll]
        let metadatasDownloading = await NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND status == %d", self.appDelegate.account, NCGlobal.shared.metadataStatusDownloading))
        let metadatasUploading = await NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND status == %d", self.appDelegate.account, NCGlobal.shared.metadataStatusUploading))
        let metadatasUploadInError: [tableMetadata] = await NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND status == %d", self.appDelegate.account, NCGlobal.shared.metadataStatusUploadError), sorted: "sessionDate", ascending: true) ?? []
        let isWiFi = NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi
        var counterDownload = metadatasDownloading.count
        var counterUpload = metadatasUploading.count
        if applicationState == .active {
            self.hud = await JGProgressHUD()
        }

        // ------------------------ DOWNLOAD

        let limitDownload = maxConcurrentOperationDownload - counterDownload
        let metadatasDownload = await NCManageDatabase.shared.getAdvancedMetadatas(predicate: NSPredicate(format: "account == %@ AND session == %@ AND status == %d", self.appDelegate.account, NCNetworking.shared.sessionDownloadBackground, NCGlobal.shared.metadataStatusWaitDownload), page: 1, limit: limitDownload, sorted: "sessionDate", ascending: true)
        for metadata in metadatasDownload where counterDownload < maxConcurrentOperationDownload {
            counterDownload += 1
            NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
        }
        if counterDownload == 0 {
            let metadatasDownloadInError: [tableMetadata] = await NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session == %@ AND status == %d", self.appDelegate.account, NCNetworking.shared.sessionDownloadBackground, NCGlobal.shared.metadataStatusDownloadError), sorted: "sessionDate", ascending: true) ?? []
            for metadata in metadatasDownloadInError {
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
                return (counterDownload, counterUpload)
            }
        }

        // CHUNK - only one for time
        if !metadatasUploading.filter({ $0.chunk > 0 }).isEmpty {
            self.pauseProcess = false
            return (counterDownload, counterUpload)
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

        for sessionSelector in sessionUploadSelectors where counterUpload < maxConcurrentOperationUpload {
            let limitUpload = maxConcurrentOperationUpload - counterUpload
            let metadatasUpload = await NCManageDatabase.shared.getAdvancedMetadatas(predicate: NSPredicate(format: "account == %@ AND sessionSelector == %@ AND status == %d", self.appDelegate.account, sessionSelector, NCGlobal.shared.metadataStatusWaitUpload), page: 1, limit: limitUpload, sorted: "sessionDate", ascending: true)
            if !metadatasUpload.isEmpty {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] PROCESS (UPLOAD) find \(metadatasUpload.count) items")
            }
            for metadata in metadatasUpload where counterUpload < maxConcurrentOperationUpload {
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
                for metadata in metadatas where counterUpload < maxConcurrentOperationUpload {
                    // isE2EE
                    let isInDirectoryE2EE = metadata.isDirectoryE2EE
                    // NO WiFi
                    if !isWiFi && metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan { continue }
                    if applicationState != .active && (isInDirectoryE2EE || metadata.chunk > 0) { continue }
                    if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusUploading) {
                        NCNetworking.shared.upload(metadata: metadata, hudView: self.hudView, hud: self.hud)
                        if isInDirectoryE2EE || metadata.chunk > 0 {
                            maxConcurrentOperationUpload = 1
                        }
                        counterUpload += 1
                    }
                }
            }
        }

        // No upload available ? --> Retry Upload in Error
        if counterUpload == 0 {
            for metadata in metadatasUploadInError {
                // Verify QUOTA
                if metadata.sessionError.contains("\(NCGlobal.shared.errorQuota)") {
                    NextcloudKit.shared.getUserProfile { _, userProfile, _, error in
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

        // No upload available ? --> Delete Assets
        if NCKeychain().removePhotoCameraRoll,
           applicationState == .active,
           counterUpload == 0,
           metadatasUploadInError.isEmpty {
            await self.deleteAssetsLocalIdentifiers(account: self.appDelegate.account)
        }

        self.pauseProcess = false
        return (counterDownload, counterUpload)
    }

    @MainActor private func deleteAssetsLocalIdentifiers(account: String) async {
        guard !NCPasscode.shared.isPasscodePresented,
              NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session CONTAINS[cd] %@", account, "upload")).isEmpty else {
            return
        }
        let localIdentifiers = NCManageDatabase.shared.getAssetLocalIdentifiersUploaded(account: account)
        if localIdentifiers.isEmpty { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)

        try? await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            NCManageDatabase.shared.clearAssetLocalIdentifiers(localIdentifiers, account: account)
        }
        return
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
}
