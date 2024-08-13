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
import Alamofire
import Foundation

class NCNetworkingE2EECreateFolder: NSObject {
    let networkingE2EE = NCNetworkingE2EE()
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, userId: String, withPush: Bool, sceneIdentifier: String?) async -> NKError {
        var fileNameFolder = utility.removeForbiddenCharacters(fileName)
        if fileName != fileNameFolder {
            let errorDescription = String(format: NSLocalizedString("_forbidden_characters_", comment: ""), NCGlobal.shared.forbiddenCharacters.joined(separator: " "))
            let error = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: errorDescription)
            return error
        }
        let fileNameIdentifier = networkingE2EE.generateRandomIdentifier()
        let serverUrlFileName = serverUrl + "/" + fileNameIdentifier
        fileNameFolder = utilityFileSystem.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        if fileNameFolder.isEmpty {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }
        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        // TEST UPLOAD IN PROGRESS
        //
        if networkingE2EE.isInUpload(account: account, serverUrl: serverUrl) {
            return NKError(errorCode: NCGlobal.shared.errorE2EEUploadInProgress, errorDescription: NSLocalizedString("_e2e_in_upload_", comment: ""))
        }

        func sendE2ee(e2eToken: String, fileId: String) async -> NKError {

            var key: NSString?
            var initializationVector: NSString?
            var method = "POST"

            // DOWNLOAD METADATA
            //
            let errorDownloadMetadata = await networkingE2EE.downloadMetadata(account: account, serverUrl: serverUrl, urlBase: urlBase, userId: userId, fileId: fileId, e2eToken: e2eToken)
            if errorDownloadMetadata == .success {
                method = "PUT"
            } else if errorDownloadMetadata.errorCode != NCGlobal.shared.errorResourceNotFound {
                return errorDownloadMetadata
            }

            NCEndToEndEncryption.shared().encodedkey(&key, initializationVector: &initializationVector)
            guard let key = key as? String, let initializationVector = initializationVector as? String else {
                return NKError(errorCode: NCGlobal.shared.errorE2EEEncodedKey, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
            }

            let object = tableE2eEncryption.init(account: account, ocIdServerUrl: directory.ocId, fileNameIdentifier: fileNameIdentifier)
            object.blob = "folders"
            if let results = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
                object.metadataKey = results.metadataKey
                object.metadataKeyIndex = results.metadataKeyIndex
            } else {
                guard let key = NCEndToEndEncryption.shared().generateKey() as NSData? else {
                    return NKError(errorCode: NCGlobal.shared.errorE2EEGenerateKey, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
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
            NCManageDatabase.shared.addE2eEncryption(object)

            // UPLOAD METADATA
            //
            let uploadMetadataError = await networkingE2EE.uploadMetadata(account: account,
                                                                                   serverUrl: serverUrl,
                                                                                   ocIdServerUrl: directory.ocId,
                                                                                   fileId: fileId,
                                                                                   userId: userId,
                                                                                   e2eToken: e2eToken,
                                                                                   method: method)

            return uploadMetadataError
        }

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: account, serverUrl: serverUrl)
        guard let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId, resultsLock.error == .success else {
            return NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        // SEND NEW METADATA
        //
        let sendE2eeError = await sendE2ee(e2eToken: e2eToken, fileId: fileId)
        guard sendE2eeError == .success else {
            await networkingE2EE.unlock(account: account, serverUrl: serverUrl)
            return sendE2eeError
        }

        // CREATE FOLDER
        //
        let resultsCreateFolder = await NCNetworking.shared.createFolder(serverUrlFileName: serverUrlFileName, account: account, options: NKRequestOptions(customHeader: ["e2e-token": e2eToken]))
        guard resultsCreateFolder.error == .success, let ocId = resultsCreateFolder.ocId, let fileId = utility.ocIdToFileId(ocId: ocId) else {
            await networkingE2EE.unlock(account: account, serverUrl: serverUrl)
            return resultsCreateFolder.error
        }

        // SET FOLDER AS E2EE
        //
        let resultsMarkE2EEFolder = await NCNetworking.shared.markE2EEFolder(fileId: fileId, delete: false, account: account, options: NCNetworkingE2EE().getOptions())
        guard resultsMarkE2EEFolder.error == .success  else {
            await networkingE2EE.unlock(account: account, serverUrl: serverUrl)
            return resultsMarkE2EEFolder.error
        }

        // UNLOCK
        //
        await networkingE2EE.unlock(account: account, serverUrl: serverUrl)

        // WRITE DB (DIRECTORY - METADATA)
        //
        let resultsReadFileOrFolder = await NCNetworking.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", account: account)
        guard resultsReadFileOrFolder.error == .success, let file = resultsReadFileOrFolder.files.first else {
            await networkingE2EE.unlock(account: account, serverUrl: serverUrl)
            return resultsReadFileOrFolder.error
        }
        let metadata = NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: true)
        NCManageDatabase.shared.addMetadata(metadata)
        NCManageDatabase.shared.addDirectory(e2eEncrypted: true, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": ocId, "serverUrl": serverUrl, "account": account, "withPush": withPush, "sceneIdentifier": sceneIdentifier as Any])

        return NKError()
    }
}
