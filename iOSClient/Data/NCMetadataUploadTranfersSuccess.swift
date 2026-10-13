// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

public protocol NCMetadataUploadTransfersSuccessDelegate: AnyObject {
    func metadataUploadTransferWillFlush(hasLivePhotos: Bool)
    func metadataUploadTransferDidFlush(hasLivePhotos: Bool)
}

actor NCMetadataUploadTranfersSuccess {
    private struct TransferSuccessItem {
        let metadata: tableMetadata
        let backgroundAutoUpload: Bool?
    }

    private var tranfersSuccess: [TransferSuccessItem] = []
    private var flushingItems: [TransferSuccessItem] = []
    private var isFlushing = false
    private let utility = NCUtility()
    private var delegates: [NCMetadataUploadTransfersSuccessDelegate] = []

    // Adds a new delegate
    func addDelegate(_ delegate: NCMetadataUploadTransfersSuccessDelegate) {
        delegates.append(delegate)
    }

    // Removes a delegate
    func removeDelegate(_ delegate: NCMetadataUploadTransfersSuccessDelegate) {
        delegates.removeAll { $0 as AnyObject === delegate as AnyObject }
    }

    func append(metadata: tableMetadata,
                ocId: String,
                date: Date?,
                etag: String?,
                ownerId: String? = nil,
                permissions: String? = nil,
                backgroundAutoUpload: Bool? = nil) async {
        let metadata = metadata.detachedCopy()
        metadata.ocId = ocId
        metadata.uploadDate = (date as? NSDate) ?? NSDate()
        metadata.etag = etag ?? ""
        metadata.chunk = 0

        if let fileId = self.utility.ocIdToFileId(ocId: ocId) {
            metadata.fileId = fileId
        }

        if let ownerId = ownerId.isNotEmpty {
            metadata.ownerId = ownerId
            if let ownerDisplayName = await NCManageDatabase.shared.getOwnerDisplayName(account: metadata.account, ownerId: ownerId) {
                metadata.ownerDisplayName = ownerDisplayName
            }
        }

        if let permissions = permissions.isNotEmpty {
            metadata.permissions = permissions
        }

        metadata.session = ""
        metadata.sessionError = ""
        metadata.sessionTaskIdentifier = 0
        metadata.status = NCGlobal.shared.metadataStatusNormal

        let item = TransferSuccessItem(metadata: metadata, backgroundAutoUpload: backgroundAutoUpload)

        if let index = tranfersSuccess.firstIndex(where: {
            $0.metadata.account == metadata.account && $0.metadata.ocId == metadata.ocId && $0.metadata.ocIdTransfer == metadata.ocIdTransfer
        }) {
            // A repeated callback without a persistence result must not erase an existing confirmation.
            tranfersSuccess[index] = TransferSuccessItem(metadata: metadata, backgroundAutoUpload: backgroundAutoUpload ?? tranfersSuccess[index].backgroundAutoUpload)
        } else {
            tranfersSuccess.append(item)
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
        tranfersSuccess.count + flushingItems.count
    }

    func getAll() -> [tableMetadata] {
        (tranfersSuccess + flushingItems).map { $0.metadata.detachedCopy() }
    }

    func exists(serverUrlFileName: String, transferIdentifier: String? = nil) async -> Bool {
        return (tranfersSuccess + flushingItems).contains {
            $0.metadata.serverUrlFileName == serverUrlFileName && (transferIdentifier == nil || $0.metadata.ocIdTransfer == transferIdentifier)
        }
    }

    func flush() async {
        guard !isFlushing, !tranfersSuccess.isEmpty else { return }
        isFlushing = true
        let items = tranfersSuccess
        flushingItems = items
        let flushDelegates = delegates
        var committedItems: [TransferSuccessItem] = []
        // Detach this batch before awaiting, so arrivals during the flush remain queued.
        tranfersSuccess.removeAll(keepingCapacity: true)
        let hasLivePhotos = await NCManageDatabase.shared.hasLivePhotos()
        defer {
            flushingItems.removeAll(keepingCapacity: true)
            isFlushing = false
            for delegate in flushDelegates {
                delegate.metadataUploadTransferDidFlush(hasLivePhotos: hasLivePhotos)
            }
        }

        var metadatasLivePhoto: [tableMetadata] = []
        var autoUploads: [tableAutoUploadTransfer] = []

        for delegate in flushDelegates {
            delegate.metadataUploadTransferWillFlush(hasLivePhotos: hasLivePhotos)
        }

        for item in items {
            let metadata = item.metadata
            var backgroundAutoUpload = item.backgroundAutoUpload ?? false
#if !EXTENSION
            do {
                // Retry persistence only when the success callback could not record it.
                if item.backgroundAutoUpload == nil {
                    backgroundAutoUpload = try await NCLocalDatabase.shared.recordAutoUploadTransfer(metadata, uploaded: true)
                    await NCManageDatabase.shared.deleteMetadataAsync(ocId: metadata.ocIdTransfer)
                }
            } catch {
                flushingItems.removeAll { $0.metadata === metadata }
                if !tranfersSuccess.contains(where: {
                    $0.metadata.account == metadata.account && $0.metadata.ocId == metadata.ocId && $0.metadata.ocIdTransfer == metadata.ocIdTransfer
                }) {
                    tranfersSuccess.append(item)
                }
                nkLog(error: "Unable to persist cached background upload completion: \(error)")
                continue
            }
#endif
            committedItems.append(item)
            let results = await NCNetworking.shared.helperMetadataSuccess(metadata: metadata, backgroundAutoUpload: backgroundAutoUpload)
            if let livePhoto = results.livePhoto {
                metadatasLivePhoto.append(livePhoto)
            }
            if let autoUpload = results.autoUpload {
                autoUploads.append(autoUpload)
            }
        }

        let metadatas = committedItems.map(\.metadata)
        await NCManageDatabase.shared.addMetadatasAsync(metadatas)

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
                for item in committedItems {
                    let metadata = item.metadata

                    delegate.transferChange(networkingStatus: NCGlobal.shared.networkingStatusUploaded,
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

        nkLog(tag: NCGlobal.shared.logTagMetadataUploadTransfers, message: "Upload flush successful (\(metadatas.count))", consoleOnly: true)
    }
}
