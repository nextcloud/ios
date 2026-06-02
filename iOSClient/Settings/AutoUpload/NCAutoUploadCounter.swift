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

    var hasItemsToUpload: Bool {
        return isLoaded && count > 0
    }

    var itemsLeftMessage: String {
        if count == 0 {
            return NSLocalizedString("_auto_upload_no_new_items_to_upload_", comment: "")
        }

        return String.localizedStringWithFormat(NSLocalizedString("_focused_auto_upload_items_left_", comment: ""), count)
    }

    var photosToBackUpMessage: String {
        return String.localizedStringWithFormat(NSLocalizedString("_focused_auto_upload_photos_to_back_up_", comment: ""), count)
    }

    var failedMessage: String {
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

    @ObservationIgnored private var pollTask: Task<Void, Never>?

    func start(account: String,
               urlBase: String,
               userId: String,
               autoUploadStart: Bool) {
        guard autoUploadStart else {
            stopPolling(reset: true)
            return
        }

        startPolling(account: account, urlBase: urlBase, userId: userId)
    }

    func stop(reset: Bool = false) {
        stopPolling(reset: reset)
    }

    private func startPolling(account: String, urlBase: String, userId: String) {
        stopPolling(reset: false)
        isLoaded = false

        pollTask = Task { @MainActor in
            let autoUploadServerUrlBase = await NCManageDatabase.shared.getAccountAutoUploadServerUrlBaseAsync(account: account,
                                                                                                               urlBase: urlBase,
                                                                                                               userId: userId)

            while !Task.isCancelled {
                let counts = await NCManageDatabase.shared.countAutoUploadMetadatasAsync(account: account,
                                                                                         autoUploadServerUrlBase: autoUploadServerUrlBase)

                guard !Task.isCancelled else {
                    return
                }

                count = counts.pending
                failedCount = counts.failed
                isLoaded = true

                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func stopPolling(reset: Bool) {
        pollTask?.cancel()
        pollTask = nil

        if reset {
            count = 0
            failedCount = 0
            isLoaded = false
        }
    }
}
