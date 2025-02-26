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
import RealmSwift

class NCNetworkingProcess {
    static let shared = NCNetworkingProcess()

    private let utilityFileSystem = NCUtilityFileSystem()
    private let database = NCManageDatabase.shared
    private let global = NCGlobal.shared
    private let networking = NCNetworking.shared
    private var notificationToken: NotificationToken?
    private var hasRun: Bool = false
    private let lockQueue = DispatchQueue(label: "com.nextcloud.networkingprocess.lockqueue")
    private var timerProcess: Timer?
    private var enableControllingScreenAwake = true

    private init() {
        self.startTimer()
        self.startObserveTableMetadata()

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayerIsPlaying), object: nil, queue: nil) { _ in

            self.enableControllingScreenAwake = false
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayerStoppedPlaying), object: nil, queue: nil) { _ in

            self.enableControllingScreenAwake = true
        }
    }

    private func startObserveTableMetadata() {
        do {
            let realm = try Realm()
            let results = realm.objects(tableMetadata.self).filter(NSPredicate(format: "status IN %@", global.metadataStatusObserveNetworkingProcess))
            notificationToken = results.observe { [weak self] (changes: RealmCollectionChange) in
                switch changes {
                case .initial:
                    print("Initial")
                case .update(_, _, let insertions, let modifications):
                    if insertions.count > 0 || modifications.count > 0 {
                        guard let self else { return }
                        self.startTimer()
                        self.lockQueue.async {
                            guard !self.hasRun, self.networking.isOnline else { return }
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

            self.lockQueue.async {
                guard !self.hasRun,
                      self.networking.isOnline,
                      let results = self.database.getResultsMetadatas(predicate: NSPredicate(format: "status != %d", self.global.metadataStatusNormal))?.freeze()
                else { return }
                self.hasRun = true

                /// Keep screen awake
                ///
                Task {
                    let tasks = await self.networking.getAllDataTask()
                    let hasSynchronizationTask = tasks.contains { $0.taskDescription == NCGlobal.shared.taskDescriptionSynchronization }
                    let resultsTransfer = results.filter { self.global.metadataStatusInTransfer.contains($0.status) }

                    if !self.enableControllingScreenAwake { return }

                    if resultsTransfer.isEmpty && !hasSynchronizationTask {
                        ScreenAwakeManager.shared.mode = .off
                    } else {
                        ScreenAwakeManager.shared.mode = NCKeychain().screenAwakeMode
                    }
                }

                if results.isEmpty {

                    /// Remove Photo CameraRoll
                    ///
                    if NCKeychain().removePhotoCameraRoll,
                       UIApplication.shared.applicationState == .active,
                       let localIdentifiers = self.database.getAssetLocalIdentifiersUploaded(),
                       !localIdentifiers.isEmpty {
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil) as NSFastEnumeration)
                        }, completionHandler: { _, _ in
                            self.database.clearAssetLocalIdentifiers(localIdentifiers)
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
        let httpMaximumConnectionsPerHostInDownload = NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload
        var httpMaximumConnectionsPerHostInUpload = NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload
        let sessionUploadSelectors = [global.selectorUploadFileNODelete, global.selectorUploadFile, global.selectorUploadAutoUpload, global.selectorUploadAutoUploadAll]
        let metadatasDownloading = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusDownloading))
        let metadatasUploading = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusUploading))
        let metadatasUploadError: [tableMetadata] = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusUploadError), sortedByKeyPath: "sessionDate", ascending: true) ?? []
        let isWiFi = networking.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi
        var counterDownloading = metadatasDownloading.count
        var counterUploading = metadatasUploading.count

        /// ------------------------ WEBDAV
        ///
        let metadatas = database.getMetadatas(predicate: NSPredicate(format: "status IN %@", global.metadataStatusWaitWebDav))
        if !metadatas.isEmpty {
            let stop = await metadataStatusWaitWebDav()
            if stop {
                return (counterDownloading, counterUploading)
            }
        }

        /// ------------------------ DOWNLOAD
        ///
        let limitDownload = httpMaximumConnectionsPerHostInDownload - counterDownloading
        let metadatasWaitDownload = self.database.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", networking.sessionDownloadBackground, global.metadataStatusWaitDownload), numItems: limitDownload, sorted: "sessionDate", ascending: true)
        for metadata in metadatasWaitDownload where counterDownloading < httpMaximumConnectionsPerHostInDownload {
            counterDownloading += 1
            networking.download(metadata: metadata, withNotificationProgressTask: true)
        }
        if counterDownloading == 0 {
            let metadatasDownloadError: [tableMetadata] = self.database.getMetadatas(predicate: NSPredicate(format: "session == %@ AND status == %d", networking.sessionDownloadBackground, global.metadataStatusDownloadError), sortedByKeyPath: "sessionDate", ascending: true) ?? []
            for metadata in metadatasDownloadError {
                // Verify COUNTER ERROR
                if let transfer = NCTransferProgress.shared.get(ocIdTransfer: metadata.ocIdTransfer),
                   transfer.countError > 3 {
                    continue
                }
                self.database.setMetadataSession(ocId: metadata.ocId,
                                                 sessionError: "",
                                                 status: global.metadataStatusWaitDownload)
            }
        }

        /// ------------------------ UPLOAD
        ///

        /// In background max 2 upload otherwise iOS Termination Reason: RUNNINGBOARD 0xdead10cc
        if applicationState == .background {
            httpMaximumConnectionsPerHostInUpload = 2
        }

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

        for sessionSelector in sessionUploadSelectors where counterUploading < httpMaximumConnectionsPerHostInUpload {
            let limitUpload = httpMaximumConnectionsPerHostInUpload - counterUploading
            let metadatasWaitUpload = self.database.getMetadatas(predicate: NSPredicate(format: "sessionSelector == %@ AND status == %d", sessionSelector, global.metadataStatusWaitUpload), numItems: limitUpload, sorted: "sessionDate", ascending: true)

            if !metadatasWaitUpload.isEmpty {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] PROCESS (UPLOAD) find \(metadatasWaitUpload.count) items")
            }

            for metadata in metadatasWaitUpload where counterUploading < httpMaximumConnectionsPerHostInUpload {

                if NCTransferProgress.shared.get(ocIdTransfer: metadata.ocIdTransfer) != nil {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Process auto upload skipped file: \(metadata.serverUrl)/\(metadata.fileNameView), because is already in session.")
                    continue
                }

                let metadatas = await NCCameraRoll().extractCameraRoll(from: metadata)

                if metadatas.isEmpty {
                    self.database.deleteMetadataOcId(metadata.ocId)
                }

                for metadata in metadatas where counterUploading < httpMaximumConnectionsPerHostInUpload {
                    /// isE2EE
                    let isInDirectoryE2EE = metadata.isDirectoryE2EE
                    /// NO WiFi
                    if !isWiFi && metadata.session == networking.sessionUploadBackgroundWWan { continue }
                    if applicationState != .active && (isInDirectoryE2EE || metadata.chunk > 0) { continue }
                    if let metadata = self.database.setMetadataStatus(ocId: metadata.ocId, status: global.metadataStatusUploading) {
                        /// find controller
                        var controller: NCMainTabBarController?
                        if let sceneIdentifier = metadata.sceneIdentifier, !sceneIdentifier.isEmpty {
                            controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier)
                        } else {
                            for ctlr in SceneManager.shared.getControllers() {
                                let account = await ctlr.account
                                if account == metadata.account {
                                    controller = ctlr
                                }
                            }

                            if controller == nil {
                                controller = await UIApplication.shared.firstWindow?.rootViewController as? NCMainTabBarController
                            }
                        }

                        networking.upload(metadata: metadata, controller: controller)
                        if isInDirectoryE2EE || metadata.chunk > 0 {
                            httpMaximumConnectionsPerHostInUpload = 1
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
                            self.database.setMetadataSession(ocId: metadata.ocId,
                                                             session: self.networking.sessionUploadBackground,
                                                             sessionError: "",
                                                             status: self.global.metadataStatusWaitUpload)
                        }
                    }
                } else {
                    self.database.setMetadataSession(ocId: metadata.ocId,
                                                     session: self.networking.sessionUploadBackground,
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

    private func metadataStatusWaitWebDav() async -> Bool {
        var returnValue: Bool = false

        /// ------------------------ CREATE FOLDER
        ///
        if let metadatasWaitCreateFolder = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitCreateFolder), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitCreateFolder.isEmpty {
            for metadata in metadatasWaitCreateFolder {
                let error = await networking.createFolder(metadata: metadata)

                if error != .success {
                    if metadata.sessionError.isEmpty {
                        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
                        let message = String(format: NSLocalizedString("_create_folder_error_", comment: ""), serverUrlFileName)
                        NCContentPresenter().messageNotification(message, error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                    }
                    returnValue = true
                }
            }
        }

        /// ------------------------ COPY
        ///
        if let metadatasWaitCopy = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitCopy), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitCopy.isEmpty {
            for metadata in metadatasWaitCopy {
                let serverUrlTo = metadata.serverUrlTo
                let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
                var serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
                let overwrite = (metadata.storeFlag as? NSString)?.boolValue ?? false

                /// Within same folder
                if metadata.serverUrl == serverUrlTo {
                    let fileNameCopy = await NCNetworking.shared.createFileName(fileNameBase: metadata.fileName, account: metadata.account, serverUrl: metadata.serverUrl)
                    serverUrlFileNameDestination = serverUrlTo + "/" + fileNameCopy
                }

                let result = await networking.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account)

                database.setMetadataCopyMove(ocId: metadata.ocId, serverUrlTo: "", overwrite: nil, status: global.metadataStatusNormal)

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCopyMoveFile, userInfo: ["serverUrl": metadata.serverUrl, "account": metadata.account, "dragdrop": false, "type": "copy"])

                if result.error == .success {

                    NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterGetServerData, userInfo: ["serverUrl": metadata.serverUrl])
                    NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterGetServerData, userInfo: ["serverUrl": serverUrlTo])

                } else {
                    NCContentPresenter().showError(error: result.error)
                }
            }
        }

        /// ------------------------ MOVE
        ///
        if let metadatasWaitMove = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitMove), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitMove.isEmpty {
            for metadata in metadatasWaitMove {
                let serverUrlTo = metadata.serverUrlTo
                let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
                let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
                let overwrite = (metadata.storeFlag as? NSString)?.boolValue ?? false

                let result = await networking.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account)

                database.setMetadataCopyMove(ocId: metadata.ocId, serverUrlTo: "", overwrite: nil, status: global.metadataStatusNormal)

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCopyMoveFile, userInfo: ["serverUrl": metadata.serverUrl, "account": metadata.account, "dragdrop": false, "type": "move"])

                if result.error == .success {
                    if metadata.directory {
                        self.database.deleteDirectoryAndSubDirectory(serverUrl: utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: result.account)
                    } else {
                        do {
                            try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                        } catch { }
                        self.database.deleteVideo(metadata: metadata)
                        self.database.deleteMetadataOcId(metadata.ocId)
                        self.database.deleteLocalFileOcId(metadata.ocId)
                        // LIVE PHOTO
                        if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata) {
                            do {
                                try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
                            } catch { }
                            self.database.deleteVideo(metadata: metadataLive)
                            self.database.deleteMetadataOcId(metadataLive.ocId)
                            self.database.deleteLocalFileOcId(metadataLive.ocId)
                        }
                    }

                    NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterGetServerData, userInfo: ["serverUrl": metadata.serverUrl])
                    NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterGetServerData, userInfo: ["serverUrl": serverUrlTo])

                } else {
                    NCContentPresenter().showError(error: result.error)
                }
            }
        }

        /// ------------------------ FAVORITE
        ///
        if let metadatasWaitFavorite = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitFavorite), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitFavorite.isEmpty {
            for metadata in metadatasWaitFavorite {
                let session = NCSession.Session(account: metadata.account, urlBase: metadata.urlBase, user: metadata.user, userId: metadata.userId)
                let fileName = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)
                let error = await networking.setFavorite(fileName: fileName, favorite: metadata.favorite, account: metadata.account)

                if error == .success {
                    database.setMetadataFavorite(ocId: metadata.ocId, favorite: nil, saveOldFavorite: nil, status: global.metadataStatusNormal)
                } else {
                    let favorite = (metadata.storeFlag as? NSString)?.boolValue ?? false
                    database.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite, saveOldFavorite: nil, status: global.metadataStatusNormal)
                }

                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterFavoriteFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl])
            }
        }

        /// ------------------------ RENAME
        ///
        if let metadatasWaitRename = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitRename), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitRename.isEmpty {
            for metadata in metadatasWaitRename {
                let serverUrlFileNameSource = metadata.serveUrlFileName
                let serverUrlFileNameDestination = metadata.serverUrl + "/" + metadata.fileName
                let result = await networking.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: false, account: metadata.account)

                if result.error == .success {
                    database.setMetadataServeUrlFileNameStatusNormal(ocId: metadata.ocId)
                } else {
                    database.restoreMetadataFileName(ocId: metadata.ocId)
                }

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRenameFile, userInfo: ["serverUrl": metadata.serverUrl, "account": metadata.account, "error": result.error])
            }
        }

        /// ------------------------ DELETE
        ///
        if let metadatasWaitDelete = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitDelete), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitDelete.isEmpty {
            for metadata in metadatasWaitDelete {
                if networking.deleteFileOrFolderQueue.operations.filter({ ($0 as? NCOperationDeleteFileOrFolder)?.ocId == metadata.ocId }).isEmpty {
                    networking.deleteFileOrFolderQueue.addOperation(NCOperationDeleteFileOrFolder(metadata: metadata))
                }
            }
        }

        return returnValue
    }

    // MARK: - Public

    func startProcess() {
        startTimer()
        startObserveTableMetadata()
    }

    func stopProcess() {
        timerProcess?.invalidate()
        timerProcess = nil
        notificationToken?.invalidate()
        notificationToken = nil
    }

    func refreshProcessingTask() async -> (counterDownloading: Int, counterUploading: Int) {
        await withCheckedContinuation { continuation in
            self.lockQueue.sync {
                guard !self.hasRun, networking.isOnline else { return }
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
                if self.database.getMetadata(predicate: NSPredicate(format: "account == %@ && serverUrl == %@ && fileName == %@ && session != ''",
                                                                    metadata.account,
                                                                    metadata.serverUrl,
                                                                    metadata.fileName)) != nil {
                    continue
                }
            }
            metadatasForUpload.append(metadata)
        }
        self.database.addMetadatas(metadatasForUpload)
        completion(metadatasForUpload.count)
    }
}
