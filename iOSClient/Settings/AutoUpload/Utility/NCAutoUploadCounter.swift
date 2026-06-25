// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation

@MainActor
@Observable
final class NCAutoUploadCounter {
    private(set) var count = 0
    private(set) var failedCount = 0
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
            return NSLocalizedString("_auto_upload_no_new_items_to_upload_", comment: "")
        }

        return String.localizedStringWithFormat(NSLocalizedString("_focused_auto_upload_items_left_", comment: ""), count)
    }

    var photosToBackUpMessage: String {
        return String.localizedStringWithFormat(NSLocalizedString("_focused_auto_upload_photos_to_back_up_", comment: ""), count)
    }

    private var failedMessage: String {
        return String.localizedStringWithFormat(NSLocalizedString("_focused_auto_upload_failed_", comment: ""), failedCount)
    }

    var itemsLeftSummary: String {
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

            await refresh()
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
        count = 0
        failedCount = 0
        isLoaded = false
    }

    private func refresh() async {
        guard let account, let autoUploadServerUrlBase else {
            return
        }

        let counts = await NCManageDatabase.shared.countAutoUploadMetadatasAsync(account: account,
                                                                                 autoUploadServerUrlBase: autoUploadServerUrlBase)

        count = counts.pending
        failedCount = counts.failed
        isLoaded = true
    }
}
