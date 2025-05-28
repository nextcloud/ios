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

    func transferReloadData(serverUrl: String?) {
        self.debouncer.call {
            self.loadDataSource()
        }
    }

    func transferCopy(metadata: tableMetadata, error: NKError) {
        setEditMode(false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.loadDataSource()
            self.searchMediaUI()
        }
    }

    func transferMove(metadata: tableMetadata, error: NKError) {
        setEditMode(false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.loadDataSource()
            self.searchMediaUI()
        }
    }

    func transferFileExists(ocId: String, exists: Bool) {
        filesExists.append(ocId)
        if !exists {
            ocIdDoNotExists.append(ocId)
        }
        if NCNetworking.shared.fileExistsQueue.operationCount == 0,
           !ocIdDoNotExists.isEmpty,
           let ocIdDoNotExists = self.ocIdDoNotExists.getArray() {
            dataSource.removeMetadata(ocIdDoNotExists)
            database.deleteMetadataOcIds(ocIdDoNotExists)
            self.ocIdDoNotExists.removeAll()
            collectionViewReloadData()
        }
    }
}
