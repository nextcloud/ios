// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct TranfersSuccessItem: Codable, Identifiable {
    var id: String {
        ocId
    }

    var ocId: String
    var fileName: String
    var serverUrl: String

    var etag: String?
    var size: Int64?
}

actor TranfersSuccess {
    private var tranfersSuccessItem: [TranfersSuccessItem] = []
    private var tablesMetadatas: [tableMetadata] = []
    private var tablesLocalFiles: [tableMetadata] = []
    private var tablesLivePhoto: [tableMetadata] = []
    private var tablesAutoUpload: [tableAutoUploadTransfer] = []

    func append(ocId: String, fileName: String, serverUrl: String, etag: String?, size: Int64?) {
        let item = TranfersSuccessItem(ocId: ocId, fileName: fileName, serverUrl: serverUrl, etag: etag, size: size)
        tranfersSuccessItem.append(item)
    }

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
