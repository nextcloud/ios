// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

actor TranfersSuccess {
    private var tablesMetadatas: [tableMetadata] = []
    private var tablesLocalFiles: [tableMetadata] = []
    private var tablesLivePhoto: [tableMetadata] = []
    private var tablesAutoUpload: [tableAutoUploadTransfer] = []

    func append(metadata: tableMetadata, localFile: tableMetadata?, livePhoto: tableMetadata?, autoUpload: tableAutoUploadTransfer?) {
        tablesMetadatas.append(metadata)
        if let localFile {
            tablesLocalFiles.append(localFile)
        }
        if let livePhoto {
            tablesLivePhoto.append(livePhoto)
        }
        if let autoUpload {
            tablesAutoUpload.append(autoUpload)
        }
    }

    func count() async -> Int {
        return tablesMetadatas.count
    }

    func flush() async {
        let isInBackground = NCNetworking.shared.isInBackground()
        // Metadatas
        let ocIdTransfers = tablesMetadatas.map(\.ocIdTransfer)
        await NCManageDatabase.shared.replaceMetadataAsync(ocIdTransfersToDelete: ocIdTransfers, metadatas: tablesMetadatas)

        // Local File
        await NCManageDatabase.shared.addLocalFilesAsync(metadatas: tablesLocalFiles)

        // Live Photo
        if !tablesLivePhoto.isEmpty {
            let accounts = Set(tablesLivePhoto.map { $0.account })
            await NCManageDatabase.shared.setLivePhotoVideo(metadatas: tablesLivePhoto)
            #if !EXTENSION
            for account in accounts {
                await NCNetworking.shared.setLivePhoto(account: account)
            }
            #endif
        }
        // Auto Upload
        await NCManageDatabase.shared.addAutoUploadTransferAsync(tablesAutoUpload)

        // TransferDispatcher
        //
        if !tablesMetadatas.isEmpty,
           !isInBackground {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                for metadata in tablesMetadatas {
                    delegate.transferChange(status: NCGlobal.shared.networkingStatusUploaded,
                                            metadata: metadata,
                                            error: .success)
                }
            }
        }

        tablesMetadatas.removeAll()
        tablesLocalFiles.removeAll()
        tablesLivePhoto.removeAll()
        tablesAutoUpload.removeAll()
    }
}
