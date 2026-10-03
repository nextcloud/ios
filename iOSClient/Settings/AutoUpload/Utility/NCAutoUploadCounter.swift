// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation
import Photos

@MainActor
@Observable
final class NCAutoUploadCounter {
    private(set) var sinceDate: Date?
    private(set) var count = 0
    private(set) var failedCount = 0
    private(set) var isSuspended = false
    private(set) var suspensionError: String?
    private(set) var isLoaded = false

    init() {}

#if DEBUG
    init(previewCount: Int) {
        self.count = previewCount
        self.isLoaded = true
    }
#endif

    var hasItemsToUpload: Bool {
        return isLoaded && count > 0
    }

    private var itemsLeftMessage: String {
        if count == 0 {
            let key = usesPhotoKitAutoUpload ? "_auto_upload_active_" : "_auto_upload_no_new_items_to_upload_"
            return NSLocalizedString(key, comment: "")
        }

        return String.localizedStringWithFormat(NSLocalizedString("_auto_upload_files_in_queue_", comment: ""), count)
    }

    private var usesPhotoKitAutoUpload: Bool {
        guard #available(iOS 27, *),
              NCPreferences().shouldUseBackgroundUploadExtension,
              PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized,
              let account,
              let capabilities = NCNetworking.shared.capabilities[account] else { return false }
        return NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: .v35)
    }

    var photosToBackUpMessage: String {
        return String.localizedStringWithFormat(NSLocalizedString("_focused_auto_upload_photos_to_back_up_", comment: ""), count)
    }

    private var failedMessage: String {
        return String.localizedStringWithFormat(NSLocalizedString("_focused_auto_upload_failed_", comment: ""), failedCount)
    }

    var itemsLeftSummary: String {
        // A suspended queue cannot make progress, so its blocking error is more useful than counters.
        if isSuspended {
            if let suspensionError {
                return String.localizedStringWithFormat(
                    NSLocalizedString("_auto_upload_suspended_error_", comment: ""),
                    suspensionError
                )
            }

            return NSLocalizedString("_auto_upload_suspended_", comment: "")
        }

        if failedCount == 0 {
            return itemsLeftMessage
        }

        if count == 0 {
            return failedMessage
        }

        return itemsLeftMessage + " · " + failedMessage
    }

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var account: String?
    @ObservationIgnored private var autoUploadServerUrlBase: String?

    func start(account: String,
               urlBase: String,
               userId: String,
               autoUploadStart: Bool) {
        guard autoUploadStart else {
            stop(reset: true)
            return
        }

        // Transfers badge updates this so the update tick is the same.
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterTransferCountChanged),
                                                          object: nil,
                                                          queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }

        task?.cancel()
        task = Task { @MainActor in
            let base = await NCManageDatabase.shared.getAccountAutoUploadServerUrlBaseAsync(account: account,
                                                                                            urlBase: urlBase,
                                                                                            userId: userId)

            guard !Task.isCancelled else {
                return
            }

            self.account = account
            self.autoUploadServerUrlBase = base

            // PhotoKit can replace completed jobs without changing the queue count.
            // Refresh while the view is subscribed so the incremental date stays current too.
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    func stop(reset: Bool = false) {
        task?.cancel()
        task = nil

        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }

        guard reset else {
            return
        }

        account = nil
        autoUploadServerUrlBase = nil
        sinceDate = nil
        count = 0
        failedCount = 0
        isSuspended = false
        suspensionError = nil
        isLoaded = false
    }

    private func refresh() async {
        guard let account, let autoUploadServerUrlBase else {
            return
        }

        let counts = await NCManageDatabase.shared.countAutoUploadMetadatasAsync(account: account,
                                                                                 autoUploadServerUrlBase: autoUploadServerUrlBase)

        let currentSinceDate = await NCManageDatabase.shared.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", account))?.autoUploadSinceDate
        guard self.account == account, self.autoUploadServerUrlBase == autoUploadServerUrlBase else { return }
        sinceDate = currentSinceDate
        count = counts.pending
        failedCount = counts.failed

        isSuspended = NCPreferences().isBackgroundUploadSuspended(account: account)
        suspensionError = nil

        if isSuspended {
            // The newest stopped transfer contains the server error that opened the circuit breaker.
            let predicate = NSPredicate(
                format: "account == %@ AND autoUploadServerUrlBase == %@ AND directory == false AND status == %d AND backgroundUploadJobIdentifier == %@",
                account,
                autoUploadServerUrlBase,
                NCGlobal.shared.metadataStatusUploadError,
                "pending"
            )
            let metadata = await NCManageDatabase.shared.getMetadatasAsync(
                predicate: predicate,
                sortedByKeyPath: "sessionDate",
                ascending: false,
                limit: 1
            )?.first
            let error = metadata?.sessionError.trimmingCharacters(in: .whitespacesAndNewlines)

            if let error, !error.isEmpty {
                suspensionError = error
            }
        }

        isLoaded = true
    }
}
