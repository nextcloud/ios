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

    func transferCopyMove(metadata: tableMetadata, destination: String, error: NKError) {
        Task {
            await self.loadDataSource()
            await self.searchMediaUI()
        }
    }
}
