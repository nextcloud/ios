// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

actor TranfersSuccess {
    private var tranfersSuccess: [tableMetadata] = []
    private let utility = NCUtility()

    func append(metadata: tableMetadata, ocId: String, date: Date?, etag: String?) {
        metadata.ocId = ocId
        metadata.uploadDate = (date as? NSDate) ?? NSDate()
        metadata.etag = etag ?? ""
        metadata.chunk = 0

        if let fileId = self.utility.ocIdToFileId(ocId: ocId) {
            metadata.fileId = fileId
        }

        metadata.session = ""
        metadata.sessionError = ""
        metadata.sessionTaskIdentifier = 0
        metadata.status = NCGlobal.shared.metadataStatusNormal

        tranfersSuccess.append(metadata)
    }

    func count() async -> Int {
        return tranfersSuccess.count
    }

    func flush() async {
        let isInBackground = NCNetworking.shared.isInBackground()
        var metadatasLocalFiles: [tableMetadata] = []
        var metadatasLivePhoto: [tableMetadata] = []
        var autoUploads: [tableAutoUploadTransfer] = []

        for metadata in tranfersSuccess {
            let results = await NCNetworking.shared.helperMetadataSuccess(metadata: metadata)

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
        let ocIdTransfers = tranfersSuccess.map(\.ocIdTransfer)
        await NCManageDatabase.shared.replaceMetadataAsync(ocIdTransfersToDelete: ocIdTransfers, metadatas: tranfersSuccess)

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
        if !tranfersSuccess.isEmpty,
           !isInBackground {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                for metadata in tranfersSuccess {
                    delegate.transferChange(status: NCGlobal.shared.networkingStatusUploaded,
                                            metadata: metadata,
                                            error: .success)
                }
            }
        }

        tranfersSuccess.removeAll()
    }
}
