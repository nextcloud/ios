// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    func updateMetadataForUploadFailure(metadata: tableMetadata, job: PHAssetResourceUploadJob) async {
        let error = job.error.map { $0 as NSError }

        metadata.session = ""
        metadata.sessionTaskIdentifier = 0
        metadata.sessionDate = Date()
        metadata.sessionError = error?.localizedDescription ?? "Background upload failed"
        metadata.errorCode = error?.code ?? NSURLErrorUnknown
        metadata.status = global.metadataStatusUploadError

        await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)

        nkLog(
            tag: global.logTagBackgroundUpload,
            message: """
            Background upload failed for \(metadata.fileName), \
            job: \(job.localIdentifier), \
            error: \(metadata.errorCode) \(metadata.sessionError)
            """
        )
    }

    func processUploadSuccess(metadata: tableMetadata, job: PHAssetResourceUploadJob) async -> Bool {
        let headers = job.responseHeaderFields ?? [:]

        guard let ocId = headers["oc-fileid"],
              !ocId.isEmpty else {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: """
                Successful job without oc-fileid: \
                \(job.localIdentifier)
                """
            )
            return false
        }

        let etag = nkComm.normalizedETag(
            headers["oc-etag"]
        )

        let date = headers["date"]?.parsedDate(
            using: "EEE, dd MMM y HH:mm:ss zzz"
        )

        let ownerId = headers["x-nc-ownerid"]
        let permissions = headers["x-nc-permissions"]

        metadata.uploadDate = (date as? NSDate) ?? NSDate()
        metadata.etag = etag ?? ""
        metadata.ocId = ocId

        if let fileId = NCUtility().ocIdToFileId(ocId: ocId) {
            metadata.fileId = fileId
        }

        if let ownerId, !ownerId.isEmpty {
           metadata.ownerId = ownerId
           if let ownerDisplayName = await NCManageDatabase.shared.getOwnerDisplayName(account: metadata.account, ownerId: ownerId) {
               metadata.ownerDisplayName = ownerDisplayName
           }
       }

       if let permissions, !permissions.isEmpty {
           metadata.permissions = permissions
       }

        metadata.chunk = 0
        metadata.sceneIdentifier = nil
        metadata.session = ""
        metadata.sessionError = ""
        metadata.sessionDate = nil
        metadata.sessionTaskIdentifier = 0
        metadata.status = NCGlobal.shared.metadataStatusNormal

        if metadata.sessionSelector == global.selectorUploadAutoUpload,
           let serverUrlBase = metadata.autoUploadServerUrlBase {
            await database.addAutoUploadTransferAsync(
                account: metadata.account,
                serverUrlBase: serverUrlBase,
                fileName: metadata.fileNameView,
                assetLocalIdentifier: metadata.assetLocalIdentifier,
                date: metadata.creationDate as Date
            )
        }

        await database.replaceMetadataAsync(
            ocId: metadata.ocIdTransfer,
            metadata: metadata
        )

        return true
    }
}
