//
//  NCNetworkingE2EECreateFolder.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/11/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

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
        var fileNameFolder = utility.removeForbiddenCharacters(fileName)
        if fileName != fileNameFolder {
            let errorDescription = String(format: NSLocalizedString("_forbidden_characters_", comment: ""), global.forbiddenCharacters.joined(separator: " "))
            let error = NKError(errorCode: global.errorConflict, errorDescription: errorDescription)
            return error
        }
        let fileNameIdentifier = networkingE2EE.generateRandomIdentifier()
        let serverUrlFileName = serverUrl + "/" + fileNameIdentifier
        fileNameFolder = utilityFileSystem.createFileName(fileNameFolder, serverUrl: serverUrl, account: session.account)
        if fileNameFolder.isEmpty {
            return NKError(errorCode: global.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }
        guard let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) else {
            return NKError(errorCode: global.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        // TEST UPLOAD IN PROGRESS
        //
        if networkingE2EE.isInUpload(account: session.account, serverUrl: serverUrl) {
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
            if let results = self.database.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) {
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
            self.database.addE2eEncryption(object)

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
        let resultsCreateFolder = await NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, account: session.account, options: NKRequestOptions(customHeader: ["e2e-token": e2eToken]))
        guard resultsCreateFolder.error == .success, let ocId = resultsCreateFolder.ocId, let fileId = utility.ocIdToFileId(ocId: ocId) else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            return resultsCreateFolder.error
        }

        // SET FOLDER AS E2EE
        //
        let resultsMarkE2EEFolder = await NextcloudKit.shared.markE2EEFolder(fileId: fileId, delete: false, account: session.account, options: NCNetworkingE2EE().getOptions(account: session.account))
        guard resultsMarkE2EEFolder.error == .success  else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            return resultsMarkE2EEFolder.error
        }

        // UNLOCK
        //
        await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)

        // WRITE DB (DIRECTORY - METADATA)
        //
        let resultsReadFileOrFolder = await NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", account: session.account)
        guard resultsReadFileOrFolder.error == .success, let file = resultsReadFileOrFolder.files?.first else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            return resultsReadFileOrFolder.error
        }
        let metadata = self.database.convertFileToMetadata(file, isDirectoryE2EE: true)
        self.database.addMetadata(metadata)
        self.database.addDirectory(e2eEncrypted: true, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)

        NCNetworking.shared.notifyAllDelegates { delegate in
            delegate.transferChange(status: self.global.networkingStatusCreateFolder,
                                    metadata: tableMetadata(value: metadata),
                                    error: .success)
        }

        return NKError()
    }
}
