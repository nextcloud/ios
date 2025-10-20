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
    private let utility = NCUtility()
    private let global = NCGlobal.shared
    private let networking = NCNetworking.shared

    private var currentTask: Task<Void, Never>?
    private var enableControllingScreenAwake = true
    private var currentAccount = ""

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.nextcloud.timerProcess", qos: .utility)
    private var lastUsedInterval: TimeInterval = 4
    private let maxInterval: TimeInterval = 4
    private let minInterval: TimeInterval = 2

    private let sessionForUpload = [NextcloudKit.shared.nkCommonInstance.identifierSessionUpload,
                                    NextcloudKit.shared.nkCommonInstance.identifierSessionUploadBackground,
                                    NextcloudKit.shared.nkCommonInstance.identifierSessionUploadBackgroundWWan]

    private init() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayerIsPlaying), object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            Task { @MainActor in
                await self.setScreenAwake(false)
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayerStoppedPlaying), object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            Task { @MainActor in
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

    @MainActor
    private func getRootController() -> NCMainTabBarController? {
        UIApplication.shared.firstWindow?.rootViewController as? NCMainTabBarController
    }

    @MainActor
    private func getController(account: String, sceneIdentifier: String?) async -> NCMainTabBarController? {
        /// find controller
        var controller: NCMainTabBarController?
        if let sceneIdentifier = sceneIdentifier,
           !sceneIdentifier.isEmpty {
            controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier)
        }

        if controller == nil {
            for ctlr in SceneManager.shared.getControllers() {
                let account = ctlr.account
                if account == account {
                    controller = ctlr
                }
            }
        }

        if controller == nil {
            controller = getRootController()
        }

        return controller
    }

    private func setScreenAwake(_ enabled: Bool) {
        enableControllingScreenAwake = enabled
    }

    func setCurrentAccount(_ account: String) {
        currentAccount = account
    }

    /// Updates the app and tab bar badges to reflect active or pending transfers.
    ///
    /// Calculates the number of transfers still in progress or failed by subtracting
    /// the completed transfer count from all non-normal metadata records, then updates
    /// both the app icon badge and the Files tab badge accordingly.
    @MainActor
    private func countBadge() async {
        let countTransferSuccess = await NCNetworking.shared.metadataTranfersSuccess.count()
        let count = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "status != %i", self.global.metadataStatusNormal)).count - countTransferSuccess
        try? await UNUserNotificationCenter.current().setBadgeCount(count)
        if let controller = getRootController(),
           let files = controller.tabBar.items?.first {
            files.badgeValue = count == 0 ? nil : self.utility.formatBadgeCount(count)
        }
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

    private func stopTimer() async {
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
            // METADATAS TABLE
            //
            let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "status != %d", self.global.metadataStatusNormal), withLimit: NCBrandOptions.shared.numMaximumProcess * 3) ?? []

            // TRANSFERS SUCCESS
            //
            let countWaitUpload = metadatas.filter { $0.status == self.global.metadataStatusWaitUpload }.count
            let countTransferSuccess = await NCNetworking.shared.metadataTranfersSuccess.count()
            if (countWaitUpload == 0 && countTransferSuccess > 0) || countTransferSuccess >= NCBrandOptions.shared.numMaximumProcess {
                await NCNetworking.shared.metadataTranfersSuccess.flush()
            }

            if !metadatas.isEmpty {
                let tasks = await networking.getAllDataTask()
                let hasSyncTask = tasks.contains { $0.taskDescription == global.taskDescriptionSynchronization }
                let resultsScreenAwake = metadatas.filter { global.metadataStatusForScreenAwake.contains($0.status) }

                if enableControllingScreenAwake {
                    ScreenAwakeManager.shared.mode = resultsScreenAwake.isEmpty && !hasSyncTask ? .off : NCPreferences().screenAwakeMode
                }

                await runMetadataPipelineAsync(metadatas: metadatas)

                // TODO: Check temperature

                if lastUsedInterval != minInterval {
                    await startTimer(interval: minInterval)
                }
            } else {
                // Remove upload asset
                await removeUploadedAssetsIfNeeded()

                if lastUsedInterval != maxInterval {
                    await startTimer(interval: maxInterval)
                }
            }

            await countBadge()
        }
    }

    private func removeUploadedAssetsIfNeeded() async {
        guard NCPreferences().removePhotoCameraRoll,
              let localIdentifiers = await NCManageDatabase.shared.getAssetLocalIdentifiersUploadedAsync(),
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

        await NCManageDatabase.shared.clearAssetLocalIdentifiersAsync(localIdentifiers)
    }

    private func runMetadataPipelineAsync(metadatas: [tableMetadata]) async {
        let database = NCManageDatabase.shared
        let countTransferSuccess = await NCNetworking.shared.metadataTranfersSuccess.count()
        let countDownloading = metadatas.filter { $0.status == self.global.metadataStatusDownloading }.count
        let countUploading = metadatas.filter { $0.status == self.global.metadataStatusUploading }.count - countTransferSuccess
        var availableProcess = NCBrandOptions.shared.numMaximumProcess - (countDownloading + countUploading)
        let isWiFi = self.networking.networkReachability == NKTypeReachability.reachableEthernetOrWiFi

        // WEBDAV
        //
        let waitWebDav = metadatas.filter { self.global.metadataStatusWaitWebDav.contains($0.status) }
        if !waitWebDav.isEmpty {
            let error = await hubProcessWebDav(metadatas: Array(waitWebDav))
            guard error == .success else {
                return
            }
        }

        // TEST AVAILABLE PROCESS
        guard availableProcess > 0, timer != nil else { return }

        // DOWNLOAD
        //
        let filteredDownload = metadatas
            .filter { $0.session == self.networking.sessionDownloadBackground && $0.status == NCGlobal.shared.metadataStatusWaitDownload }
            .sorted { ($0.sessionDate ?? Date.distantFuture) < ($1.sessionDate ?? Date.distantFuture) }
            .prefix(availableProcess)
        let metadatasWaitDownload = Array(filteredDownload)

        for metadata in metadatasWaitDownload {
            availableProcess -= 1
            if !isAppInBackground {
                await networking.downloadFileInBackground(metadata: metadata)
            }
        }

        // TEST AVAILABLE PROCESS
        guard availableProcess > 0, timer != nil else { return }

        // UPLOAD
        //
        let metadatasWaitUpload = Array(metadatas
            .filter {
                sessionForUpload.contains($0.session) &&
                $0.status == NCGlobal.shared.metadataStatusWaitUpload
            }
            .sorted { // Earlier dates first; nils go to the end
                ($0.sessionDate ?? .distantFuture) < ($1.sessionDate ?? .distantFuture)
            }
            .prefix(availableProcess))

        for metadata in metadatasWaitUpload {
            guard availableProcess > 0, timer != nil else { return }
            // WiFi check
            if !isWiFi && metadata.session == networking.sessionUploadBackgroundWWan {
                continue
            }
            // File exists ? skip it
            let error = await networking.fileExists(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account)
            if error == .success {
                await database.deleteMetadataAsync(id: metadata.ocId)
                continue
            }
            // extract image/video
            let extractMetadatas = await NCCameraRoll().extractCameraRoll(from: metadata)
            guard timer != nil else { return }
            // no extract photo
            if extractMetadatas.isEmpty {
                await database.deleteMetadataAsync(id: metadata.ocId)
            }
            // upload file(s)
            for metadata in extractMetadatas {
                guard timer != nil else { return }
                // UPLOAD E2EE
                //
                if metadata.isDirectoryE2EE {
                    let controller = await getController(account: metadata.account, sceneIdentifier: metadata.sceneIdentifier)
                    await NCNetworkingE2EEUpload().upload(metadata: metadata, controller: controller)
                // UPLOAD CHUNK
                //
                } else if metadata.chunk > 0 {
                    let controller = await getController(account: metadata.account, sceneIdentifier: metadata.sceneIdentifier)
                    let hud = await NCHud(controller?.view)
                    await networking.uploadChunk(metadata: metadata, hud: hud)
                // UPLOAD IN BACKGROUND
                //
                } else {
                    if !isAppInBackground {
                        await networking.uploadFileInBackground(metadata: metadata)
                    }
                }
                availableProcess -= 1
            }
        }

        /// No upload available ? --> Retry Upload in Error
        ///
        let uploadError = metadatas.filter { $0.status == self.global.metadataStatusUploadError }
        if countUploading == 0 {
            for metadata in uploadError {
                /// Check QUOTA
                if metadata.sessionError.contains("\(global.errorQuota)") {
                    let results = await NextcloudKit.shared.getUserMetadataAsync(account: metadata.account, userId: metadata.userId) { task in
                        Task {
                            let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                                        path: metadata.userId,
                                                                                                        name: "getUserMetadata")
                            await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                        }
                    }
                    if results.error == .success, let userProfile = results.userProfile, userProfile.quotaFree > 0, userProfile.quotaFree > metadata.size {
                        await database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                               session: self.networking.sessionUploadBackground,
                                                               sessionError: "",
                                                               status: self.global.metadataStatusWaitUpload)
                    }
                } else {
                    await database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                           session: self.networking.sessionUploadBackground,
                                                           sessionError: "",
                                                           status: global.metadataStatusWaitUpload)
                }
            }
        }

        return
    }

    // MARK: - Hub Process WebDav

    private func hubProcessWebDav(metadatas: [tableMetadata]) async -> NKError {
        var results: [tableMetadata] = []

        // CREATE FOLDER
        //
        results = metadatas.filter { $0.status == global.metadataStatusWaitCreateFolder }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in results {
            let error = await networking.createFolder(metadata: metadata)
            guard error == .success, timer != nil else {
                return .cancelled
            }
        }

        // COPY
        //
        results = metadatas.filter { $0.status == global.metadataStatusWaitCopy }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in results {
            let error = await networking.copyFileOrFolder(metadata: metadata)
            guard error == .success, timer != nil else {
                return .cancelled
            }
        }

        // MOVE
        //
        results = metadatas.filter { $0.status == global.metadataStatusWaitMove }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in results {
            let error = await networking.moveFileOrFolder(metadata: metadata)
            guard error == .success, timer != nil else {
                return .cancelled
            }
        }

        // FAVORITE
        //
        results = metadatas.filter { $0.status == global.metadataStatusWaitFavorite }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in results {
            let error = await networking.setFavorite(metadata: metadata)
            guard error == .success, timer != nil else {
                return .cancelled
            }
        }

        // RENAME
        //
        results = metadatas.filter { $0.status == global.metadataStatusWaitRename }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in results {
            let error = await networking.renameFileOrFolder(metadata: metadata)
            guard error == .success else { return error }
        }

        // DELETE
        //
        results = metadatas.filter { $0.status == global.metadataStatusWaitDelete }.sorted { $0.serverUrl < $1.serverUrl }
        for metadata in results {
            let error = await networking.deleteFileOrFolder(metadata: metadata)
            guard error == .success, timer != nil else {
                return .cancelled
            }
        }

        return .success
    }

}
