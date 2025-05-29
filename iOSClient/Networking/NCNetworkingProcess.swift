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
    private var hasRun: Bool = false
    private let lockQueue = DispatchQueue(label: "com.nextcloud.networkingprocess.lockqueue")
    private var timer: Timer?
    private var enableControllingScreenAwake = true
    private var currentAccount: String = ""

    private init() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayerIsPlaying), object: nil, queue: nil) { _ in
            self.enableControllingScreenAwake = false
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayerStoppedPlaying), object: nil, queue: nil) { _ in
            self.enableControllingScreenAwake = true
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.timer?.invalidate()
            self.timer = nil
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !isAppInBackground {
                    self.startTimer()
                }
            }
        }
    }

    private func startTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true, block: { _ in
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
                       !isAppInBackground,
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
        let httpMaximumConnectionsPerHostInDownload = NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload
        var httpMaximumConnectionsPerHostInUpload = NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload
        let result = self.database.fetchNetworkingProcessState()
        var counterDownloading = result.counterDownloading
        var counterUploading = result.counterUploading
        let sessionUploadSelectors = [global.selectorUploadFileNODelete, global.selectorUploadFile, global.selectorUploadAutoUpload]
        let metadatasUploadError: [tableMetadata] = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusUploadError), sortedByKeyPath: "sessionDate", ascending: true) ?? []

        let isWiFi = networking.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi

        /// Check Server Error
        guard !self.currentAccount.isEmpty, networking.noServerErrorAccount(self.currentAccount) else {
            return (0, 0)
        }

        /// ------------------------ WEBDAV
        ///
        let metadatas = database.getMetadatas(predicate: NSPredicate(format: "status IN %@", global.metadataStatusWaitWebDav))
        if !metadatas.isEmpty {
            let error = await metadataStatusWaitWebDav()
            if error != .success {
                return (counterDownloading, counterUploading)
            }
        }

        /// ------------------------ DOWNLOAD
        ///
        let limitDownload = httpMaximumConnectionsPerHostInDownload - counterDownloading
        let metadatasWaitDownload = self.database.fetchNetworkingProcessDownload(limit: limitDownload, session: networking.sessionDownloadBackground)

        for metadata in metadatasWaitDownload where counterDownloading < httpMaximumConnectionsPerHostInDownload {
            counterDownloading += 1
            networking.download(metadata: metadata)
        }

        /// ------------------------ UPLOAD
        ///

        /// In background max 2 upload otherwise iOS Termination Reason: RUNNINGBOARD 0xdead10cc
        if isAppInBackground {
            httpMaximumConnectionsPerHostInUpload = 2
        }

        /// CHUNK or  E2EE - only one for time
        if self.database.hasUploadingMetadataWithChunksOrE2EE() {
            return (counterDownloading, counterUploading)
        }

        for sessionSelector in sessionUploadSelectors where counterUploading < httpMaximumConnectionsPerHostInUpload {
            let limitUpload = httpMaximumConnectionsPerHostInUpload - counterUploading
            let metadatasWaitUpload = self.database.fetchNetworkingProcessUpload(limit: limitUpload, sessionSelector: sessionSelector)

            if !metadatasWaitUpload.isEmpty {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] PROCESS (UPLOAD) find \(metadatasWaitUpload.count) items")
            }

            for metadata in metadatasWaitUpload where counterUploading < httpMaximumConnectionsPerHostInUpload {
                let metadatas = await NCCameraRoll().extractCameraRoll(from: metadata)

                if metadatas.isEmpty {
                    self.database.deleteMetadataOcId(metadata.ocId)
                }

                for metadata in metadatas where counterUploading < httpMaximumConnectionsPerHostInUpload {
                    /// isE2EE
                    let isInDirectoryE2EE = metadata.isDirectoryE2EE
                    /// NO WiFi
                    if !isWiFi && metadata.session == networking.sessionUploadBackgroundWWan { continue }
                    if isAppInBackground && (isInDirectoryE2EE || metadata.chunk > 0) { continue }
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
                /// Check QUOTA
                if metadata.sessionError.contains("\(global.errorQuota)") {
                    NextcloudKit.shared.getUserMetadata(account: metadata.account, userId: metadata.userId) { _, userProfile, _, error in
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

    private func metadataStatusWaitWebDav() async -> NKError {

        /// ------------------------ CREATE FOLDER
        ///
        if let metadatasWaitCreateFolder = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitCreateFolder), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitCreateFolder.isEmpty {
            for metadata in metadatasWaitCreateFolder {
                let errorCreateFolder = await networking.createFolder(fileName: metadata.fileName,
                                                                      serverUrl: metadata.serverUrl,
                                                                      overwrite: true,
                                                                      session: NCSession.shared.getSession(account: metadata.account),
                                                                      selector: metadata.sessionSelector)

                if let sceneIdentifier = metadata.sceneIdentifier {
                    NCNetworking.shared.notifyDelegates(forScene: sceneIdentifier) { delegate in
                        delegate.transferChange(status: self.global.networkingStatusCreateFolder,
                                                metadata: metadata,
                                                error: errorCreateFolder)
                    } others: { delegate in
                        delegate.transferReloadData(serverUrl: metadata.serverUrl)
                    }
                } else {
                    NCNetworking.shared.notifyAllDelegates { delegate in
                        delegate.transferChange(status: self.global.networkingStatusCreateFolder,
                                                metadata: metadata,
                                                error: errorCreateFolder)
                    }
                }
            }
        }

        /// ------------------------ COPY
        ///
        if let metadatasWaitCopy = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitCopy), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitCopy.isEmpty {
            for metadata in metadatasWaitCopy {
                let ocId = metadata.ocId
                let serverUrlTo = metadata.serverUrlTo
                let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
                var serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
                let overwrite = (metadata.storeFlag as? NSString)?.boolValue ?? false

                /// Within same folder
                if metadata.serverUrl == serverUrlTo {
                    let fileNameCopy = await NCNetworking.shared.createFileName(fileNameBase: metadata.fileName, account: metadata.account, serverUrl: metadata.serverUrl)
                    serverUrlFileNameDestination = serverUrlTo + "/" + fileNameCopy
                }

                let resultCopy = await NextcloudKit.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account)

                database.setMetadataStatus(ocId: ocId, status: global.metadataStatusNormal, sync: false)

                if resultCopy.error == .success {
                    let result = await NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileNameDestination, account: metadata.account)
                    if result.error == .success, let metadata = result.metadata {
                        database.addMetadata(metadata)
                    }
                }

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferCopy(metadata: metadata, error: resultCopy.error)
                }

                if resultCopy.error != .success {
                    return resultCopy.error
                }
            }
        }

        /// ------------------------ MOVE
        ///
        if let metadatasWaitMove = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitMove), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitMove.isEmpty {
            for metadata in metadatasWaitMove {
                let ocId = metadata.ocId
                let serverUrlTo = metadata.serverUrlTo
                let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
                let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
                let overwrite = (metadata.storeFlag as? NSString)?.boolValue ?? false

                let resultMove = await NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account)

                database.setMetadataStatus(ocId: ocId, status: global.metadataStatusNormal, sync: false)

                if resultMove.error == .success {
                    let result = await NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileNameDestination, account: metadata.account)
                    if result.error == .success, let metadata = result.metadata {
                        database.addMetadata(metadata)
                    }
                    // Remove source metadata
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
                }

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferMove(metadata: metadata, error: resultMove.error)
                }

                if resultMove.error != .success {
                    return resultMove.error
                }
            }
        }

        /// ------------------------ FAVORITE
        ///
        if let metadatasWaitFavorite = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitFavorite), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitFavorite.isEmpty {
            for metadata in metadatasWaitFavorite {
                let session = NCSession.Session(account: metadata.account, urlBase: metadata.urlBase, user: metadata.user, userId: metadata.userId)
                let fileName = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)
                let errorFavorite = await NextcloudKit.shared.setFavorite(fileName: fileName, favorite: metadata.favorite, account: metadata.account)

                if errorFavorite == .success {
                    database.setMetadataFavorite(ocId: metadata.ocId, favorite: nil, saveOldFavorite: nil, status: global.metadataStatusNormal)
                } else {
                    let favorite = (metadata.storeFlag as? NSString)?.boolValue ?? false
                    database.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite, saveOldFavorite: nil, status: global.metadataStatusNormal)
                }

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusFavorite,
                                            metadata: metadata,
                                            error: errorFavorite)
                }

                if errorFavorite != .success {
                    return errorFavorite
                }
            }
        }

        /// ------------------------ RENAME
        ///
        if let metadatasWaitRename = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitRename), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitRename.isEmpty {
            for metadata in metadatasWaitRename {
                let serverUrlFileNameSource = metadata.serveUrlFileName
                let serverUrlFileNameDestination = metadata.serverUrl + "/" + metadata.fileName
                let resultRename = await NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: false, account: metadata.account)

                if resultRename.error == .success {
                    database.setMetadataServeUrlFileNameStatusNormal(ocId: metadata.ocId)
                } else {
                    database.restoreMetadataFileName(ocId: metadata.ocId)
                }

                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferChange(status: NCGlobal.shared.networkingStatusRename,
                                            metadata: metadata,
                                            error: resultRename.error)
                }

                if resultRename.error != .success {
                    return resultRename.error
                }
            }
        }

        /// ------------------------ DELETE
        ///
        if let metadatasWaitDelete = self.database.getMetadatas(predicate: NSPredicate(format: "status == %d", global.metadataStatusWaitDelete), sortedByKeyPath: "serverUrl", ascending: true), !metadatasWaitDelete.isEmpty {
            var metadatasError: [tableMetadata: NKError] = [:]
            var returnError = NKError()

            for metadata in metadatasWaitDelete {
                let ocId = metadata.ocId
                let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
                let resultDelete = await NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: metadata.account)

                database.setMetadataStatus(ocId: ocId, status: global.metadataStatusNormal, sync: false)

                if resultDelete.error == .success || resultDelete.error.errorCode == NCGlobal.shared.errorResourceNotFound {
                    do {
                        try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                    } catch { }

                    NCImageCache.shared.removeImageCache(ocIdPlusEtag: metadata.ocId + metadata.etag)

                    self.database.deleteVideo(metadata: metadata)
                    self.database.deleteMetadataOcId(metadata.ocId)
                    self.database.deleteLocalFileOcId(metadata.ocId)

                    if metadata.directory {
                        self.database.deleteDirectoryAndSubDirectory(serverUrl: NCUtilityFileSystem().stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
                    }

                    metadatasError[tableMetadata(value: metadata)] = .success
                } else {
                    metadatasError[tableMetadata(value: metadata)] = resultDelete.error
                    returnError = resultDelete.error
                }
            }

            NCNetworking.shared.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusDelete,
                                        metadatasError: metadatasError)
            }

            if returnError != .success {
                return returnError
            }
        }

        return .success
    }

    // MARK: - Public

    func setCurrentAccount(_ account: String) {
        self.currentAccount = account
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
