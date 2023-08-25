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

protocol uploadE2EEDelegate: AnyObject {
    func start()
    func uploadE2EEProgress(_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double)
}

extension uploadE2EEDelegate {
    func start() { }
    func uploadE2EEProgress(_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) {}
}

class NCNetworkingE2EEUpload: NSObject {

    let networkingE2EE = NCNetworkingE2EE()

    func upload(metadata: tableMetadata, uploadE2EEDelegate: uploadE2EEDelegate? = nil) async -> (NKError) {

        var metadata = tableMetadata.init(value: metadata)
        let ocIdTemp = metadata.ocId
        let account = metadata.account
        let serverUrl = metadata.serverUrl

        defer {
            Task {
                await networkingE2EE.unlock(account: account, serverUrl: serverUrl)
            }
        }

        // Create metadata for upload
        if let result = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "serverUrl == %@ AND fileNameView == %@ AND ocId != %@", metadata.serverUrl, metadata.fileNameView, metadata.ocId)) {
            metadata.fileName = result.fileName
        } else {
            metadata.fileName = networkingE2EE.generateRandomIdentifier()
        }
        metadata.session = NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload
        metadata.sessionError = ""
        guard let result = NCManageDatabase.shared.addMetadata(metadata) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
            
        }
        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate:  NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }
        metadata = result

        let resultsLock = await networkingE2EE.lock(account: metadata.account, serverUrl: metadata.serverUrl)

        guard let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId, resultsLock.error == .success else {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))])
            return NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        let resultsSendE2ee = await sendE2ee(metadata: metadata, e2eToken: e2eToken, ocIdServerUrl: directory.ocId, fileId: fileId)
        guard resultsSendE2ee.error == .success else {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": resultsSendE2ee])
            return resultsSendE2ee.error
        }

        // COUNTER
        if NCGlobal.shared.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            NCManageDatabase.shared.updateCounterE2eMetadataV2(account: metadata.account, ocIdServerUrl: directory.ocId, counter: resultsSendE2ee.counter)
        }

        let resultsSendFile = await sendFile(metadata: metadata, e2eToken: e2eToken, uploadE2EEDelegate: uploadE2EEDelegate)
        if let afError = resultsSendFile.afError, afError.isExplicitlyCancelledError {

            CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": resultsSendFile.error])

        } else if resultsSendFile.error == .success, let ocId = resultsSendFile.ocId {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NCUtilityFileSystem.shared.moveFileInBackground(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), toPath: CCUtility.getDirectoryProviderStorageOcId(ocId))

            metadata.date = resultsSendFile.date ?? NSDate()
            metadata.etag = resultsSendFile.etag ?? ""
            metadata.ocId = ocId
            metadata.chunk = 0

            metadata.session = ""
            metadata.sessionError = ""
            metadata.sessionTaskIdentifier = 0
            metadata.status = NCGlobal.shared.metadataStatusNormal

            NCManageDatabase.shared.addMetadata(metadata)
            NCManageDatabase.shared.addLocalFile(metadata: metadata)
            NCUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": resultsSendFile.error])

        } else {

            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: resultsSendFile.error.errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": resultsSendFile.error])
        }

        return (resultsSendFile.error)
    }

    private func sendE2ee(metadata: tableMetadata, e2eToken: String, ocIdServerUrl: String, fileId: String) async -> (counter: Int, error: NKError) {

        var key: NSString?, initializationVector: NSString?, authenticationTag: NSString?
        var method = "POST"

        if NCEndToEndEncryption.sharedManager()?.encryptFile(metadata.fileNameView, fileNameIdentifier: metadata.fileName, directory: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), key: &key, initializationVector: &initializationVector, authenticationTag: &authenticationTag) == false {
            return (0, NKError(errorCode: NCGlobal.shared.errorE2EEEncryptFile, errorDescription: NSLocalizedString("_e2e_error_", comment: "")))
        }

        let resultGetE2EEMetadata = await NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken)
        if resultGetE2EEMetadata.error == .success, let e2eMetadata = resultGetE2EEMetadata.e2eMetadata {
            let errorDecodeMetadata = NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: resultGetE2EEMetadata.signature, serverUrl: metadata.serverUrl, account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId, ownerId: metadata.ownerId)
            guard errorDecodeMetadata == .success else { return (0, errorDecodeMetadata) }
            method = "PUT"
        }

        // [REPLACE]
        NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileNameView))

        // Add new metadata
        let object = tableE2eEncryption.init(account: metadata.account, ocIdServerUrl: ocIdServerUrl, fileNameIdentifier: metadata.fileName)
        if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            object.metadataKey = result.metadataKey
            object.metadataKeyIndex = result.metadataKeyIndex
        } else {
            let key = NCEndToEndEncryption.sharedManager()?.generateKey() as NSData?
            object.metadataKey = key!.base64EncodedString()
            object.metadataKeyIndex = 0
        }
        object.authenticationTag = authenticationTag! as String
        object.fileName = metadata.fileNameView
        object.key = key! as String
        object.initializationVector = initializationVector! as String
        object.mimeType = metadata.contentType
        object.serverUrl = metadata.serverUrl
        NCManageDatabase.shared.addE2eEncryption(object)

        let resultsEncodeMetadata = NCEndToEndMetadata().encodeMetadata(account: metadata.account, serverUrl: metadata.serverUrl, userId: metadata.userId)
        guard resultsEncodeMetadata.error == .success, let e2eMetadata = resultsEncodeMetadata.metadata else { return (0, resultsEncodeMetadata.error) }

        let resultsPutE2EEMetadata = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, signature: resultsEncodeMetadata.signature, method: method)

        return (resultsEncodeMetadata.counter, resultsPutE2EEMetadata.error)
    }

    private func sendFile(metadata: tableMetadata, e2eToken: String, uploadE2EEDelegate: uploadE2EEDelegate? = nil) async -> (ocId: String?, etag: String?, date: NSDate? ,afError: AFError?, error: NKError) {

        if metadata.chunk > 0 {

            return await withCheckedContinuation({ continuation in
                NCNetworking.shared.uploadChunkFile(metadata: metadata, withUploadComplete: false, addCustomHeaders: ["e2e-token": e2eToken]) {
                    uploadE2EEDelegate?.start()
                } progressHandler: { totalBytesExpected, totalBytes, fractionCompleted in
                    uploadE2EEDelegate?.uploadE2EEProgress(totalBytesExpected, totalBytes, fractionCompleted)
                } completion: { account, file, afError, error in
                    continuation.resume(returning: (ocId: file?.ocId, etag: file?.etag, date: file?.date ,afError: afError, error: error))
                }
            })

        } else {

            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
            return await withCheckedContinuation({ continuation in
                NCNetworking.shared.uploadFile(metadata: metadata, fileNameLocalPath: fileNameLocalPath, withUploadComplete: false, addCustomHeaders: ["e2e-token": e2eToken]) {
                    uploadE2EEDelegate?.start()
                } progressHandler: { totalBytesExpected, totalBytes, fractionCompleted in
                    uploadE2EEDelegate?.uploadE2EEProgress(totalBytesExpected, totalBytes, fractionCompleted)
                } completion: { account, ocId, etag, date, size, allHeaderFields, afError, error in
                    continuation.resume(returning: (ocId: ocId, etag: etag, date: date ,afError: afError, error: error))
                }
            })
        }
    }
}
