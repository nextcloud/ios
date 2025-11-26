// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

public protocol NCMetadataTransfersSuccessDelegate: AnyObject {
    func metadataTransferWillFlush(hasLivePhotos: Bool)
    func metadataTransferDidFlush(hasLivePhotos: Bool)
}

actor NCMetadataTranfersSuccess {
    private var tranfersSuccess: [tableMetadata] = []
    private let utility = NCUtility()
    private var delegates: [NCMetadataTransfersSuccessDelegate] = []

    // Adds a new delegate
    func addDelegate(_ delegate: NCMetadataTransfersSuccessDelegate) {
        delegates.append(delegate)
    }

    // Removes a delegate
    func removeDelegate(_ delegate: NCMetadataTransfersSuccessDelegate) {
        delegates.removeAll { $0 as AnyObject === delegate as AnyObject }
    }

    func append(metadata: tableMetadata, ocId: String, date: Date?, etag: String?) async {
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

        // Create Live Photo metadata
        let capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)
        if capabilities.isLivePhotoServerAvailable,
           metadata.isLivePhoto {
            await NCManageDatabase.shared.setLivePhotoVideo(account: metadata.account,
                                                            serverUrlFileName: metadata.serverUrlFileName,
                                                            fileId: metadata.fileId,
                                                            classFile: metadata.classFile)
        }
    }

    func count() -> Int {
        tranfersSuccess.count
    }

    func getAll() -> [tableMetadata] {
        tranfersSuccess
    }

    func exists(serverUrlFileName: String) async -> Bool {
        return tranfersSuccess.filter({ $0.serverUrlFileName == serverUrlFileName }).first != nil
    }

    func flush() async {
        let metadatas: [tableMetadata] = tranfersSuccess
        let hasLivePhotos = await NCManageDatabase.shared.hasLivePhotos()
        tranfersSuccess.removeAll(keepingCapacity: true)

        var metadatasLocalFiles: [tableMetadata] = []
        var metadatasLivePhoto: [tableMetadata] = []
        var autoUploads: [tableAutoUploadTransfer] = []

        for delegate in delegates {
            delegate.metadataTransferWillFlush(hasLivePhotos: hasLivePhotos)
        }

        for metadata in metadatas {
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

        await NCManageDatabase.shared.addMetadatasAsync(metadatas)

        // Local File
        await NCManageDatabase.shared.addLocalFilesAsync(metadatas: metadatasLocalFiles)

        // Auto Upload
        await NCManageDatabase.shared.addAutoUploadTransferAsync(autoUploads)

        if !NCNetworking.shared.isInBackground() {
            // Set livePhoto on Server
            let accounts = Set(metadatasLivePhoto.map { $0.account })
            for account in accounts {
                await NCNetworking.shared.setLivePhoto(account: account)
                if isAppInBackground {
                    return
                }
            }

            // TransferDispatcher — notify outside of shared-state mutation
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                for metadata in metadatas {
                    delegate.transferChange(status: NCGlobal.shared.networkingStatusUploaded,
                                            account: metadata.account,
                                            fileName: metadata.fileName,
                                            serverUrl: metadata.serverUrl,
                                            selector: metadata.sessionSelector,
                                            ocId: metadata.ocId,
                                            destination: nil,
                                            error: .success)
                }
            }
        }

        for delegate in delegates {
            delegate.metadataTransferDidFlush(hasLivePhotos: hasLivePhotos)
        }

        nkLog(tag: NCGlobal.shared.logTagMetadataTransfers, message: "Flush successful (\(metadatas.count))", consoleOnly: true)
    }
}
