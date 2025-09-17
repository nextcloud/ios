// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

class NCNetworkingE2EEDelete: NSObject {
    let database = NCManageDatabase.shared
    let utilityFileSystem = NCUtilityFileSystem()
    let networkingE2EE = NCNetworkingE2EE()

    func delete(metadata: tableMetadata) async -> NKError {
        let session = NCSession.shared.getSession(account: metadata.account)
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
        guard resultsLock.error == .success,
              let e2eToken = resultsLock.e2eToken,
              let fileId = resultsLock.fileId else {
            return resultsLock.error
        }

        // DELETE FILE
        //
        let serverUrlFileName = self.utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
        let options = NKRequestOptions(customHeader: ["e2e-token": e2eToken])
        let result = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: serverUrlFileName, account: metadata.account, options: options) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "deleteFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        if result.error == .success || result.error.errorCode == NCGlobal.shared.errorResourceNotFound {
            do {
                try FileManager.default.removeItem(atPath: NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                await database.deleteVideoAsync(metadata.ocId)
                await database.deleteMetadataAsync(id: metadata.ocId)
                await database.deleteLocalFileAsync(id: metadata.ocId)
                // LIVE PHOTO SERVER
                if let metadataLive = await self.database.getMetadataLivePhotoAsync(metadata: metadata),
                    metadataLive.isFlaggedAsLivePhotoByServer {
                    do {
                        try FileManager.default.removeItem(atPath: NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadataLive.ocId, userId: metadataLive.userId, urlBase: metadataLive.urlBase))
                    } catch { }
                    await self.database.deleteVideoAsync(metadataLive.ocId)
                    await self.database.deleteMetadataAsync(id: metadataLive.ocId)
                    await self.database.deleteLocalFileAsync(id: metadataLive.ocId)
                }
                if metadata.directory {
                    await self.database.deleteDirectoryAndSubDirectoryAsync(serverUrl: self.utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName), account: metadata.account)
                }
            } catch { }
        } else {
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return result.error
        }

        // DOWNLOAD METADATA
        //
        let errorDownloadMetadata = await networkingE2EE.downloadMetadata(serverUrl: metadata.serverUrl, fileId: fileId, e2eToken: e2eToken, session: session)
        guard errorDownloadMetadata == .success else {
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return errorDownloadMetadata
        }

        // UPDATE DB
        //
        await self.database.deleteE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@",
                                                                            metadata.account,
                                                                            metadata.serverUrl,
                                                                            metadata.fileName))

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

        // UNLOCK
        //
        await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        return NKError()
    }
}
