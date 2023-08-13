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

    let errorEncodeMetadata = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))

    func createFolderAndMarkE2EE(fileName: String, serverUrl: String, account: String, userId: String) async -> NKError {

        let serverUrlFileName = serverUrl + "/" + fileName
        var error = NKError()

        // CREATE FOLDER
        let createFolderResults = await NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName)
        if createFolderResults.error != .success { return createFolderResults.error }

        let readFileOrFolderResults = await NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0")
        error = readFileOrFolderResults.error
        if error == .success, let file = readFileOrFolderResults.files.first {

            // MARK AS E2EE
            let markE2EEFolderResults = await NextcloudKit.shared.markE2EEFolder(fileId: file.fileId, delete: false)
            if markE2EEFolderResults.error != .success { return markE2EEFolderResults.error }

            file.e2eEncrypted = true
            let isDirectoryE2EE = NCUtility.shared.isDirectoryE2EE(file: file)
            guard let metadata = NCManageDatabase.shared.addMetadata(NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)) else {
                return error
            }
            NCManageDatabase.shared.addDirectory(encrypted: true, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)
            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrlFileName))

            // LOCK
            let lockResults = await NCNetworkingE2EE.shared.lock(account: account, serverUrl: serverUrlFileName)
            if lockResults.error != .success { return lockResults.error }

            let resultEncoder = NCEndToEndMetadata().encoderMetadata(account: account, serverUrl: serverUrlFileName, userId: userId)
            if resultEncoder.metadata == nil {
                return errorEncodeMetadata
            }

            let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: file.fileId, e2eToken: lockResults.e2eToken!, e2eMetadata: resultEncoder.metadata, signature: resultEncoder.signature, method: "POST")
            error = putE2EEMetadataResults.error

            // UNLOCK
            await NCNetworkingE2EE.shared.unlock(account: account, serverUrl: serverUrlFileName)

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl": serverUrl])
        }

        return error
    }

    func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, userId: String, withPush: Bool) async -> (NKError) {

        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        var serverUrlFileName = ""
        var fileNameIdentifier = ""
        var ocId: String?
        var error = NKError()

        fileNameFolder = NCUtilityFileSystem.shared.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        if fileNameFolder.isEmpty { return error }
        fileNameIdentifier = NCNetworkingE2EE.shared.generateRandomIdentifier()
        serverUrlFileName = serverUrl + "/" + fileNameIdentifier

        // ** Lock **
        let lockResults = await NCNetworkingE2EE.shared.lock(account: account, serverUrl: serverUrl)

        error = lockResults.error
        if error == .success, let e2eToken = lockResults.e2eToken, let fileIdLock = lockResults.fileId {

            let createFolderResults = await NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, options: NKRequestOptions(customHeader: ["e2e-token": e2eToken]))
            error = createFolderResults.error
            ocId = createFolderResults.ocId
            if error == .success, let fileId = NCUtility.shared.ocIdToFileId(ocId: ocId) {
                // Mark folder as E2EE
                let markE2EEFolderResults = await NextcloudKit.shared.markE2EEFolder(fileId: fileId, delete: false)
                error = markE2EEFolderResults.error
                if error == .success {
                    error = await createE2Ee(e2eToken: e2eToken, fileIdLock: fileIdLock, account: account, fileNameFolder: fileNameFolder, fileNameIdentifier: fileNameIdentifier, serverUrl: serverUrl, ocIdServerUrl: ocId!, urlBase: urlBase, userId: userId)
                }
            }
        }

        // ** Unlock **
        await NCNetworkingE2EE.shared.unlock(account: account, serverUrl: serverUrl)
        
        if error == .success, let ocId = ocId {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": ocId, "serverUrl": serverUrl, "account": account, "e2ee": true, "withPush": withPush])
        }
        return error
    }

    private func createE2Ee(e2eToken: String, fileIdLock: String, account: String, fileNameFolder: String, fileNameIdentifier: String, serverUrl: String, ocIdServerUrl: String, urlBase: String, userId: String) async -> (NKError) {

        var key: NSString?
        var initializationVector: NSString?
        var method = "POST"

        // Get last metadata
        let results = await NextcloudKit.shared.getE2EEMetadata(fileId: fileIdLock, e2eToken: e2eToken)
        if results.error == .success, let e2eMetadata = results.e2eMetadata {
            let error = NCEndToEndMetadata().decoderMetadata(e2eMetadata, signature: results.signature, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId, ownerId: nil)
            if error != .success { return error }
            method = "PUT"
        }

        // Add new metadata
        NCEndToEndEncryption.sharedManager()?.encodedkey(&key, initializationVector: &initializationVector)

        let object = tableE2eEncryption.init(account: account, ocIdServerUrl: ocIdServerUrl, fileNameIdentifier: fileNameIdentifier)
        object.authenticationTag = ""
        object.fileName = fileNameFolder
        object.key = key! as String
        object.initializationVector = initializationVector! as String
        if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
            object.metadataKey = result.metadataKey
            object.metadataKeyIndex = result.metadataKeyIndex
        } else {
            object.metadataKey = (NCEndToEndEncryption.sharedManager()?.generateKey()?.base64EncodedString(options: []))! as String // AES_KEY_128_LENGTH
            object.metadataKeyIndex = 0
        }
        object.mimeType = "httpd/unix-directory"
        object.serverUrl = serverUrl
        NCManageDatabase.shared.addE2eEncryption(object)

        let resultEncoder = NCEndToEndMetadata().encoderMetadata(account: account, serverUrl: serverUrl, userId: userId)
        if resultEncoder.metadata == nil {
            return errorEncodeMetadata
        }

        // send metadata
        let putE2EEMetadataResults =  await NextcloudKit.shared.putE2EEMetadata(fileId: fileIdLock, e2eToken: e2eToken, e2eMetadata: resultEncoder.metadata, signature: resultEncoder.signature, method: method)
        return putE2EEMetadataResults.error
    }

    func markE2EEFolder(account: String, serverUrl: String, fileId: String, ocId: String, userId: String) async -> (NKError) {

        let markE2EEFolderResult = await NextcloudKit.shared.markE2EEFolder(fileId: fileId, delete: false)
        if markE2EEFolderResult.error != .success { return markE2EEFolderResult.error }

        NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))
        NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: true, richWorkspace: nil, account: account)
        NCManageDatabase.shared.setMetadataEncrypted(ocId: ocId, encrypted: true)

        // LOCK
        let lockResults = await NCNetworkingE2EE.shared.lock(account: account, serverUrl: serverUrl)
        if lockResults.error != .success { return lockResults.error }

        let resultEncoder = NCEndToEndMetadata().encoderMetadata(account: account, serverUrl: serverUrl, userId: userId)
        if resultEncoder.metadata == nil {
            return errorEncodeMetadata
        }
        
        let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: lockResults.e2eToken!, e2eMetadata: resultEncoder.metadata, signature: resultEncoder.signature, method: "POST")
        let error = putE2EEMetadataResults.error

        // UNLOCK
        await NCNetworkingE2EE.shared.unlock(account: account, serverUrl: serverUrl)

        return error
    }
}
