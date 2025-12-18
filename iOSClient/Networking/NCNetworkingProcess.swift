// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Photos
import RealmSwift
import Alamofire
import LucidBanner

actor NCNetworkingProcess {
    static let shared = NCNetworkingProcess()

    private let utilityFileSystem = NCUtilityFileSystem()
    private let utility = NCUtility()
    private let global = NCGlobal.shared
    private let networking = NCNetworking.shared

    private var currentTask: Task<Void, Never>?

    @MainActor
    private var currentUploadTask: Task<(account: String, file: NKFile?, error: NKError), Never>?

    @MainActor
    private var currentUploadRequest: UploadRequest?

    private var enableControllingScreenAwake = true
    private var currentAccount = ""
    private var inWaitingCount: Int = 0

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.nextcloud.timerProcess", qos: .utility)
    private var lastUsedInterval: TimeInterval = 3.5
    private let maxInterval: TimeInterval = 3.5
    private let minInterval: TimeInterval = 2.5

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
                await self.cancelCurrentTaskOnBackground()
                await self.cancelCurrentUpload()
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
        UIApplication.shared.mainAppWindow?.rootViewController as? NCMainTabBarController
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

    private func inWaitingCount() async -> Int {
        let countTransferSuccess = await NCNetworking.shared.metadataTranfersSuccess.count()
        let totalNonNormal = await NCManageDatabase.shared.getMetadatasInWaitingCountAsync()
        let count = max(0, totalNonNormal - countTransferSuccess)

        return count
    }

    func getInWaitingCount() async -> Int {
        return inWaitingCount
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

    private func cancelCurrentTaskOnBackground() {
        currentTask?.cancel()
        currentTask = nil
    }

    @MainActor
    private func cancelCurrentUpload() async {
        self.currentUploadTask?.cancel()
        self.currentUploadRequest?.cancel()
        self.currentUploadTask = nil
        self.currentUploadRequest = nil
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

            if Task.isCancelled {
                return
            }

            guard networking.isOnline,
                  !currentAccount.isEmpty,
                  networking.noServerErrorAccount(currentAccount)
            else {
                return
            }

            // UPDATE INWAIT & BADGE
            //
            let count = await inWaitingCount()
            if count != inWaitingCount {
                inWaitingCount = count
                Task { @MainActor in
                    UNUserNotificationCenter.current().setBadgeCount(count)

                    if let controller = getRootController(),
                       let files = controller.tabBar.items?.first {
                            files.badgeValue = count == 0 ? nil : self.utility.formatBadgeCount(count)
                    }
                }
            }

            // METADATAS
            //
            let metadatas = await NCManageDatabase.shared.getMetadataProcess()

            // TRANSFERS SUCCESS
            //
            let countWaitUpload = metadatas.filter { $0.status == self.global.metadataStatusWaitUpload }.count
            let countProgress = metadatas.filter { global.metadatasStatusInProgress.contains($0.status) }.count
            let countTransferSuccess = await NCNetworking.shared.metadataTranfersSuccess.count()
            if (countWaitUpload == 0 && countTransferSuccess > 0) || countTransferSuccess >= NCBrandOptions.shared.numMaximumProcess {
                await NCNetworking.shared.metadataTranfersSuccess.flush()
            }

            // ZOMBIE
            //
            if countWaitUpload == 0, countProgress > 0 {
                await NCNetworking.shared.verifyZombie()
            }

            if !metadatas.isEmpty {
                let tasks = await networking.getAllDataTask()
                let hasSyncTask = tasks.contains { $0.taskDescription == global.taskDescriptionSynchronization }
                let resultsScreenAwake = metadatas.filter { global.metadataStatusForScreenAwake.contains($0.status) }

                if enableControllingScreenAwake {
                    ScreenAwakeManager.shared.mode = resultsScreenAwake.isEmpty && !hasSyncTask ? .off : NCPreferences().screenAwakeMode
                }

                if Task.isCancelled {
                    return
                }

                await runMetadataPipelineAsync(metadatas: metadatas)

                // TODO: Check temperature

                if lastUsedInterval != minInterval {
                    await startTimer(interval: minInterval)
                }
            } else {
                // Remove upload asset
                await removeUploadedAssetsIfNeeded()

                // Set Live Photo
                await NCNetworking.shared.setLivePhoto(account: currentAccount)

                if lastUsedInterval != maxInterval {
                    await startTimer(interval: maxInterval)
                }
            }
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
        guard availableProcess > 0, timer != nil else {
            return
        }

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
        guard availableProcess > 0, timer != nil else {
            return
        }

        // UPLOAD IN ERROR (check > 5 minute ago)
        //
        for metadata in metadatas where metadata.status == self.global.metadataStatusUploadError && (metadata.sessionDate ?? .distantFuture) < Date().addingTimeInterval(-300) {
            await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                  session: self.networking.sessionUploadBackground,
                                                                  sessionError: "",
                                                                  status: global.metadataStatusWaitUpload)
        }

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
            // extract image/video
            let extractMetadatas = await NCCameraRoll().extractCameraRoll(from: metadata)
            guard timer != nil else { return }
            // no extract photo
            if extractMetadatas.isEmpty {
                await database.deleteMetadataAsync(id: metadata.ocId)
            }
            // upload file(s)
            for metadata in extractMetadatas {
                guard timer != nil,
                      !isAppInBackground else {
                    return
                }

                // IS TRANSFER SUCCESS
                //
                if await NCNetworking.shared.metadataTranfersSuccess.exists(serverUrlFileName: metadata.serverUrlFileName) {
                    // File exists
                    continue
                }

                // AUTO-UPLOAD: CHECK FILE EXISTS
                if metadata.sessionSelector == global.selectorUploadAutoUpload {
                    let existsResult = await networking.fileExists(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account)
                    if existsResult == .success {
                        // File exists → delete from local metadata and skip
                        await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                        continue
                    } else if existsResult.errorCode == 404 {
                        // 404 Not Found → file does not exist
                        // Proceed
                    } else {
                        // Any other error (423 locked, 401 auth, 403 forbidden, 5xx, etc.)
                        continue
                    }
                }

                // UPLOAD E2EE
                //
                if metadata.isDirectoryE2EE {
                    let controller = await getController(account: metadata.account, sceneIdentifier: metadata.sceneIdentifier)
                    let scene = await SceneManager.shared.getWindow(sceneIdentifier: metadata.sceneIdentifier)?.windowScene

                    let token = await showUploadBanner(scene: scene,
                                                       blocksTouches: true,
                                                       onButtonTap: {
                        Task {
                            await self.cancelCurrentUpload()
                        }
                    })

                    await NCNetworkingE2EEUpload().upload(metadata: metadata,
                                                          controller: controller,
                                                          stageBanner: .button,
                                                          tokenBanner: token) { uploadRequest in
                        Task {@MainActor in
                            self.currentUploadRequest = uploadRequest
                        }
                    } currentUploadTask: { task in
                        Task {@MainActor in
                            self.currentUploadTask = task
                        }
                    }

                    // wait dismiss banner before open another (loop)
                    await LucidBanner.shared.dismissAsync()

                // UPLOAD CHUNK
                //
                } else if metadata.chunk > 0 {
                    await uploadChunk(metadata: metadata)
                // UPLOAD IN BACKGROUND
                //
                } else {
                    await networking.uploadFileInBackground(metadata: metadata)
                }

                availableProcess -= 1
            }
        }
    }

    // MARK: - Upload in chunk mode

    @MainActor
    func uploadChunk(metadata: tableMetadata) async {
        var tokenBanner: Int?
        let scene = SceneManager.shared.getWindow(sceneIdentifier: metadata.sceneIdentifier)?.windowScene

        tokenBanner = showUploadBanner(scene: scene,
                                       vPosition: .bottom,
                                       verticalMargin: 55,
                                       draggable: true,
                                       stage: .button,
                                       allowMinimizeOnTap: true,
                                       onButtonTap: {
            Task {
                await self.cancelCurrentUpload()
                LucidBanner.shared.dismiss()
            }
        })

        LucidBanner.shared.update(title: NSLocalizedString("_wait_file_preparation_", comment: ""),
                                  subtitle: NSLocalizedString("_large_upload_tip_", comment: ""),
                                  footnote: "( " + NSLocalizedString("_tap_to_min_max_", comment: "") + " )",
                                  systemImage: "gearshape.arrow.triangle.2.circlepath",
                                  imageAnimation: .rotate)

        let task = Task { () -> (account: String, file: NKFile?, error: NKError) in
            let results = await NCNetworking.shared.uploadChunkFile(metadata: metadata) { total, counter in
                Task {@MainActor in
                    let progress = Double(counter) / Double(total)
                    LucidBanner.shared.update(progress: progress, for: tokenBanner)
                }
            } uploadStart: { _ in
                Task {@MainActor in
                    LucidBanner.shared.update(
                        title: NSLocalizedString("_keep_active_for_upload_", comment: ""),
                        systemImage: "arrowshape.up.circle",
                        imageAnimation: .breathe,
                        progress: 0,
                        for: tokenBanner)
                }
            } uploadProgressHandler: { _, _, progress in
                Task {@MainActor in
                    LucidBanner.shared.update(progress: progress, for: tokenBanner)
                }
            } assembling: {
                Task {@MainActor in
                    LucidBanner.shared.update(
                        title: NSLocalizedString("_finalizing_wait_", comment: ""),
                        systemImage: "gearshape.arrow.triangle.2.circlepath",
                        imageAnimation: .rotate,
                        progress: 0,
                        stage: .placeholder,
                        for: tokenBanner)
                }
            }

            return results
        }

        currentUploadTask = task
        _ = await task.value

        LucidBanner.shared.dismiss()
    }

    // MARK: - Helper

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
