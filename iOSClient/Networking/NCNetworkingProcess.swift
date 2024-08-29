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

class NCNetworkingProcess {
    static let shared = NCNetworkingProcess()

    private let utilityFileSystem = NCUtilityFileSystem()
    private var notificationToken: NotificationToken?
    private var hasRun: Bool = false
    private let lockQueue = DispatchQueue(label: "com.nextcloud.networkingprocess.lockqueue")
    private let global = NCGlobal.shared
    private var timerProcess: Timer?
    private let hud: JGProgressHUD = JGProgressHUD()

    private init() {
        self.startTimer()
        self.startObserveTableMetadata()
    }

    private func startObserveTableMetadata() {
        do {
            let realm = try Realm()
            let results = realm.objects(tableMetadata.self).filter("status IN %d", [global.metadataStatusWaitDownload, global.metadataStatusWaitUpload, global.metadataStatusWaitCreateFolder])
            notificationToken = results.observe { [weak self] (changes: RealmCollectionChange) in
                switch changes {
                case .initial:
                    print("Initial")
                case .update(let metadatas, let deletions, let insertions, let modifications):
                    if insertions.count > 0 || modifications.count > 0 {
                        guard let self else { return }

                        self.lockQueue.sync {
                            guard !self.hasRun, NCNetworking.shared.isOnline else { return }
                            self.hasRun = true

                            Task { [weak self] in
                                guard let self else { return }
                                await self.start()
                                self.hasRun = false
                            }
                        }
                    }
                case .error(let error):
                    print("Error: \(error.localizedDescription)")
                }
            }
        } catch let error {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func startTimer() {
        self.timerProcess?.invalidate()
        self.timerProcess = Timer.scheduledTimer(withTimeInterval: 3, repeats: true, block: { _ in

            self.lockQueue.sync {
                guard !self.hasRun, NCNetworking.shared.isOnline else { return }
                self.hasRun = true

                guard let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status != %d", NCGlobal.shared.metadataStatusNormal)) else { return }

                if results.isEmpty {
                    /// Remove Photo CameraRoll
                    ///
                    if NCKeychain().removePhotoCameraRoll,
                       UIApplication.shared.applicationState == .active,
                       let localIdentifiers = NCManageDatabase.shared.getAssetLocalIdentifiersUploaded(),
                       !localIdentifiers.isEmpty {
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil) as NSFastEnumeration)
                        }, completionHandler: { _, _ in
                            NCManageDatabase.shared.clearAssetLocalIdentifiers(localIdentifiers)
                            self.hasRun = false
                        })
                    } else {
                        self.hasRun = false
                    }
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUpdateBadgeNumber,
                                                                object: nil,
                                                                userInfo: ["counterDownload": 0,
                                                                           "counterUpload": 0])
                } else {
                    Task { [weak self] in
                        guard let self else { return }
                        await self.start()
                        self.hasRun = false
                    }
                }
            }
        })
    }

    @discardableResult
    private func start() async -> (counterDownloading: Int, counterUploading: Int) {
        let applicationState = await checkApplicationState()
        let maxConcurrentOperationDownload = NCBrandOptions.shared.maxConcurrentOperationDownload
        var maxConcurrentOperationUpload = NCBrandOptions.shared.maxConcurrentOperationUpload
        let sessionUploadSelectors = [global.selectorUploadFileNODelete, global.selectorUploadFile, global.selectorUploadAutoUpload, global.selectorUploadAutoUploadAll]
        let metadatasDownloading = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusDownloading))
        let metadatasUploading = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusUploading))
        let metadatasUploadError: [tableMetadata] = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusUploadError), sorted: "sessionDate", ascending: true) ?? []
        let isWiFi = NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi
        var counterDownloading = metadatasDownloading.count
        var counterUploading = metadatasUploading.count

        /// ------------------------ FOLDER
        ///
        if let metadatasWaitCreateFolder = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitCreateFolder), sorted: "serverUrl", ascending: true) {
            for metadata in metadatasWaitCreateFolder {
                let error = await NCNetworking.shared.createFolderOffline(metadata: metadata)
                if error != .success {
                    if metadata.sessionError.isEmpty {
                        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
                        let message = String(format: NSLocalizedString("_offlinefolder_error_", comment: ""), serverUrlFileName)
                        NCContentPresenter().messageNotification(message, error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                    }
                    return (counterDownloading, counterUploading)
                }
            }
        }

        /// ------------------------ DOWNLOAD
        ///
        let limitDownload = maxConcurrentOperationDownload - counterDownloading
        let metadatasWaitDownload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", NCNetworking.shared.sessionDownloadBackground, global.metadataStatusWaitDownload), numItems: limitDownload, sorted: "sessionDate", ascending: true)
        for metadata in metadatasWaitDownload where counterDownloading < maxConcurrentOperationDownload {
            counterDownloading += 1
            NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
        }
        if counterDownloading == 0 {
            let metadatasDownloadError: [tableMetadata] = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", NCNetworking.shared.sessionDownloadBackground, global.metadataStatusDownloadError), sorted: "sessionDate", ascending: true) ?? []
            for metadata in metadatasDownloadError {
                // Verify COUNTER ERROR
                if let transfer = NCTransferProgress.shared.get(ocIdTransfer: metadata.ocIdTransfer),
                   transfer.countError > 3 {
                    continue
                }
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           sessionError: "",
                                                           status: global.metadataStatusWaitDownload)
            }
        }

        /// ------------------------ UPLOAD
        ///

        /// E2EE - only one for time
        for metadata in metadatasUploading.unique(map: { $0.serverUrl }) {
            if metadata.isDirectoryE2EE {
                return (counterDownloading, counterUploading)
            }
        }

        /// CHUNK - only one for time
        if !metadatasUploading.filter({ $0.chunk > 0 }).isEmpty {
            return (counterDownloading, counterUploading)
        }

        for sessionSelector in sessionUploadSelectors where counterUploading < maxConcurrentOperationUpload {
            let limitUpload = maxConcurrentOperationUpload - counterUploading
            let metadatasWaitUpload = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "sessionSelector == %@ AND status == %d", sessionSelector, global.metadataStatusWaitUpload), numItems: limitUpload, sorted: "sessionDate", ascending: true)

            if !metadatasWaitUpload.isEmpty {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] PROCESS (UPLOAD) find \(metadatasWaitUpload.count) items")
            }

            for metadata in metadatasWaitUpload where counterUploading < maxConcurrentOperationUpload {

                if NCTransferProgress.shared.get(ocIdTransfer: metadata.ocIdTransfer) != nil {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Process auto upload skipped file: \(metadata.serverUrl)/\(metadata.fileNameView), because is already in session.")
                    continue
                }

                let metadatas = await NCCameraRoll().extractCameraRoll(from: metadata)

                if metadatas.isEmpty {
                    NCManageDatabase.shared.deleteMetadataOcId(metadata.ocId)
                }

                for metadata in metadatas where counterUploading < maxConcurrentOperationUpload {
                    /// isE2EE
                    let isInDirectoryE2EE = metadata.isDirectoryE2EE
                    /// NO WiFi
                    if !isWiFi && metadata.session == NCNetworking.shared.sessionUploadBackgroundWWan { continue }
                    if applicationState != .active && (isInDirectoryE2EE || metadata.chunk > 0) { continue }
                    if let metadata = NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: global.metadataStatusUploading) {
                        var hudView: UIView?

                        if let sceneIdentifier = metadata.sceneIdentifier, !sceneIdentifier.isEmpty {
                            let controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier)
                            hudView = await controller?.view
                        }

                        if hudView == nil {
                            let controllers = SceneManager.shared.getControllers()
                            for controller in controllers {
                                if await controller.account == metadata.account {
                                    hudView = await controller.view
                                }
                            }
                        }

                        if hudView == nil {
                            let controller = await UIApplication.shared.firstWindow?.rootViewController
                            hudView = await controller?.view
                        }

                        NCNetworking.shared.upload(metadata: metadata, hudView: hudView, hud: self.hud)
                        if isInDirectoryE2EE || metadata.chunk > 0 {
                            maxConcurrentOperationUpload = 1
                        }
                        counterUploading += 1
                    }
                }
            }
        }

        /// No upload available ? --> Retry Upload in Error
        ///
        if counterUploading == 0 {
            for metadata in metadatasUploadError {
                // Verify COUNTER ERROR
                if let transfer = NCTransferProgress.shared.get(ocIdTransfer: metadata.ocIdTransfer),
                   transfer.countError > 3 {
                    continue
                }
                /// Verify QUOTA
                if metadata.sessionError.contains("\(global.errorQuota)") {
                    NextcloudKit.shared.getUserProfile(account: metadata.account) { _, userProfile, _, error in
                        if error == .success, let userProfile, userProfile.quotaFree > 0, userProfile.quotaFree > metadata.size {
                            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                                       session: NCNetworking.shared.sessionUploadBackground,
                                                                       sessionError: "",
                                                                       status: self.global.metadataStatusWaitUpload)
                        }
                    }
                } else {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                               session: NCNetworking.shared.sessionUploadBackground,
                                                               sessionError: "",
                                                               status: global.metadataStatusWaitUpload)
                }
            }
        }

        return (counterDownloading, counterUploading)
    }

    private func checkApplicationState() async -> UIApplication.State {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let appState = UIApplication.shared.applicationState
                continuation.resume(returning: appState)
            }
        }
    }

    // MARK: - Public

    func refreshProcessingTask() async -> (counterDownloading: Int, counterUploading: Int) {
        await withCheckedContinuation { continuation in
            self.lockQueue.sync {
                guard !self.hasRun, NCNetworking.shared.isOnline else { return }
                self.hasRun = true

                Task { [weak self] in
                    guard let self else { return }
                    let result = await self.start()
                    self.hasRun = false
                    continuation.resume(returning: result)
                }
            }
        }
    }

    func createProcessUploads(metadatas: [tableMetadata], verifyAlreadyExists: Bool = false, completion: @escaping (_ items: Int) -> Void = {_ in}) {
        var metadatasForUpload: [tableMetadata] = []
        for metadata in metadatas {
            if verifyAlreadyExists {
                if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && serverUrl == %@ && fileName == %@ && session != ''",
                                                                              metadata.account,
                                                                              metadata.serverUrl,
                                                                              metadata.fileName)) != nil {
                    continue
                }
            }
            metadatasForUpload.append(metadata)
        }
        NCManageDatabase.shared.addMetadatas(metadatasForUpload)
        completion(metadatasForUpload.count)
    }
}
