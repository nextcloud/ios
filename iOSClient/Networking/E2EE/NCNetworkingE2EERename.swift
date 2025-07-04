// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import UIKit
import Foundation

class NCNetworkingE2EERename: NSObject {
    let database = NCManageDatabase.shared
    let networkingE2EE = NCNetworkingE2EE()
    let utilityFileSystem = NCUtilityFileSystem()

    func rename(metadata: tableMetadata, fileNameNew: String) async -> NKError {
        let session = NCSession.shared.getSession(account: metadata.account)
        // verify if exists the new fileName
        if await self.database.getE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_file_already_exists_")
        }
        guard let directory = await self.database.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_")
        }

        // TEST UPLOAD IN PROGRESS
        //
        if await networkingE2EE.isInUpload(account: metadata.account, serverUrl: metadata.serverUrl) {
            return NKError(errorCode: NCGlobal.shared.errorE2EEUploadInProgress, errorDescription: NSLocalizedString("_e2e_in_upload_", comment: ""))
        }

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: metadata.account, serverUrl: metadata.serverUrl)
        guard resultsLock.error == .success, let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId else { return resultsLock.error }

        // DOWNLOAD METADATA
        //
        let errorDownloadMetadata = await networkingE2EE.downloadMetadata(serverUrl: metadata.serverUrl, fileId: fileId, e2eToken: e2eToken, session: session)
        guard errorDownloadMetadata == .success else {
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return errorDownloadMetadata
        }

        // DB RENAME
        //
        let newFileNamePath = utilityFileSystem.getFileNamePath(fileNameNew, serverUrl: metadata.serverUrl, session: session)
        await self.database.renameFileE2eEncryptionAsync(account: metadata.account, serverUrl: metadata.serverUrl, fileNameIdentifier: metadata.fileName, newFileName: fileNameNew, newFileNamePath: newFileNamePath)

        // UPLOAD METADATA
        //
        let uploadMetadataError = await networkingE2EE.uploadMetadata(serverUrl: metadata.serverUrl,
                                                                      ocIdServerUrl: directory.ocId,
                                                                      fileId: fileId,
                                                                      e2eToken: e2eToken,
                                                                      method: "PUT",
                                                                      session: session)
        guard uploadMetadataError == .success else {
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return uploadMetadataError
        }

        // UPDATE DB
        //
        await self.database.setMetadataFileNameViewAsync(serverUrl: metadata.serverUrl, fileName: metadata.fileName, newFileNameView: fileNameNew, account: metadata.account)

        // MOVE FILE SYSTEM
        //
        let atPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileNameView
        let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
        do {
            try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
        } catch { }

        // UNLOCK
        //
        await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        NCNetworking.shared.notifyAllDelegates { delegate in
            delegate.transferChange(status: NCGlobal.shared.networkingStatusRename,
                                    metadata: metadata,
                                    error: uploadMetadataError)
        }

        return NKError()
    }
}
