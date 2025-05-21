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
            var needLoadDataSource: Bool = false

            for (key, error) in metadatasError {
                switch error {
                case .success:
                    continue
                default:
                    if error.errorCode == self.global.errorResourceNotFound {
                        deleteOcIds.append(key.ocId)
                    }
                    needLoadDataSource = true
                }
            }

            if needLoadDataSource {
                self.loadDataSource {
                    self.semaphoreNotificationCenter.signal()
                }
            } else {
                self.semaphoreNotificationCenter.signal()
            }
        default:
            break
        }
    }
}
