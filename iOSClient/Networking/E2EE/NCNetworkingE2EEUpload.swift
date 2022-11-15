//
//  NCNetworkingE2EEUpload.swift
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

class NCNetworkingE2EEUpload: NSObject {
    public static let shared: NCNetworkingE2EEUpload = {
        let instance = NCNetworkingE2EEUpload()
        return instance
    }()

    func upload(metadata: tableMetadata) async -> (NKError) {

        var metadata = tableMetadata.init(value: metadata)
        let ocIdTemp = metadata.ocId
        let errorCreateEncrypted = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_create_encrypted_")

        // Verify max size
        if metadata.size > NCGlobal.shared.e2eeMaxFileSize {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": metadata.ocId, "error": NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "E2E Error file too big")])
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "E2E Error file too big")
        }

        // Create metadata for upload
        if let result = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "serverUrl == %@ AND fileNameView == %@ AND ocId != %@", metadata.serverUrl, metadata.fileNameView, metadata.ocId)) {
            metadata.fileName = result.fileName
        } else {
            metadata.fileName = NCNetworkingE2EE.shared.generateRandomIdentifier()
        }
        metadata.e2eEncrypted = true
        metadata.session = NKCommon.shared.sessionIdentifierUpload
        metadata.sessionError = ""
        guard let result = NCManageDatabase.shared.addMetadata(metadata) else { return errorCreateEncrypted }
        metadata = result

        let lockResults = await NCNetworkingE2EE.shared.lock(account: metadata.account, serverUrl: metadata.serverUrl)
        guard let e2eToken = lockResults.e2eToken, let directory = lockResults.directory, lockResults.error == .success else {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_create_encrypted_")])
            return errorCreateEncrypted
        }

        // Send e2e metadata
        guard await createE2Ee(metadata: metadata, e2eToken: e2eToken, directory: directory) == .success else {
            // Unlock
            await NCNetworkingE2EE.shared.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_create_encrypted_")])
            return errorCreateEncrypted
        }

        // Send file
        let sendFileResults = await sendFile(metadata: metadata, e2eToken: e2eToken)

        // Unlock
        await NCNetworkingE2EE.shared.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        if sendFileResults.afError?.isExplicitlyCancelledError ?? false {

            CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": sendFileResults.error])

        } else if sendFileResults.error == .success, let ocId = sendFileResults.ocId {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NCUtilityFileSystem.shared.moveFileInBackground(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), toPath: CCUtility.getDirectoryProviderStorageOcId(ocId))

            metadata.date = sendFileResults.date ?? NSDate()
            metadata.etag = sendFileResults.etag ?? ""
            metadata.ocId = ocId

            metadata.session = ""
            metadata.sessionError = ""
            metadata.sessionTaskIdentifier = 0
            metadata.status = NCGlobal.shared.metadataStatusNormal

            NCManageDatabase.shared.addMetadata(metadata)
            NCManageDatabase.shared.addLocalFile(metadata: metadata)
            NCUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": sendFileResults.error])

        } else {

            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: sendFileResults.error.errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": sendFileResults.error])
        }

        return(sendFileResults.error)
    }

    private func createE2Ee(metadata: tableMetadata, e2eToken: String, directory: tableDirectory) async -> (NKError) {

        var key: NSString?, initializationVector: NSString?, authenticationTag: NSString?
        let objectE2eEncryption = tableE2eEncryption()
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
        var method = "POST"

        if NCEndToEndEncryption.sharedManager()?.encryptFileName(metadata.fileNameView, fileNameIdentifier: metadata.fileName, directory: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), key: &key, initializationVector: &initializationVector, authenticationTag: &authenticationTag) == false {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": metadata.ocId, "error": NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_create_encrypted_")])
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_create_encrypted_")
        }

        if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            objectE2eEncryption.metadataKey = result.metadataKey
            objectE2eEncryption.metadataKeyIndex = result.metadataKeyIndex
        } else {
            let key = NCEndToEndEncryption.sharedManager()?.generateKey(16) as NSData?
            objectE2eEncryption.metadataKey = key!.base64EncodedString()
            objectE2eEncryption.metadataKeyIndex = 0
        }
        objectE2eEncryption.account = metadata.account
        objectE2eEncryption.authenticationTag = authenticationTag as String?
        objectE2eEncryption.fileName = metadata.fileNameView
        objectE2eEncryption.fileNameIdentifier = metadata.fileName
        objectE2eEncryption.fileNamePath = fileNameLocalPath
        objectE2eEncryption.key = key! as String
        objectE2eEncryption.initializationVector = initializationVector! as String
        objectE2eEncryption.mimeType = metadata.contentType
        objectE2eEncryption.serverUrl = metadata.serverUrl
        objectE2eEncryption.version = 1
        NCManageDatabase.shared.addE2eEncryption(objectE2eEncryption)

        // Get last metadata
        let getE2EEMetadataResults = await  NextcloudKit.shared.getE2EEMetadata(fileId: directory.fileId, e2eToken: e2eToken)
        if getE2EEMetadataResults.error == .success, let e2eMetadata = getE2EEMetadataResults.e2eMetadata {
            if !NCEndToEndMetadata.shared.decoderMetadata(e2eMetadata, privateKey: CCUtility.getEndToEndPrivateKey(metadata.account), serverUrl: metadata.serverUrl, account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId) {
                return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
            }
            method = "PUT"
        }

        // Rebuild metadata
        guard let tableE2eEncryption = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)), let e2eMetadataNew = NCEndToEndMetadata.shared.encoderMetadata(tableE2eEncryption, privateKey: CCUtility.getEndToEndPrivateKey(metadata.account), serverUrl: metadata.serverUrl) else {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
        }

        // send metadata
        let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: directory.fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadataNew, method: method)
        
        return putE2EEMetadataResults.error
    }

    private func sendFile(metadata: tableMetadata, e2eToken: String) async -> (ocId: String?, etag: String?, date: NSDate? ,afError: AFError?, error: NKError) {

        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!

        return await withCheckedContinuation({ continuation in

            NCNetworking.shared.uploadFile(metadata: metadata, fileNameLocalPath:fileNameLocalPath, withUploadComplete: false, addCustomHeaders: ["e2e-token": e2eToken]) {

                NCContentPresenter.shared.noteTop(text: NSLocalizedString("_upload_e2ee_", comment: ""), image: nil, type: NCContentPresenter.messageType.info, delay: NCGlobal.shared.dismissAfterSecond, priority: .max)

            } completion: { account, ocId, etag, date, size, allHeaderFields, afError, error in

                continuation.resume(returning: (ocId: ocId, etag: etag, date: date ,afError: afError, error: error))
            }
        })
    }
}
