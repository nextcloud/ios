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

@objc class NCNetworkingE2EEUpload: NSObject {
    @objc public static let shared: NCNetworkingE2EEUpload = {
        let instance = NCNetworkingE2EEUpload()
        return instance
    }()

    func upload(metadata: tableMetadata, filename: String) async -> (NKError) {

        let ocIdTemp = metadata.ocId
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
        let errorCreateEncrypted = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_create_encrypted_")

        // Verify max size
        if metadata.size > NCGlobal.shared.e2eeMaxFileSize {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": metadata.ocId, "error": NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "E2E Error file too big")])

            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "E2E Error file too big")
        }

        // Update metadata
        var metadata = tableMetadata.init(value: metadata)
        metadata.fileName = filename //CCUtility.generateRandomIdentifier()!
        metadata.e2eEncrypted = true
        metadata.session = NKCommon.shared.sessionIdentifierUpload
        metadata.sessionError = ""
        guard let result = NCManageDatabase.shared.addMetadata(metadata) else { return errorCreateEncrypted }
        metadata = result

        // Create E2E metadata
        let results = await createE2Ee(metadata: metadata)
        guard let e2eToken = results.e2eToken, results.error == .success else {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_create_encrypted_")])
            return errorCreateEncrypted
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": metadata.serverUrl])
        NCContentPresenter.shared.noteTop(text: NSLocalizedString("_upload_e2ee_", comment: ""), image: nil, type: NCContentPresenter.messageType.info, delay: NCGlobal.shared.dismissAfterSecond, priority: .max)

        let errorReturn = await withCheckedContinuation({ continuation in

            NCNetworking.shared.uploadFile(metadata: metadata, addCustomHeaders: ["e2e-token": e2eToken]) {
            } completion: { account, ocId, etag, date, size, allHeaderFields, afError, error in

                NCNetworking.shared.uploadRequest.removeValue(forKey: fileNameLocalPath)
                let metadata = tableMetadata.init(value: metadata)

                if afError?.isExplicitlyCancelledError ?? false {

                    CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))

                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": error])

                } else if error == .success, let ocId = ocId {

                    NCUtilityFileSystem.shared.moveFileInBackground(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), toPath: CCUtility.getDirectoryProviderStorageOcId(ocId))

                    metadata.date = date ?? NSDate()
                    metadata.etag = etag ?? ""
                    metadata.ocId = ocId

                    metadata.session = ""
                    metadata.sessionError = ""
                    metadata.sessionTaskIdentifier = 0
                    metadata.status = NCGlobal.shared.metadataStatusNormal

                    NCManageDatabase.shared.addMetadata(metadata)
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
                    NCManageDatabase.shared.addLocalFile(metadata: metadata)

                    NCUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)

                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": error])

                } else {

                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: error.errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)

                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": error])
                }

                continuation.resume(returning: error)
            }
        })

        await NCNetworkingE2EE.shared.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        return(errorReturn)
    }

    private func createE2Ee(metadata: tableMetadata) async -> (e2eToken: String?, error: NKError) {

        var key: NSString?, initializationVector: NSString?, authenticationTag: NSString?
        let objectE2eEncryption = tableE2eEncryption()
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!

        if NCEndToEndEncryption.sharedManager()?.encryptFileName(metadata.fileNameView, fileNameIdentifier: metadata.fileName, directory: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), key: &key, initializationVector: &initializationVector, authenticationTag: &authenticationTag) == false {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": metadata.ocId, "error": NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_create_encrypted_")])

            return (nil, NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_create_encrypted_"))
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

        return await NCNetworkingE2EE.shared.sendE2EMetadata(account: metadata.account, serverUrl: metadata.serverUrl, fileNameRename: nil, fileNameNewRename: nil, deleteE2eEncryption: nil, urlBase: metadata.urlBase, userId: metadata.userId, upload: true)
    }
}
