// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import CFNetwork
import Foundation

class NCNetworkingE2EECreateFolder: NSObject {
    let networkingE2EE = NCNetworkingE2EE()
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared

    func createFolder(fileName: String, serverUrl: String, sceneIdentifier: String?, session: NCSession.Session) async -> NKError {
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        var fileNameFolder = FileAutoRenamer.rename(fileName, isFolderPath: true, capabilities: capabilities)

        let fileNameIdentifier = networkingE2EE.generateRandomIdentifier()
        let serverUrlFileName = utilityFileSystem.serverDirectoryDown(serverUrl: serverUrl, fileNameFolder: fileNameIdentifier)
        fileNameFolder = utilityFileSystem.createFileName(fileNameFolder, serverUrl: serverUrl, account: session.account)
        if fileNameFolder.isEmpty {
            return NKError(errorCode: global.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }
        guard let directory = await self.database.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) else {
            return NKError(errorCode: global.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        // TEST UPLOAD IN PROGRESS
        //
        if await networkingE2EE.isInUpload(account: session.account, serverUrl: serverUrl) {
            return NKError(errorCode: global.errorE2EEUploadInProgress, errorDescription: NSLocalizedString("_e2e_in_upload_", comment: ""))
        }

        func sendE2ee(e2eToken: String, fileId: String, session: NCSession.Session) async -> NKError {
            var key: NSString?
            var initializationVector: NSString?
            var method = "POST"

            // DOWNLOAD METADATA
            //
            let errorDownloadMetadata = await networkingE2EE.downloadMetadata(serverUrl: serverUrl, fileId: fileId, e2eToken: e2eToken, session: session)
            if errorDownloadMetadata == .success {
                method = "PUT"
            } else if errorDownloadMetadata.errorCode != global.errorResourceNotFound {
                return errorDownloadMetadata
            }

            NCEndToEndEncryption.shared().encodedkey(&key, initializationVector: &initializationVector)
            guard let key = key as? String, let initializationVector = initializationVector as? String else {
                return NKError(errorCode: global.errorE2EEEncodedKey, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
            }

            let object = tableE2eEncryption.init(account: session.account, ocIdServerUrl: directory.ocId, fileNameIdentifier: fileNameIdentifier)
            object.blob = "folders"
            if let results = await self.database.getE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) {
                object.metadataKey = results.metadataKey
                object.metadataKeyIndex = results.metadataKeyIndex
            } else {
                guard let key = NCEndToEndEncryption.shared().generateKey() as NSData? else {
                    return NKError(errorCode: global.errorE2EEGenerateKey, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
                }
                object.metadataKey = key.base64EncodedString()
                object.metadataKeyIndex = 0
            }
            object.authenticationTag = ""
            object.fileName = fileNameFolder
            object.key = key
            object.initializationVector = initializationVector
            object.mimeType = "httpd/unix-directory"
            object.serverUrl = serverUrl
            await self.database.addE2eEncryptionAsync(object)

            // UPLOAD METADATA
            //
            let uploadMetadataError = await networkingE2EE.uploadMetadata(serverUrl: serverUrl,
                                                                          ocIdServerUrl: directory.ocId,
                                                                          fileId: fileId,
                                                                          e2eToken: e2eToken,
                                                                          method: method,
                                                                          session: session)

            return uploadMetadataError
        }

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: session.account, serverUrl: serverUrl)
        guard let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId, resultsLock.error == .success else {
            return NKError(errorCode: global.errorE2EELock, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        // SEND NEW METADATA
        //
        let sendE2eeError = await sendE2ee(e2eToken: e2eToken, fileId: fileId, session: session)
        guard sendE2eeError == .success else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            return sendE2eeError
        }

        // CREATE FOLDER
        //
        let resultsCreateFolder = await NextcloudKit.shared.createFolderAsync(serverUrlFileName: serverUrlFileName, account: session.account, options: NKRequestOptions(customHeader: ["e2e-token": e2eToken]))
        guard resultsCreateFolder.error == .success, let ocId = resultsCreateFolder.ocId, let fileId = utility.ocIdToFileId(ocId: ocId) else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            return resultsCreateFolder.error
        }

        // SET FOLDER AS E2EE
        //
        let resultsMarkE2EEFolder = await NextcloudKit.shared.markE2EEFolderAsync(fileId: fileId, delete: false, account: session.account, options: NCNetworkingE2EE().getOptions(account: session.account, capabilities: capabilities))
        guard resultsMarkE2EEFolder.error == .success  else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            return resultsMarkE2EEFolder.error
        }

        // UNLOCK
        //
        await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)

        // WRITE DB (DIRECTORY - METADATA)
        //
        let resultsReadFileOrFolder = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName, depth: "0", account: session.account)
        guard resultsReadFileOrFolder.error == .success, let file = resultsReadFileOrFolder.files?.first else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            return resultsReadFileOrFolder.error
        }
        let metadata = await self.database.convertFileToMetadataAsync(file)
        await self.database.addMetadataAsync(metadata)
        await self.database.addDirectoryAsync(serverUrl: serverUrlFileName,
                                              ocId: metadata.ocId,
                                              fileId: metadata.fileId,
                                              permissions: metadata.permissions,
                                              favorite: metadata.favorite,
                                              account: metadata.account)

        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: self.global.networkingStatusCreateFolder,
                                    metadata: metadata.detachedCopy(),
                                    error: .success)
        }

        return NKError()
    }
}
