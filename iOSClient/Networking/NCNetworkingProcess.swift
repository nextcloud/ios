// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Photos
import RealmSwift
import Alamofire
import LucidBanner
import SwiftUI

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
    private var lastScheduledAndInProgressCount: Int = 0
    private var lastVerifyZombieDate: Date = .distantPast
    private let verifyZombieInterval: TimeInterval = 12
    private var lastAssetRemovalDate: Date = .distantPast
    private let removeUploadedAssetsInterval: TimeInterval = 300
    private var lastAssetRemovalFailed = false
    // When the current, still-unanswered batch of removal candidates first
    // appeared. The wait before prompting is measured from here rather than from
    // the previous attempt: "last attempt" is ancient whenever the app has been
    // running a while, which made the interval trivially satisfied and popped the
    // sheet for whichever single asset happened to finish uploading first, with
    // the rest arriving in a second prompt. Anchoring on the batch gives the rule
    // "prompt once the queue drains, or after the interval if it never does".
    // Cleared whenever no candidates remain.
    private var candidatesPendingSince: Date?

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.nextcloud.timerProcess", qos: .utility)
    private var lastUsedInterval: TimeInterval = 3.5
    public let maxInterval: TimeInterval = 3.5
    private let minInterval: TimeInterval = 2.5
    private let offlineInterval: TimeInterval = 10
    private let seriousThermalInterval: TimeInterval = 7
    private let criticalThermalInterval: TimeInterval = 12

    /// Returns the preferred polling interval for the networking process.
    ///
    /// The interval is adjusted according to the current thermal state to reduce
    /// CPU activity, database checks, and transfer polling when the device is hot.
    /// Offline mode keeps its dedicated interval during nominal and fair states.
    ///
    /// - Parameter hasPendingTransfers: Indicates whether uploads or downloads are pending.
    /// - Returns: The interval to use before the next networking process check.
    private func preferredTimerInterval(hasPendingTransfers: Bool) -> TimeInterval {
        let baseInterval: TimeInterval

        if networking.isOffline {
            baseInterval = offlineInterval
        } else {
            baseInterval = hasPendingTransfers ? minInterval : maxInterval
        }

        switch ProcessInfo.processInfo.thermalState {
        case .critical:
            return max(baseInterval, criticalThermalInterval)

        case .serious:
            return max(baseInterval, seriousThermalInterval)

        case .fair, .nominal:
            return baseInterval

        @unknown default:
            return baseInterval
        }
    }

    private func updateTimerIntervalIfNeeded(hasPendingTransfers: Bool) async {
        let interval = preferredTimerInterval(hasPendingTransfers: hasPendingTransfers)
        guard lastUsedInterval != interval else {
            return
        }

        await startTimer(interval: interval)
    }

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

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterNetworkingProcess), object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            Task {
                await self.handleTimerTick()
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            Task {
                let count = await self.scheduledAndInProgressCount()
                try? await UNUserNotificationCenter.current().setBadgeCount(count)

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
            for controllerCandidate in SceneManager.shared.getControllers() {
                if controllerCandidate.account == account {
                    controller = controllerCandidate
                    break
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

    private func scheduledAndInProgressCount() async -> Int {
        let statuses = NCGlobal.shared.metadatasStatusInWaitingDownloadUpload + NCGlobal.shared.metadatasStatusDownloadingUploading

        return await NCManageDatabase.shared.getMetadatasStatusCountAsync(status: statuses)
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

            guard !currentAccount.isEmpty,
                  networking.noServerErrorAccount(currentAccount)
            else {
                return
            }

            // UPDATE SCHEDULED + IN PROGRESS & BADGE
            //
            let count = await scheduledAndInProgressCount()
            if count != lastScheduledAndInProgressCount {
                lastScheduledAndInProgressCount = count
                Task { @MainActor in
                    if let controller = getRootController(),
                       let files = controller.tabBar.items?.first {
                            files.badgeValue = count == 0 ? nil : self.utility.formatBadgeCount(count)
                    }
                }

                NotificationCenter.default.post(name: NSNotification.Name(rawValue: global.notificationCenterTransferCountChanged), object: nil)
            }

            // METADATAS
            //
            var metadatas = await NCManageDatabase.shared.getMetadataProcess()

            // TRANSFERS UPLOAD SUCCESS
            //
            let countTransferUploadSuccess = await NCNetworking.shared.metadataUploadTranfersSuccess.count()
            let countWaitUpload = metadatas.filter { $0.status == self.global.metadataStatusWaitUpload }.count
            if (countWaitUpload == 0 && countTransferUploadSuccess > 0) || countTransferUploadSuccess >= NCBrandOptions.shared.numMaximumProcess {
                await NCNetworking.shared.metadataUploadTranfersSuccess.flush()
            }

            // TRANSFERS DOWNLOAD SUCCESS
            //
            let countTransferDownloadSuccess = await NCNetworking.shared.metadataDownloadTranfersSuccess.count()
            let countWaitDownload = metadatas.filter { $0.status == self.global.metadataStatusWaitDownload }.count
            if (countWaitDownload == 0 && countTransferDownloadSuccess > 0) || countTransferDownloadSuccess >= NCBrandOptions.shared.numMaximumProcess {
                await NCNetworking.shared.metadataDownloadTranfersSuccess.flush()
            }

            // ZOMBIE
            // Check periodically while transfers are marked as in progress. Do not let a
            // stalled download keep a process slot occupied, but avoid querying all URLSession
            // task lists on every pipeline tick.
            let countProgress = metadatas.filter { global.metadatasStatusDownloadingUploading.contains($0.status) }.count
            if countProgress > 0,
               Date().timeIntervalSince(lastVerifyZombieDate) >= verifyZombieInterval {
                lastVerifyZombieDate = Date()
                await NCNetworking.shared.verifyZombie()
                metadatas = await NCManageDatabase.shared.getMetadataProcess()
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

                // TEST EXISTS ACCOUNT
                //
                var metadatasByAccount: [String: [tableMetadata]] = [:]
                for metadata in metadatas {
                    metadatasByAccount[metadata.account, default: []].append(metadata)
                }
                var metadatasToDelete: [tableMetadata] = []
                for account in metadatasByAccount.keys {
                    if await NCManageDatabase.shared.getTableAccountAsync(account: account) == nil {
                        metadatasToDelete.append(contentsOf: metadatasByAccount[account] ?? [])
                    }
                }
                if !metadatasToDelete.isEmpty {
                    let ocIds = metadatasToDelete.map { $0.ocId }
                    await NCManageDatabase.shared.deleteMetadatasAsync(ocIds: ocIds)
                    return
                }

                await runMetadataPipelineAsync(metadatas: metadatas)

                // Remove uploaded assets as soon as they qualify, independently of
                // whatever else is still in the queue: gating this on the *entire*
                // queue being empty (see below) meant any unrelated pending transfer
                // (a download, a different account's upload, …) starved deletion
                // indefinitely, since it's rare for the queue to ever be fully idle.
                await removeUploadedAssetsIfNeeded(queueIsEmpty: false)

                await updateTimerIntervalIfNeeded(hasPendingTransfers: true)
            } else {
                // Remove upload asset
                await removeUploadedAssetsIfNeeded(queueIsEmpty: true)

                // Set Live Photo
                await NCNetworking.shared.setLivePhoto(account: currentAccount)

                await updateTimerIntervalIfNeeded(hasPendingTransfers: false)
            }
        }
    }

    /// Deletes camera roll assets whose upload has already completed, when the
    /// user has enabled "remove after upload". `PHAssetChangeRequest.deleteAssets`
    /// always raises the native "Delete X Photos?" confirmation sheet, which needs
    /// an active foreground app — so this must only ever be called from the
    /// foreground polling timer above, never from a background task. It is no
    /// longer gated on the *entire* transfer queue being idle (see call sites),
    /// only on the asset's own upload having actually completed.
    ///
    /// While other work is still queued, this is additionally debounced to at most
    /// once every `removeUploadedAssetsInterval` — otherwise every single asset
    /// finishing its upload during a busy stretch (a whole camera-roll backlog,
    /// say) pops its own native confirmation sheet in quick succession, which is
    /// disruptive without adding safety. `getAssetLocalIdentifiersUploadedAsync`
    /// always returns *every* currently-eligible asset, not just newly-finished
    /// ones, so delaying the call only batches more assets into one prompt — it
    /// never causes an eligible asset to be skipped. Once the queue is empty there
    /// is nothing left to batch with, so the wait is skipped and cleanup runs
    /// immediately instead of leaving the last batch stranded until the interval
    /// happens to elapse — unless the previous attempt failed (see below), in
    /// which case this fast path is suppressed so an idle queue can't turn into
    /// a retry on every timer tick.
    ///
    /// A failed attempt is never treated as done: the identifiers stay tracked
    /// so a later pass retries them — except a deliberate refusal, which retires
    /// exactly the set that was proposed (those identifiers are cleared, so they
    /// are never offered again) while leaving the feature itself on, so assets
    /// uploaded later are still proposed normally.
    ///
    /// Detecting that refusal takes more than the error code:
    /// `PHPhotosError.userCancelled` is reported both for a real Cancel tap and
    /// for the sheet being torn down because the app left the foreground, so it
    /// is combined with the app-state check described inline below. Everything
    /// else (interruptions, access revoked, …) is assumed transient and keeps
    /// retrying every `removeUploadedAssetsInterval`.
    private func removeUploadedAssetsIfNeeded(queueIsEmpty: Bool) async {
        guard NCPreferences().removePhotoCameraRoll else {
            return
        }
        guard let localIdentifiers = await NCManageDatabase.shared.getAssetLocalIdentifiersUploadedAsync(),
              !localIdentifiers.isEmpty else {
            candidatesPendingSince = nil
            return
        }

        let pendingSince = candidatesPendingSince ?? Date()
        candidatesPendingSince = pendingSince

        if lastAssetRemovalFailed {
            // The previous attempt failed or was interrupted: wait out the
            // interval before asking again, whatever the queue is doing —
            // otherwise an idle queue would re-trigger the confirmation sheet
            // on every timer tick (every ~2.5-3.5s).
            guard Date().timeIntervalSince(lastAssetRemovalDate) >= removeUploadedAssetsInterval else {
                return
            }
        } else {
            // Prompt as soon as there is nothing left to batch with, or once
            // the batch has waited long enough that a never-draining queue
            // would otherwise starve it.
            guard queueIsEmpty || Date().timeIntervalSince(pendingSince) >= removeUploadedAssetsInterval else {
                return
            }
        }

        lastAssetRemovalDate = Date()

        let attemptStartedAt = Date()

        let (completed, error): (Bool, Error?) = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(
                    PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil) as NSFastEnumeration
                )
            }, completionHandler: { completed, error in
                continuation.resume(returning: (completed, error))
            })
        }

        // performChanges reports failure (and, for this specific change, user
        // cancellation of the native confirmation sheet) via `completed == false`
        // — previously discarded here, which meant a declined or failed deletion
        // still cleared these identifiers from tracking below, permanently
        // forgetting to ever retry them. Only clear on actual success.
        guard completed else {
            lastAssetRemovalFailed = true

            let nsError = error as NSError?
            let wasCancelled = nsError?.domain == PHPhotosErrorDomain
                && nsError?.code == PHPhotosError.userCancelled.rawValue

            // `userCancelled` is reported both when the user actually taps
            // Cancel and when the sheet is torn down because the app left the
            // foreground (screen lock, app switch) — same domain, same code, so
            // the error alone can't tell a refusal from an interruption. The
            // app state can: the sheet itself only makes the app *resign
            // active*, it never backgrounds it, so a `didEnterBackground` at
            // any point while the sheet was up means something interrupted it
            // rather than the user answering it. Only an untouched-foreground
            // cancellation counts as a deliberate refusal.
            let wasInterrupted = isAppInBackground || lastDidEnterBackgroundDate >= attemptStartedAt

            if wasCancelled && !wasInterrupted {
                // A refusal applies to the set that was actually put to the
                // user, not to the feature as a whole: these assets are retired
                // from tracking so they are never proposed again, while anything
                // uploaded later still becomes a candidate normally. Clearing the
                // identifier is how "no longer a deletion candidate" is expressed
                // (same as the success path) — for a row that has already reached
                // status Normal, nothing else reads the field.
                lastAssetRemovalFailed = false
                candidatesPendingSince = nil
                await NCManageDatabase.shared.clearAssetLocalIdentifiersAsync(localIdentifiers)
                nkLog(tag: self.global.logTagNetworkingTasks, emoji: .info, message: "Remove \(localIdentifiers.count) uploaded asset(s) from camera roll declined by user, won't propose these again")
            } else if wasCancelled {
                nkLog(tag: self.global.logTagNetworkingTasks, emoji: .info, message: "Remove \(localIdentifiers.count) uploaded asset(s) from camera roll interrupted (app left the foreground before the prompt was answered), will retry")
            } else {
                nkLog(tag: self.global.logTagNetworkingTasks, emoji: .error, message: "Remove \(localIdentifiers.count) uploaded asset(s) from camera roll failed: \(error?.localizedDescription ?? "unknown")")
            }
            return
        }

        lastAssetRemovalFailed = false
        candidatesPendingSince = nil
        nkLog(tag: self.global.logTagNetworkingTasks, emoji: .success, message: "Removed \(localIdentifiers.count) uploaded asset(s) from camera roll")

        await NCManageDatabase.shared.clearAssetLocalIdentifiersAsync(localIdentifiers)
    }

    private func runMetadataPipelineAsync(metadatas: [tableMetadata]) async {
        let database = NCManageDatabase.shared
        let countDownloadTransferSuccess = await NCNetworking.shared.metadataDownloadTranfersSuccess.count()
        let countUploadTransferSuccess = await NCNetworking.shared.metadataUploadTranfersSuccess.count()
        let countDownloading = max(0, metadatas.filter { $0.status == self.global.metadataStatusDownloading }.count - countDownloadTransferSuccess)
        let countUploading = max(0, metadatas.filter { $0.status == self.global.metadataStatusUploading }.count - countUploadTransferSuccess)
        var availableProcess = NCBrandOptions.shared.numMaximumProcess - (countDownloading + countUploading)
        let isWiFi = self.networking.networkReachability == NKTypeReachability.reachableEthernetOrWiFi
        // Banner
        var banner: LucidBanner?
        var token: Int?
        defer {
            if let banner {
                Task { @MainActor in
                    banner.dismiss()
                }
            }
        }

        // WEBDAV
        //
        let waitWebDav = metadatas.filter { self.global.metadataStatusWaitWebDav.contains($0.status) }
        if !waitWebDav.isEmpty {
            let error = await hubProcessWebDav(metadatas: Array(waitWebDav))
            guard error == .success else {
                return
            }
        }

        // OFFLINE TEST
        //
        if networking.isOffline {
            return
        }

        // TEST AVAILABLE PROCESS
        //
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
        //
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
                // Empty can mean two different things: the asset was removed from
                // the photo library before we got to it (nothing left to upload,
                // safe to drop), or extraction itself failed/timed out while the
                // asset is still there (a stalled iCloud fetch, a transient I/O
                // error, ...). Only the first case should delete the queued
                // upload outright — the second should be retried, the same way
                // any other upload failure already is.
                let assetStillExists = !metadata.assetLocalIdentifier.isEmpty &&
                    PHAsset.fetchAssets(withLocalIdentifiers: [metadata.assetLocalIdentifier], options: nil).firstObject != nil

                if assetStillExists {
                    await database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                            sessionTaskIdentifier: 0,
                                                            sessionError: "Asset extraction failed",
                                                            status: global.metadataStatusUploadError)
                } else {
                    await database.deleteMetadataAsync(id: metadata.ocId)
                }
            }
            // upload file(s)
            for metadata in extractMetadatas {
                guard timer != nil,
                      !isAppInBackground else {
                    return
                }

                // IS TRANSFER SUCCESS
                //
                if await NCNetworking.shared.metadataUploadTranfersSuccess.exists(serverUrlFileName: metadata.serverUrlFileName) {
                    // File exists
                    continue
                }

                // AUTO-UPLOAD: CHECK FILE EXISTS
                //
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
                if metadata.isDirectoryE2EE,
                   let windowScene = await SceneManager.shared.getWindow(sceneIdentifier: metadata.sceneIdentifier)?.windowScene {
                    let controller = await getController(account: metadata.account, sceneIdentifier: metadata.sceneIdentifier)
                    let payload = LucidBannerPayload(blocksTouches: true,
                                                     draggable: false)
                    if banner == nil {
                        (banner, token) = await showUploadBanner(windowScene: windowScene,
                                                                 payload: payload,
                                                                 allowMinimizeOnTap: false,
                                                                 onButtonTap: {
                            Task {
                                await self.cancelCurrentUpload()
                            }
                        })
                    }

                    await NCNetworkingE2EEUpload().upload(metadata: metadata,
                                                          controller: controller,
                                                          banner: banner,
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
        guard let windowScene = SceneManager.shared.getWindow(sceneIdentifier: metadata.sceneIdentifier)?.windowScene else {
            return
        }
        var token: Int?
        var banner: LucidBanner?

        (banner, token) = showUploadBanner(windowScene: windowScene,
                                           payload: LucidBannerPayload(stage: .button,
                                                                       vPosition: .bottom,
                                                                       verticalMargin: 50,
                                                                       blocksTouches: false,
                                                                       draggable: true),
                                           allowMinimizeOnTap: true,
                                           onButtonTap: {
            Task {
                await self.cancelCurrentUpload()
                if let banner {
                    banner.dismiss()
                }
            }
        })

        banner?.update(payload: LucidBannerPayload.Update(
            title: NSLocalizedString("_wait_file_preparation_", comment: ""),
            subtitle: NSLocalizedString("_large_upload_tip_", comment: ""),
            footnote: "( " + NSLocalizedString("_tap_to_min_max_", comment: "") + " )",
            systemImage: "gearshape.arrow.triangle.2.circlepath",
            imageAnimation: .rotate
        ))

        let task = Task { () -> (account: String, file: NKFile?, error: NKError) in
            let results = await NCNetworking.shared.uploadChunkFile(metadata: metadata) { total, counter in
                Task {
                    banner?.update(
                        payload: LucidBannerPayload.Update(progress: Double(counter) / Double(total)),
                        for: token
                    )
                }
            } uploadStart: { _ in
                Task {
                    banner?.update(payload: LucidBannerPayload.Update(
                        title: NSLocalizedString("_keep_active_for_upload_", comment: ""),
                        systemImage: "arrowshape.up.circle",
                        imageAnimation: .breathe,
                        progress: 0
                    ), for: token)
                }
            } uploadProgressHandler: { _, _, progress in
                Task {
                    banner?.update(
                        payload: LucidBannerPayload.Update(progress: progress),
                        for: token
                    )
                }
            } assembling: {
                Task {
                    banner?.update(payload: LucidBannerPayload.Update(
                        title: NSLocalizedString("_finalizing_wait_", comment: ""),
                        systemImage: "gearshape.arrow.triangle.2.circlepath",
                        imageAnimation: .rotate,
                        progress: .nan,
                        stage: .placeholder
                    ), for: token)
                }
            }

            return results
        }

        currentUploadTask = task
        _ = await task.value

        if let banner {
            banner.dismiss()
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
