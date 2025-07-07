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
        /// DELETE
        case NCGlobal.shared.networkingStatusDelete:
            self.debouncer.call {
                Task {
                    await self.loadDataSource()
                }
            }
        default:
            break
        }
    }

    func transferReloadData(serverUrl: String?, status: Int?) {
        self.debouncer.call {
            Task {
                await self.loadDataSource()
            }
        }
    }

    func transferCopy(metadata: tableMetadata, error: NKError) {
        setEditMode(false)

        Task {
            await self.loadDataSource()
            await self.searchMediaUI()
        }
    }

    func transferMove(metadata: tableMetadata, error: NKError) {
        setEditMode(false)

        Task {
            await self.loadDataSource()
            await self.searchMediaUI()
        }
    }

    func transferFileExists(ocId: String, exists: Bool) {
        Task {
            await tracker.appendToFilesExists(ocId)
            if !exists {
                await tracker.appendToOcIdDoNotExists(ocId)
            }
            if networking.fileExistsQueue.operationCount == 0,
               await !tracker.isEmptyOcIdDoNotExists() {
                let ocIdDoNotExists = await tracker.getOcIdDoNotExists()

                dataSource.removeMetadata(ocIdDoNotExists)
                database.deleteMetadataOcIds(ocIdDoNotExists)
                await tracker.resetOcIdDoNotExists()

                collectionViewReloadData()
            }
        }
    }
}
