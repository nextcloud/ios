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
    var taskIdentifier: Int

    var date: Date?
    var etag: String?
    var size: Int64?
}

actor TranfersSuccess {
    private var tranfersSuccessItem: [TranfersSuccessItem] = []
    private var tablesMetadatas: [tableMetadata] = []
    private var tablesLocalFiles: [tableMetadata] = []
    private var tablesLivePhoto: [tableMetadata] = []
    private var tablesAutoUpload: [tableAutoUploadTransfer] = []

    func append(ocId: String, fileName: String, serverUrl: String, taskIdentifier: Int, date: Date?, etag: String?, size: Int64?) {
        let item = TranfersSuccessItem(ocId: ocId,
                                       fileName: fileName,
                                       serverUrl: serverUrl,
                                       taskIdentifier: taskIdentifier,
                                       date: date,
                                       etag: etag,
                                       size: size)
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
        let utility = NCUtility()
        let isInBackground = NCNetworking.shared.isInBackground()

        let metadatasUploading = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "status == %d", NCGlobal.shared.metadataStatusUploading)) ?? []

        for item in tranfersSuccessItem {
            let metadata: tableMetadata?

            if let found = metadatasUploading.first(where: {
                $0.fileName == item.fileName &&
                $0.serverUrl == item.serverUrl &&
                $0.sessionTaskIdentifier == item.taskIdentifier
            }) {
                metadata = found
            } else {
                metadata = await NCManageDatabase.shared.getMetadataAsync(
                    predicate: NSPredicate(
                        format: "serverUrl == %@ AND fileName == %@ AND sessionTaskIdentifier == %d",
                        item.serverUrl,
                        item.fileName,
                        item.taskIdentifier
                    )
                )
            }
            guard let metadata else {
                continue
            }

            metadata.uploadDate = (item.date as? NSDate) ?? NSDate()
            metadata.etag = item.etag ?? ""
            metadata.ocId = item.ocId
            metadata.chunk = 0

            if let fileId = utility.ocIdToFileId(ocId: item.ocId) {
                metadata.fileId = fileId
            }

            metadata.session = ""
            metadata.sessionError = ""
            metadata.sessionTaskIdentifier = 0
            metadata.status = NCGlobal.shared.metadataStatusNormal

            let results = await NCNetworking.shared.helperMetadataSuccess(metadata: metadata)
        }


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
