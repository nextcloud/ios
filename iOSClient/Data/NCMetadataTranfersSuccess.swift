// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

actor NCMetadataTranfersSuccess {
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

        if let index = tranfersSuccess.firstIndex(where: { $0.ocId == metadata.ocId }) {
            tranfersSuccess[index] = metadata
        } else {
            tranfersSuccess.append(metadata)
        }
    }

    func count() -> Int {
        tranfersSuccess.count
    }

    func getAll() -> [tableMetadata] {
        tranfersSuccess
    }

    func getMetadata(ocIdTransfer: String) async -> tableMetadata? {
        return tranfersSuccess.filter({ $0.ocIdTransfer == ocIdTransfer }).first
    }

    func flush() async {
        let isInBackground = NCNetworking.shared.isInBackground()
        let snapshot: [tableMetadata] = tranfersSuccess
        tranfersSuccess.removeAll(keepingCapacity: true)

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMetadataTranfersSuccessFlush)

        guard !snapshot.isEmpty else {
            nkLog(tag: NCGlobal.shared.logTagMetadataTransfers, message: "Flush skipped (no items)", consoleOnly: true)
            return
        }

        var metadatasLocalFiles: [tableMetadata] = []
        var metadatasLivePhoto: [tableMetadata] = []
        var autoUploads: [tableAutoUploadTransfer] = []

        for metadata in snapshot {
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

        let ocIdTransfers = snapshot.map(\.ocIdTransfer)
        await NCManageDatabase.shared.replaceMetadataAsync(ocIdTransfersToDelete: ocIdTransfers, metadatas: snapshot)

        // Local File
        if !metadatasLocalFiles.isEmpty {
            await NCManageDatabase.shared.addLocalFilesAsync(metadatas: metadatasLocalFiles)
        }

        // Auto Upload
        if !autoUploads.isEmpty {
            await NCManageDatabase.shared.addAutoUploadTransferAsync(autoUploads)
        }

        // Live Photo
        if !metadatasLivePhoto.isEmpty,
           !isInBackground {
            let accounts = Set(metadatasLivePhoto.map { $0.account })
            await NCManageDatabase.shared.setLivePhotoVideo(metadatas: metadatasLivePhoto)
            #if !EXTENSION
            for account in accounts {
                await NCNetworking.shared.setLivePhoto(account: account)
            }
            #endif
        }

        // TransferDispatcher — notify outside of shared-state mutation
        if !isInBackground {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                for metadata in snapshot {
                    delegate.transferChange(status: NCGlobal.shared.networkingStatusUploaded,
                                            metadata: metadata,
                                            destination: nil,
                                            error: .success)
                }
            }
        }

        nkLog(tag: NCGlobal.shared.logTagMetadataTransfers, message: "Flush successful (\(snapshot.count))", consoleOnly: true)
    }
}
