// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Photos
import RealmSwift

actor NCNetworkingProcess {
    static let shared = NCNetworkingProcess()

    private let utilityFileSystem = NCUtilityFileSystem()
    private let database = NCManageDatabase.shared
    private let global = NCGlobal.shared
    private let networking = NCNetworking.shared

    private var currentTask: Task<Void, Never>?
    private var enableControllingScreenAwake = true
    private var currentAccount = ""

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.nextcloud.timerProcess", qos: .utility)
    private var lastUsedInterval: TimeInterval = 3
    private let maxInterval: TimeInterval = 3
    private let minInterval: TimeInterval = 1.5

    private init() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayerIsPlaying), object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            Task {
                await self.setScreenAwake(false)
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayerStoppedPlaying), object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            Task {
                await self.setScreenAwake(true)
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            Task {
                await self.stopTimer()
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            Task {
                await self.startTimer(interval: self.maxInterval)
            }
        }
    }

    private func setScreenAwake(_ enabled: Bool) {
        enableControllingScreenAwake = enabled
    }

    func setCurrentAccount(_ account: String) {
        currentAccount = account
    }

    func startTimer(interval: TimeInterval) async {
        let isActive = await MainActor.run {
            UIApplication.shared.applicationState == .active
        }
        guard isActive else {
            return
        }

        await stopTimer()

        lastUsedInterval = interval
        let newTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        newTimer.schedule(deadline: .now() + interval, repeating: interval)

        newTimer.setEventHandler { [weak self] in
            guard let self else { return }
            Task {
                await self.handleTimerTick()
            }
        }

        timer = newTimer
        newTimer.resume()
    }

    func stopTimer() async {
        timer?.cancel()
        timer = nil
    }

    private func handleTimerTick() async {
        if currentTask != nil {
            print("[NKLOG] current task is running")
            return
        }

        currentTask = Task {
            defer {
                currentTask = nil
            }

            guard networking.isOnline,
                  !currentAccount.isEmpty,
                  networking.noServerErrorAccount(currentAccount)
            else {
                return
            }

            let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "status != %d", self.global.metadataStatusNormal))
            if !metadatas.isEmpty {
                let tasks = await networking.getAllDataTask()
                let hasSyncTask = tasks.contains { $0.taskDescription == global.taskDescriptionSynchronization }
                let resultsScreenAwake = metadatas.filter { global.metadataStatusForScreenAwake.contains($0.status) }

                if enableControllingScreenAwake {
                    ScreenAwakeManager.shared.mode = resultsScreenAwake.isEmpty && !hasSyncTask ? .off : NCPreferences().screenAwakeMode
                }

                await runMetadataPipelineAsync()

                if lastUsedInterval != minInterval {
                    await startTimer(interval: minInterval)
                }
            } else {
                await removeUploadedAssetsIfNeeded()
                if lastUsedInterval != maxInterval {
                    await startTimer(interval: maxInterval)
                }
            }
        }
    }

    private func removeUploadedAssetsIfNeeded() async {
        guard NCPreferences().removePhotoCameraRoll,
              let localIdentifiers = await self.database.getAssetLocalIdentifiersUploadedAsync(),
              !localIdentifiers.isEmpty else {
            return
        }

         _ = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(
                    PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil) as NSFastEnumeration
                )
            }, completionHandler: { completed, _ in
                continuation.resume(returning: completed)
            })
        }

        await self.database.clearAssetLocalIdentifiersAsync(localIdentifiers)
    }

    private func runMetadataPipelineAsync() async {
        let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "status != %d", self.global.metadataStatusNormal))
        guard !metadatas.isEmpty else {
            return
        }

        /// ------------------------ WEBDAV
        let waitWebDav = metadatas.filter { self.global.metadataStatusWaitWebDav.contains($0.status) }
        if !waitWebDav.isEmpty {
            let (status, error) = await metadataStatusWaitWebDav(metadatas: Array(waitWebDav))
            if  (error == .cancelled) || (status == global.metadataStatusWaitDelete && error != .success) {
                return
            }
        }

        /// ------------------------ DOWNLOAD
        let httpMaximumConnectionsPerHostInDownload = NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload
        var counterDownloading = metadatas.filter { $0.status == self.global.metadataStatusDownloading }.count
        let limitDownload = max(0, httpMaximumConnectionsPerHostInDownload - counterDownloading)

        let filteredDownload = metadatas
            .filter { $0.session == self.networking.sessionDownloadBackground && $0.status == NCGlobal.shared.metadataStatusWaitDownload }
            .sorted { ($0.sessionDate ?? Date.distantFuture) < ($1.sessionDate ?? Date.distantFuture) }
            .prefix(limitDownload)
        let metadatasWaitDownload = Array(filteredDownload)

        for metadata in metadatasWaitDownload where counterDownloading < httpMaximumConnectionsPerHostInDownload {
            counterDownloading += 1
            await networking.downloadFileInBackground(metadata: metadata)
        }

        /// ------------------------ UPLOAD

        /// CHUNK or  E2EE - only one for time
        let hasUploadingMetadataWithChunksOrE2EE = metadatas.filter { $0.status == NCGlobal.shared.metadataStatusUploading && ($0.chunk > 0 || $0.e2eEncrypted == true) }
        if !hasUploadingMetadataWithChunksOrE2EE.isEmpty {
            return
        }

        var httpMaximumConnectionsPerHostInUpload = NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload
        let isWiFi = self.networking.networkReachability == NKTypeReachability.reachableEthernetOrWiFi
        let sessionUploadSelectors = [self.global.selectorUploadFileNODelete, self.global.selectorUploadFile, self.global.selectorUploadAutoUpload]
        var counterUploading = metadatas.filter { $0.status == self.global.metadataStatusUploading }.count
        for sessionSelector in sessionUploadSelectors {
            guard counterUploading < httpMaximumConnectionsPerHostInUpload else { return }

            let limitUpload = max(0, httpMaximumConnectionsPerHostInUpload - counterUploading)
            let filteredUpload = metadatas
                .filter { $0.sessionSelector == sessionSelector && $0.status == NCGlobal.shared.metadataStatusWaitUpload }
                .sorted { ($0.sessionDate ?? Date.distantFuture) < ($1.sessionDate ?? Date.distantFuture) }
                .prefix(limitUpload)
            let metadatasWaitUpload = Array(filteredUpload)

            if !metadatasWaitUpload.isEmpty {
                nkLog(debug: "PROCESS (UPLOAD) find \(metadatasWaitUpload.count) items")
            }

            for metadata in metadatasWaitUpload {
                guard counterUploading < httpMaximumConnectionsPerHostInUpload else { return }
                let metadatas = await NCCameraRoll().extractCameraRoll(from: metadata)

                // no extract photo
                if metadatas.isEmpty {
                    await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                }

                for metadata in metadatas {
                    guard counterUploading < httpMaximumConnectionsPerHostInUpload,
                          timer != nil else { return }

                    /// NO WiFi
                    if !isWiFi && metadata.session == networking.sessionUploadBackgroundWWan { continue }

                    await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                status: global.metadataStatusUploading)

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

                    if metadata.isDirectoryE2EE {
                        await NCNetworkingE2EEUpload().upload(metadata: metadata, controller: controller)

                        httpMaximumConnectionsPerHostInUpload = 1
                    } else if metadata.chunk > 0 {
                        let controller = controller

                        Task { @MainActor in
                            var numChunks = 0
                            var counterUpload: Int = 0
                            let hud = NCHud(controller?.view)
                            hud.pieProgress(text: NSLocalizedString("_wait_file_preparation_", comment: ""))

                            await NCNetworking.shared.uploadChunkFile(metadata: metadata) { num in
                                numChunks = num
                            } counterChunk: { counter in
                                hud.progress(num: Float(counter), total: Float(numChunks))
                            } startFilesChunk: { _ in
                                hud.setText(NSLocalizedString("_keep_active_for_upload_", comment: ""))
                            } requestHandler: { _ in
                                hud.progress(num: Float(counterUpload), total: Float(numChunks))
                                counterUpload += 1
                            } assembling: {
                                hud.setText(NSLocalizedString("_wait_", comment: ""))
                            }

                            hud.dismiss()
                        }

                        httpMaximumConnectionsPerHostInUpload = 1
                    } else {
                        await networking.uploadFileInBackground(metadata: metadata)
                    }
                    counterUploading += 1
                }
            }
        }

        /// No upload available ? --> Retry Upload in Error
        ///
        let uploadError = metadatas.filter { $0.status == self.global.metadataStatusUploadError }
        if counterUploading == 0 {
            for metadata in uploadError {
                /// Check QUOTA
                if metadata.sessionError.contains("\(global.errorQuota)") {
                    let results = await NextcloudKit.shared.getUserMetadataAsync(account: metadata.account, userId: metadata.userId)
                    if results.error == .success, let userProfile = results.userProfile, userProfile.quotaFree > 0, userProfile.quotaFree > metadata.size {
                        await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                    session: self.networking.sessionUploadBackground,
                                                                    sessionError: "",
                                                                    status: self.global.metadataStatusWaitUpload)
                    }
                } else {
                    await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                session: self.networking.sessionUploadBackground,
                                                                sessionError: "",
                                                                status: global.metadataStatusWaitUpload)
                }
            }
        }

        return
    }

    private func metadataStatusWaitWebDav(metadatas: [tableMetadata]) async -> (status: Int?, error: NKError) {
        let networking = NCNetworking.shared

        /// ------------------------ CREATE FOLDER
        ///
        let metadatasWaitCreateFolder = metadatas.filter { $0.status == global.metadataStatusWaitCreateFolder }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in metadatasWaitCreateFolder {
            guard timer != nil else {
                return (global.metadataStatusWaitCreateFolder, .cancelled)
            }

            let resultsCreateFolder = await networking.createFolder(fileName: metadata.fileName,
                                                                    serverUrl: metadata.serverUrl,
                                                                    overwrite: true,
                                                                    session: NCSession.shared.getSession(account: metadata.account),
                                                                    selector: metadata.sessionSelector)
            if let sceneIdentifier = metadata.sceneIdentifier {
                await networking.transferDispatcher.notifyDelegates(forScene: sceneIdentifier) { delegate in
                    delegate.transferChange(status: self.global.networkingStatusCreateFolder,
                                            metadata: metadata,
                                            error: resultsCreateFolder.error)
                } others: { delegate in
                    delegate.transferReloadData(serverUrl: metadata.serverUrl, status: nil)
                }
            } else {
                await networking.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusCreateFolder,
                                            metadata: metadata,
                                            error: resultsCreateFolder.error)
                }
            }

            if resultsCreateFolder.error != .success {
                return (global.metadataStatusWaitCreateFolder, resultsCreateFolder.error)
            }
        }

        /// ------------------------ COPY
        ///
        let metadatasWaitCopy = metadatas.filter { $0.status == global.metadataStatusWaitCopy }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in metadatasWaitCopy {
            guard timer != nil else {
                return (global.metadataStatusWaitCopy, .cancelled)
            }

            let destination = metadata.destination
            var serverUrlFileNameDestination = destination + "/" + metadata.fileName
            let overwrite = (metadata.storeFlag as? NSString)?.boolValue ?? false

            /// Within same folder
            if metadata.serverUrl == destination {
                let fileNameCopy = await NCNetworking.shared.createFileName(fileNameBase: metadata.fileName, account: metadata.account, serverUrl: metadata.serverUrl)
                serverUrlFileNameDestination = destination + "/" + fileNameCopy
            }

            let resultCopy = await NextcloudKit.shared.copyFileOrFolderAsync(serverUrlFileNameSource: metadata.serverUrlFileName, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account)

            await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                        status: global.metadataStatusNormal)

            if resultCopy.error == .success {
                let result = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrlFileNameDestination, account: metadata.account)
                if result.error == .success, let metadata = result.metadata {
                    await self.database.addMetadataAsync(metadata)
                }
            }

            await networking.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferCopy(metadata: metadata, destination: destination, error: resultCopy.error)
            }

            if resultCopy.error != .success {
                return (global.metadataStatusWaitCopy, resultCopy.error)
            }
        }

        /// ------------------------ MOVE
        ///
        let metadatasWaitMove = metadatas.filter { $0.status == global.metadataStatusWaitMove }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in metadatasWaitMove {
            guard timer != nil else {
                return (global.metadataStatusWaitMove, .cancelled)
            }

            let destination = metadata.destination
            let serverUrlFileNameDestination = destination + "/" + metadata.fileName
            let overwrite = (metadata.storeFlag as? NSString)?.boolValue ?? false

            let resultMove = await NextcloudKit.shared.moveFileOrFolderAsync(serverUrlFileNameSource: metadata.serverUrlFileName, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account)

            await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                        status: global.metadataStatusNormal)

            if resultMove.error == .success {
                let result = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrlFileNameDestination, account: metadata.account)
                if result.error == .success, let metadata = result.metadata {
                    // Remove directory
                    if metadata.directory {
                        let serverUrl = utilityFileSystem.navigateServerPathDown(serverUrl: metadata.serverUrl, fileNameFolder: metadata.fileName)
                        await self.database.deleteDirectoryAndSubDirectoryAsync(serverUrl: serverUrl,
                                                                                account: result.account)
                    }
                    await self.database.addMetadataAsync(metadata)
                }
            }

            await networking.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferMove(metadata: metadata, destination: destination, error: resultMove.error)
            }

            if resultMove.error != .success {
                return (global.metadataStatusWaitMove, resultMove.error)
            }
        }

        /// ------------------------ FAVORITE
        ///
        let metadatasWaitFavorite = metadatas.filter { $0.status == global.metadataStatusWaitFavorite }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in metadatasWaitFavorite {
            guard timer != nil else {
                return (global.metadataStatusWaitFavorite, .cancelled)
            }

            let session = NCSession.Session(account: metadata.account, urlBase: metadata.urlBase, user: metadata.user, userId: metadata.userId)
            let fileName = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)
            let resultsFavorite = await NextcloudKit.shared.setFavoriteAsync(fileName: fileName, favorite: metadata.favorite, account: metadata.account)

            if resultsFavorite.error == .success {
                await self.database.setMetadataFavoriteAsync(ocId: metadata.ocId,
                                                             favorite: nil,
                                                             saveOldFavorite: nil,
                                                             status: global.metadataStatusNormal)
            } else {
                let favorite = (metadata.storeFlag as? NSString)?.boolValue ?? false
                await self.database.setMetadataFavoriteAsync(ocId: metadata.ocId,
                                                             favorite: favorite,
                                                             saveOldFavorite: nil,
                                                             status: global.metadataStatusNormal)
            }

            await networking.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusFavorite,
                                        metadata: metadata,
                                        error: resultsFavorite.error)
            }

            if resultsFavorite.error != .success {
                return (global.metadataStatusWaitFavorite, resultsFavorite.error)
            }
        }

        /// ------------------------ RENAME
        ///
        let metadatasWaitRename = metadatas.filter { $0.status == global.metadataStatusWaitRename }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in metadatasWaitRename {
            guard timer != nil else {
                return (global.metadataStatusWaitRename, .cancelled)
            }

            let serverUrlFileNameSource = metadata.serverUrlFileName
            let serverUrlFileNameDestination = metadata.serverUrl + "/" + metadata.fileName
            let resultRename = await NextcloudKit.shared.moveFileOrFolderAsync(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: false, account: metadata.account)

            if resultRename.error == .success {
                await self.database.setMetadataServerUrlFileNameStatusNormalAsync(ocId: metadata.ocId)
            } else {
                await self.database.restoreMetadataFileNameAsync(ocId: metadata.ocId)
            }

            await networking.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferChange(status: NCGlobal.shared.networkingStatusRename,
                                        metadata: metadata,
                                        error: resultRename.error)
            }

            if resultRename.error != .success {
                return (global.metadataStatusWaitRename, resultRename.error)
            }
        }

        /// ------------------------ DELETE
        ///
        let metadatasWaitDelete = metadatas.filter { $0.status == global.metadataStatusWaitDelete }.sorted { $0.serverUrl < $1.serverUrl }
        if !metadatasWaitDelete.isEmpty {
            var metadatasError: [tableMetadata: NKError] = [:]
            var returnError = NKError()

            for metadata in metadatasWaitDelete {
                guard timer != nil else {
                    return (global.metadataStatusWaitDelete, .cancelled)
                }

                let resultDelete = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account)

                await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                            status: global.metadataStatusNormal)

                if resultDelete.error == .success || resultDelete.error.errorCode == NCGlobal.shared.errorResourceNotFound {
                    do {
                        try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                    } catch { }

                    NCImageCache.shared.removeImageCache(ocIdPlusEtag: metadata.ocId + metadata.etag)

                    await self.database.deleteVideoAsync(metadata.ocId)
                    await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                    await self.database.deleteLocalFileOcIdAsync(metadata.ocId)

                    if metadata.directory {
                        let serverUrl = NCUtilityFileSystem().navigateServerPathDown(serverUrl: metadata.serverUrl, fileNameFolder: metadata.fileName)
                        await self.database.deleteDirectoryAndSubDirectoryAsync(serverUrl: serverUrl,
                                                                                account: metadata.account)
                    }

                    metadatasError[metadata] = .success
                } else {
                    metadatasError[metadata] = resultDelete.error
                    returnError = resultDelete.error
                }
            }

            await networking.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusDelete,
                                        metadatasError: metadatasError)
            }

            if returnError != .success {
                return (global.metadataStatusWaitDelete, returnError)
            }
        }

        return (nil, .success)
    }
}
