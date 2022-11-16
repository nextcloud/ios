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
    public static let shared: NCNetworkingE2EECreateFolder = {
        let instance = NCNetworkingE2EECreateFolder()
        return instance
    }()

    func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, userId: String) async -> (NKError) {

        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        var serverUrlFileName = ""
        var fileNameIdentifier = ""
        var ocId: String?
        var error = NKError()

        fileNameFolder = NCUtilityFileSystem.shared.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        if fileNameFolder.isEmpty { return error }
        fileNameIdentifier = NCNetworkingE2EE.shared.generateRandomIdentifier()
        serverUrlFileName = serverUrl + "/" + fileNameIdentifier

        // Lock
        let lockResults = await NCNetworkingE2EE.shared.lock(account: account, serverUrl: serverUrl)
        error = lockResults.error
        if error == .success, let e2eToken = lockResults.e2eToken {

            let createFolderResults = await NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, options: NKRequestOptions(customHeader: ["e2e-token": e2eToken]))
            error = createFolderResults.error
            ocId = createFolderResults.ocId
            if error == .success, let fileId = NCUtility.shared.ocIdToFileId(ocId: createFolderResults.ocId) {
                // Mark folder as E2EE
                let markE2EEFolderResults = await NextcloudKit.shared.markE2EEFolder(fileId: fileId, delete: false)
                error = markE2EEFolderResults.error
                if error == .success {
                    error = await createE2Ee(account: account, fileNameFolder: fileNameFolder, fileNameIdentifier: fileNameIdentifier, serverUrl: serverUrl, e2eToken: e2eToken, fileId: fileId ,urlBase: urlBase, userId: userId)
                }
            }

            // Unlock
            await NCNetworkingE2EE.shared.unlock(account: account, serverUrl: serverUrl)
        }

        if error == .success, let ocId = ocId {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": ocId, "serverUrl": serverUrl, "account": account, "e2ee": true])
        }
        return error
    }

    private func createE2Ee(account: String, fileNameFolder: String, fileNameIdentifier: String, serverUrl: String, e2eToken: String, fileId: String, urlBase: String, userId: String) async -> (NKError) {

        var key: NSString?
        var initializationVector: NSString?
        let object = tableE2eEncryption()
        var method = "POST"

        // Get last metadata
        let getE2EEMetadataResults = await NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken)
        if getE2EEMetadataResults.error == .success, let e2eMetadata = getE2EEMetadataResults.e2eMetadata {
            if !NCEndToEndMetadata.shared.decoderMetadata(e2eMetadata, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId) {
                return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
            }
            method = "PUT"
        }

        // Add new metadata
        NCEndToEndEncryption.sharedManager()?.encryptkey(&key, initializationVector: &initializationVector)
        object.account = account
        object.authenticationTag = nil
        object.fileName = fileNameFolder
        object.fileNameIdentifier = fileNameIdentifier
        object.fileNamePath = ""
        object.key = key! as String
        object.initializationVector = initializationVector! as String
        if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
            object.metadataKey = result.metadataKey
            object.metadataKeyIndex = result.metadataKeyIndex
        } else {
            object.metadataKey = (NCEndToEndEncryption.sharedManager()?.generateKey(16)?.base64EncodedString(options: []))! as String // AES_KEY_128_LENGTH
            object.metadataKeyIndex = 0
        }
        object.mimeType = "httpd/unix-directory"
        object.serverUrl = serverUrl
        object.version = 1
        NCManageDatabase.shared.addE2eEncryption(object)

        // Rebuild metadata
        guard let tableE2eEncryption = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)), let e2eMetadataNew = NCEndToEndMetadata.shared.encoderMetadata(tableE2eEncryption, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: serverUrl) else {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
        }

        // send metadata
        let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadataNew, method: method)
        
        return putE2EEMetadataResults.error
    }

    func createFolderAndMarkE2EE(fileName: String, serverUrl: String) async -> NKError {

        let serverUrlFileName = serverUrl + "/" + fileName
        var error = NKError()

        let createFolderResults = await NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName)
        if createFolderResults.error != .success { return createFolderResults.error }

        let readFileOrFolderResults = await NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0")
        error = readFileOrFolderResults.error
        if error == .success, let file = readFileOrFolderResults.files.first {

            let markE2EEFolderResults = await NextcloudKit.shared.markE2EEFolder(fileId: file.fileId, delete: false)
            if markE2EEFolderResults.error != .success { return markE2EEFolderResults.error }

            file.e2eEncrypted = true
            guard let metadata = NCManageDatabase.shared.addMetadata(NCManageDatabase.shared.convertNCFileToMetadata(file, account: readFileOrFolderResults.account)) else {
                return error
            }
            NCManageDatabase.shared.addDirectory(encrypted: true, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)
            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrlFileName))

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl": serverUrl])
        }

        return error
    }
}
