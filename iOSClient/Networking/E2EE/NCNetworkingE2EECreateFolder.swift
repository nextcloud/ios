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
import OpenSSL
import NextcloudKit
import CFNetwork
import Alamofire
import Foundation

class NCNetworkingE2EECreateFolder: NSObject {

    let networkingE2EE = NCNetworkingE2EE()

    func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, userId: String, withPush: Bool) async -> NKError {

        let fileNameIdentifier = networkingE2EE.generateRandomIdentifier()
        let serverUrlFileName = serverUrl + "/" + fileNameIdentifier
        let fileNameFolder = NCUtilityFileSystem.shared.createFileName(CCUtility.removeForbiddenCharactersServer(fileName)!, serverUrl: serverUrl, account: account)
        if fileNameFolder.isEmpty {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate:  NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        func sendE2ee(e2eToken: String, fileId: String) async -> (counter: Int, error: NKError) {

            var key: NSString?
            var initializationVector: NSString?
            var method = "POST"

            // DOWNLOAD METADATA
            //
            let errorDownloadMetadata = await networkingE2EE.downloadMetadata(account: account, serverUrl: serverUrl, urlBase: urlBase, userId: userId, fileId: fileId, e2eToken: e2eToken)
            if errorDownloadMetadata == .success {
                method = "PUT"
            } else if errorDownloadMetadata.errorCode != NCGlobal.shared.errorResourceNotFound {
                return (0, errorDownloadMetadata)
            }

            NCEndToEndEncryption.sharedManager()?.encodedkey(&key, initializationVector: &initializationVector)
            guard let key = key as? String, let initializationVector = initializationVector as? String else {
                return (0, NKError(errorCode: NCGlobal.shared.errorE2EEEncodedKey, errorDescription: NSLocalizedString("_e2e_error_", comment: "")))
            }

            let object = tableE2eEncryption.init(account: account, ocIdServerUrl: directory.ocId, fileNameIdentifier: fileNameIdentifier)
            object.blob = "folders"
            if let results = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
                object.metadataKey = results.metadataKey
                object.metadataKeyIndex = results.metadataKeyIndex
            } else {
                guard let key = NCEndToEndEncryption.sharedManager()?.generateKey() as NSData? else {
                    return (0, NKError(errorCode: NCGlobal.shared.errorE2EEGenerateKey, errorDescription: NSLocalizedString("_e2e_error_", comment: "")))
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
            let resultsUploadMetadata = await networkingE2EE.uploadMetadata(account: account, serverUrl: serverUrl, fileId: fileId, userId: userId, e2eToken: e2eToken, method: method)
            guard resultsUploadMetadata.error == .success else {
                return (0, resultsUploadMetadata.error)
            }

            return (resultsUploadMetadata.counter, resultsUploadMetadata.error)
        }

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: account, serverUrl: serverUrl)
        guard let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId, resultsLock.error == .success else {
            return NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        // CREATE FOLDER
        //
        let resultsCreateFolder = await NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, options: NKRequestOptions(customHeader: ["e2e-token": e2eToken]))
        guard resultsCreateFolder.error == .success else {
            await NCNetworkingE2EE().unlock(account: account, serverUrl: serverUrl)
            return resultsCreateFolder.error
        }

        // SEND NEW METADATA
        //
        let resultsSendE2ee = await sendE2ee(e2eToken: e2eToken, fileId: fileId)
        guard resultsSendE2ee.error == .success else {
            await NCNetworkingE2EE().unlock(account: account, serverUrl: serverUrl)
            return resultsSendE2ee.error
        }

        // COUNTER
        //
        if NCGlobal.shared.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            NCManageDatabase.shared.updateCounterE2eMetadataV2(account: account, ocIdServerUrl: directory.ocId, counter: resultsSendE2ee.counter)
        }

        // UNLOCK
        //
        await networkingE2EE.unlock(account: account, serverUrl: serverUrl)

        return NKError()
    }
}
