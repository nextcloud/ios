// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import UniformTypeIdentifiers
import NextcloudKit

// MARK: - Drag

extension NCMedia: NCTransferDelegate {
    func transferReloadData(serverUrl: String?, status: Int?) {
        self.debouncer.call {
            Task {
                await self.loadDataSource()
            }
        }
    }

    func transferChange(status: String, metadata: tableMetadata, destination: String?, error: NKError) {
        self.debouncer.call {
            switch status {
            case self.global.networkingStatusCopyMove:
                Task {
                    await self.loadDataSource()
                    await self.searchMediaUI()
                }
            default:
                break
            }
        }
    }
}
