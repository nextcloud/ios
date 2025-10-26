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
    private var inWaitingCount: Int = 0

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.nextcloud.timerProcess", qos: .utility)
    private var lastUsedInterval: TimeInterval = 3
    private let maxInterval: TimeInterval = 3
    private let minInterval: TimeInterval = 1.5

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
            // File exists for Auto Upload? skip it
            if metadata.sessionSelector == global.selectorUploadAutoUpload {
                let error = await networking.fileExists(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account)
                if error == .success {
                    await database.deleteMetadataAsync(id: metadata.ocId)
                    continue
                }
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
                guard timer != nil, !isAppInBackground else { return }

                // UPLOAD E2EE
                //
                if metadata.isDirectoryE2EE {
                    let controller = await getController(account: metadata.account, sceneIdentifier: metadata.sceneIdentifier)
                    await NCNetworkingE2EEUpload().upload(metadata: metadata, controller: controller)

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
        var numChunks = 0
        var countUpload: Int = 0

        let token = LucidBanner.shared.show(
            title: NSLocalizedString("_wait_file_preparation_", comment: ""),
            subtitle: NSLocalizedString("_large_upload_tip_", comment: ""),
            textColor: .label,
            systemImage: "gearshape.arrow.triangle.2.circlepath",
            imageColor: NCBrandColor.shared.customer,
            imageAnimation: .rotate,
            progressColor: NCBrandColor.shared.customer,
            blocksTouches: false,
            onTapWithContext: { token, revision, stage in
                print("tap on banner")
            }) { state in
                ToastBannerView(state: state)
            }

        await NCNetworking.shared.uploadChunkFile(metadata: metadata) { num in
            numChunks = num
        } counterChunk: { counter in
            Task { @MainActor in
                let progress = Double(counter) / Double(numChunks)
                LucidBanner.shared.update(
                    progress: progress,
                    onTapWithContext: { token, revision, stage in

                }, for: token)
            }
        } startFilesChunk: { _ in
            Task {
                LucidBanner.shared.update(
                    title: NSLocalizedString("_keep_active_for_upload_", comment: ""),
                    systemImage: "arrowshape.up.circle",
                    imageAnimation: .breathe,
                    progress: 0,
                    onTapWithContext: { token, revision, stage in

                }, for: token)
            }
        } requestHandler: { _ in
            Task {
                let progress = Double(countUpload) / Double(numChunks)
                LucidBanner.shared.update(
                    progress: progress,
                    onTapWithContext: { token, revision, stage in

                }, for: token)
                countUpload += 1
            }
        } assembling: {
            Task {
                LucidBanner.shared.update(title: NSLocalizedString("_wait_", comment: ""),
                                          systemImage: "tray.and.arrow.down",
                                          imageAnimation: .pulsebyLayer,
                                          progress: 0,
                                          for: token)
            }
        }

        Task {
            LucidBanner.shared.dismiss(for: token)
        }

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
