// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

public protocol NCMetadataDownloadTransfersSuccessDelegate: AnyObject {
    func metadataDownloadTransferWillFlush()
    func metadataDownloadTransferDidFlush()
}

actor NCMetadataDownloadTranfersSuccess {
    private struct TransferSuccessItem {
        let metadata: tableMetadata
    }

    private var tranfersSuccess: [TransferSuccessItem] = []
    private let utility = NCUtility()
    private var delegates: [NCMetadataDownloadTransfersSuccessDelegate] = []

    // Adds a new delegate
    func addDelegate(_ delegate: NCMetadataDownloadTransfersSuccessDelegate) {
        delegates.append(delegate)
    }

    // Removes a delegate
    func removeDelegate(_ delegate: NCMetadataDownloadTransfersSuccessDelegate) {
        delegates.removeAll { $0 as AnyObject === delegate as AnyObject }
    }

    func append(metadata: tableMetadata, etag: String?) async {
        metadata.session = ""
        metadata.sessionError = ""
        metadata.sessionTaskIdentifier = 0
        metadata.status = NCGlobal.shared.metadataStatusNormal
        if let etag = etag {
            metadata.etag = etag
        }

        let item = TransferSuccessItem(metadata: metadata)

        if let index = tranfersSuccess.firstIndex(where: { $0.metadata.ocId == metadata.ocId }) {
            tranfersSuccess[index] = item
        } else {
            tranfersSuccess.append(item)
        }
    }

    func count() -> Int {
        tranfersSuccess.count
    }

    func getAll() -> [tableMetadata] {
        tranfersSuccess.map(\.metadata)
    }

    func exists(serverUrlFileName: String) async -> Bool {
        return tranfersSuccess.contains { $0.metadata.serverUrlFileName == serverUrlFileName }
    }

    func flush() async {
        let items = tranfersSuccess
        let metadatas = items.map(\.metadata)
        tranfersSuccess.removeAll(keepingCapacity: true)

        var metadatasLocalFiles: [tableMetadata] = []

        for delegate in delegates {
            delegate.metadataDownloadTransferWillFlush()
        }

        for metadata in metadatas {
            // E2EE
            if let result = await NCManageDatabase.shared.getE2eEncryptionAsync(
                predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@",
                                       metadata.fileName,
                                       metadata.serverUrl)
            ) {
                NCEndToEndEncryption.shared().decryptFile(metadata.fileName,
                                                          fileNameView: metadata.fileNameView,
                                                          ocId: metadata.ocId,
                                                          userId: metadata.userId,
                                                          urlBase: metadata.urlBase,
                                                          key: result.key,
                                                          initializationVector: result.initializationVector,
                                                          authenticationTag: result.authenticationTag)
            }

            metadatasLocalFiles.append(metadata)

        }

        // added metadatas
        await NCManageDatabase.shared.addMetadatasAsync(metadatas)
        // Local File
        await NCManageDatabase.shared.addLocalFilesAsync(metadatas: metadatasLocalFiles)

        if !NCNetworking.shared.isInBackground() {
            // TransferDispatcher — notify outside of shared-state mutation
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                for item in items {
                    let metadata = item.metadata
                    delegate.transferChange(networkingStatus: NCGlobal.shared.networkingStatusDownloaded,
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
            delegate.metadataDownloadTransferDidFlush()
        }

        nkLog(tag: NCGlobal.shared.logTagMetadataDownloadTransfers, message: "Download flush successful (\(metadatas.count))", consoleOnly: true)
    }
}
