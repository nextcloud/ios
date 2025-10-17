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

    func count() async -> Int {
        return tranfersSuccessItem.count
    }

    func flush() async {
        let utility = NCUtility()
        let isInBackground = NCNetworking.shared.isInBackground()

        var metadatasUploaded: [tableMetadata] = []
        var metadatasLocalFiles: [tableMetadata] = []
        var metadatasLivePhoto: [tableMetadata] = []
        var autoUploads: [tableAutoUploadTransfer] = []

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

            metadatasUploaded.append(metadata)
            if let localFile = results.localFile {
                metadatasLocalFiles.append(localFile)
            }
            if let livePhoto = results.livePhoto {
                metadatasLivePhoto.append(livePhoto)
            }
            if let autoUpload = results.autoUpload {
                autoUploads.append(autoUpload)
            }
        }

        // Metadatas
        let ocIdTransfers = metadatasUploaded.map(\.ocIdTransfer)
        await NCManageDatabase.shared.replaceMetadataAsync(ocIdTransfersToDelete: ocIdTransfers, metadatas: metadatasUploaded)

        // Local File
        await NCManageDatabase.shared.addLocalFilesAsync(metadatas: metadatasLocalFiles)

        // Live Photo
        if !metadatasLivePhoto.isEmpty {
            let accounts = Set(metadatasLivePhoto.map { $0.account })
            await NCManageDatabase.shared.setLivePhotoVideo(metadatas: metadatasLivePhoto)
            #if !EXTENSION
            for account in accounts {
                await NCNetworking.shared.setLivePhoto(account: account)
            }
            #endif
        }

        // Auto Upload
        await NCManageDatabase.shared.addAutoUploadTransferAsync(autoUploads)

        // TransferDispatcher
        //
        if !metadatasUploaded.isEmpty,
           !isInBackground {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                for metadata in metadatasUploaded {
                    delegate.transferChange(status: NCGlobal.shared.networkingStatusUploaded,
                                            metadata: metadata,
                                            error: .success)
                }
            }
        }

        tranfersSuccessItem.removeAll()
    }
}
