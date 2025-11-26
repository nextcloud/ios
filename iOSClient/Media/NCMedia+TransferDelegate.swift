// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import UniformTypeIdentifiers
import NextcloudKit

// MARK: - Drag

extension NCMedia: NCTransferDelegate {
    func transferReloadData(serverUrl: String?, requestData: Bool, status: Int?) {
        Task {
            await self.debouncer.call {
                await self.loadDataSource()
            }
        }
    }

    func transferChange(status: String,
                        account: String,
                        fileName: String,
                        serverUrl: String,
                        selector: String?,
                        ocId: String,
                        destination: String?,
                        error: NKError) {
        Task {
            await self.debouncer.call {
                switch status {
                case self.global.networkingStatusCopyMove:
                    await self.loadDataSource()
                    await self.searchMediaUI()
                default:
                    break
                }
            }
        }
    }
}
