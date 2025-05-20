// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import UniformTypeIdentifiers
import NextcloudKit

// MARK: - Drag

extension NCMedia: NCTransferDelegate {
    func transferChange(status: String, metadatasError: [tableMetadata: NKError]) {
        switch status {
        case NCGlobal.shared.networkingStatusDelete:
            if self.semaphoreNotificationCenter.wait(timeout: .now() + 5) == .timedOut {
                self.semaphoreNotificationCenter.signal()
            }
            var deleteOcIds: [String] = []
            var loadDataSource: Bool = false
            for metadataError in metadatasError {
                if metadataError.value.errorCode == self.global.errorResourceNotFound {
                    deleteOcIds.append(metadataError.key.ocId)
                    loadDataSource = true
                } else if metadataError.value != .success {
                    loadDataSource = true
                }
            }
            if loadDataSource {
                self.loadDataSource {
                    self.semaphoreNotificationCenter.signal()
                }
            }
        default:
            break
        }
    }
}
