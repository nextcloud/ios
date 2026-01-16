// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import UniformTypeIdentifiers
import NextcloudKit

// MARK: - Drag

extension NCMedia: NCTransferDelegate {
    func transferReloadData(serverUrl: String?) { }

    func transferReloadDataSource(serverUrl: String?, requestData: Bool, status: Int?) {
        Task {
            await self.debouncerLoadDataSource.call {
                await self.loadDataSource()
            }
        }
    }

    func transferProgressDidUpdate(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) { }

    func transferChange(status: String,
                        account: String,
                        fileName: String,
                        serverUrl: String,
                        selector: String?,
                        ocId: String,
                        destination: String?,
                        error: NKError) {
        Task {
            await self.debouncerSearch.call {
                await self.loadDataSource()
                await self.searchMediaUI()
            }
        }
    }
}
