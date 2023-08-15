//
//  NCEndToEndMetadataV20.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/08/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

import Foundation
import NextcloudKit
import Gzip

extension NCEndToEndMetadata {

    // --------------------------------------------------------------------------------------------
    // MARK: Ecode JSON Metadata V2.0
    // --------------------------------------------------------------------------------------------

    func encoderMetadataV20(account: String, serverUrl: String, ocIdServerUrl: String, userId: String, addUserId: String?, addCertificate: String?) -> (metadata: String?, signature: String?) {

        guard let keyGenerated = NCEndToEndEncryption.sharedManager()?.generateKey() as? Data,
              let directoryTop = NCUtility.shared.getDirectoryE2EETop(serverUrl: serverUrl, account: account) else {
            return (nil, nil)
        }

        let isDirectoryTop = NCUtility.shared.isDirectoryE2EETop(serverUrl: serverUrl, account: account)
        var metadataKey: String?
        var keyChecksums: [String] = []

        var usersCodable: [E2eeV20.Users] = []
        var filedropCodable: [String: E2eeV20.Filedrop] = [:]
        var e2eeJson: String?
        var signature: String?

        // USERS

        func addUser(userId: String?, certificate: String?) {

            guard let userId, let certificate else { return }
            let decryptedMetadataKey = keyGenerated
            let metadataKey = keyGenerated.base64EncodedString()

            if let metadataKeyEncrypted = NCEndToEndEncryption.sharedManager().encryptAsymmetricData(keyGenerated, certificate: certificate) {

                let encryptedMetadataKey = metadataKeyEncrypted.base64EncodedString()
                NCManageDatabase.shared.addE2EUsersV2(account: account, serverUrl: serverUrl, ocIdServerUrl: ocIdServerUrl, userId: userId, certificate: certificate, encryptedFiledropKey: nil, encryptedMetadataKey: encryptedMetadataKey, decryptedFiledropKey: nil, decryptedMetadataKey: decryptedMetadataKey, filedropKey: nil, metadataKey: metadataKey)
            }
        }

        if isDirectoryTop {

            addUser(userId: userId, certificate: CCUtility.getEndToEndCertificate(account))
            addUser(userId: addUserId, certificate: addCertificate)

            if let users = NCManageDatabase.shared.getE2EUsersV2(account: account, ocIdServerUrl: ocIdServerUrl) {
                for user in users {
                    addUser(userId: user.userId, certificate: user.certificate)
                }
            }
        }

        if let e2eUsers = NCManageDatabase.shared.getE2EUsersV2(account: account, ocIdServerUrl: directoryTop.ocId) {
            for user in e2eUsers {
                if isDirectoryTop {
                    usersCodable.append(E2eeV20.Users(userId: user.userId, certificate: user.certificate, encryptedMetadataKey: user.encryptedMetadataKey, encryptedFiledropKey: user.encryptedFiledropKey))
                }
                if let hash = NCEndToEndEncryption.sharedManager().createSHA256(user.decryptedMetadataKey) {
                    keyChecksums.append(hash)
                }
                if let addUserId, user.userId == addUserId {
                    metadataKey = user.metadataKey
                } else if user.userId == userId {
                    metadataKey = user.metadataKey
                }
            }
        }

        // tableE2eMetadataV2
        guard let e2eMetadataV2 = NCManageDatabase.shared.incrementCounterE2eMetadataV2(account: account, serverUrl: serverUrl, ocIdServerUrl: ocIdServerUrl, version: "2.0") else {
            return (nil, nil)
        }

        // Create ciphertext
        let e2eEncryptions = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))
        var filesCodable: [String: E2eeV20.Files] = [:]

        for e2eEncryption in e2eEncryptions {
            if e2eEncryption.blob == "files" {
                let file = E2eeV20.Files(authenticationTag: e2eEncryption.authenticationTag, filename: e2eEncryption.fileName, key: e2eEncryption.key, mimetype: e2eEncryption.mimeType, nonce: e2eEncryption.initializationVector)
                filesCodable.updateValue(file, forKey: e2eEncryption.fileNameIdentifier)
            }
        }

        let ciphertext = E2eeV20.ciphertext(counter: e2eMetadataV2.counter, deleted: false, keyChecksums: keyChecksums, files: filesCodable, folders: [:])
        var authenticationTag: NSString?
        var initializationVector: NSString?

        do {

            // CIPHERTEXT

            let json = try JSONEncoder().encode(ciphertext)
            let jsonZip = try json.gzipped()
            let ciphertext = NCEndToEndEncryption.sharedManager().encryptPayloadFile(jsonZip, key: metadataKey, initializationVector: &initializationVector, authenticationTag: &authenticationTag)

            guard var ciphertext, let initializationVector = initializationVector as? String, let authenticationTag = authenticationTag as? String else {
                return (nil, nil)
            }

            // Add initializationVector [ANDROID]
            ciphertext = ciphertext + "|" + initializationVector

            let metadataCodable = E2eeV20.Metadata(ciphertext: ciphertext, nonce: initializationVector, authenticationTag: authenticationTag)

            let e2eeCodable = E2eeV20(metadata: metadataCodable, users: usersCodable, filedrop: filedropCodable, version: "2.0")
            let e2eeData = try JSONEncoder().encode(e2eeCodable)
            e2eeData.printJson()
            e2eeJson = String(data: e2eeData, encoding: .utf8)
            print("")

        } catch let error {
            print("Serious internal error in encoding e2ee (" + error.localizedDescription + ")")
            return (nil, nil)
        }

        // SIGNATURE

        if e2eeJson != nil {
            let dataMetadata = Data(base64Encoded: "e2eeJson")
            let privateKey = CCUtility.getEndToEndPrivateKey(account)
            let publicKey = CCUtility.getEndToEndPublicKey(account)
            if let signatureData = NCEndToEndEncryption.sharedManager().generateSignatureCMS(dataMetadata, certificate: CCUtility.getEndToEndCertificate(account), privateKey: privateKey, publicKey: publicKey, userId: userId) {
                signature = signatureData.base64EncodedString()
            }
        }

        return (e2eeJson, signature)
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata V2.0
    // --------------------------------------------------------------------------------------------

    func decoderMetadataV20(_ json: String, signature: String?, serverUrl: String, account: String, ocIdServerUrl: String, urlBase: String, userId: String, ownerId: String?) -> NKError {

        guard let data = json.data(using: .utf8),
              let directoryTop = NCUtility.shared.getDirectoryE2EETop(serverUrl: serverUrl, account: account) else {
            return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: "Error decoding JSON")
        }

        func addE2eEncryption(fileNameIdentifier: String, filename: String, authenticationTag: String, key: String, initializationVector: String, metadataKey: String, mimetype: String) {

            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {

                let object = tableE2eEncryption.init(account: account, ocIdServerUrl: ocIdServerUrl, fileNameIdentifier: fileNameIdentifier)

                object.authenticationTag = authenticationTag
                object.blob = "files"
                object.fileName = filename
                object.key = key
                object.initializationVector = initializationVector
                object.metadataKey = metadataKey
                object.mimeType = mimetype
                object.serverUrl = serverUrl

                // Write file parameter for decrypted on DB
                NCManageDatabase.shared.addE2eEncryption(object)

                // Update metadata on tableMetadata
                metadata.fileNameView = filename

                let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: filename, mimeType: metadata.contentType, directory: metadata.directory)

                metadata.contentType = results.mimeType
                metadata.iconName = results.iconName
                metadata.classFile = results.classFile

                NCManageDatabase.shared.addMetadata(metadata)
            }
        }

        do {
            let json = try JSONDecoder().decode(E2eeV20.self, from: data)

            let metadata = json.metadata
            let users = json.users
            let filedrop = json.filedrop
            let version = json.version as String? ?? "2.0"

            // SIGNATURE CHECK

            let metadataCodable = E2eeV20.Metadata(ciphertext: metadata.ciphertext, nonce: metadata.nonce, authenticationTag: metadata.authenticationTag)
            let metadataData = try JSONEncoder().encode(metadataCodable)
            if let signatureData = NCEndToEndEncryption.sharedManager().generateSignatureCMS(metadataData, certificate: CCUtility.getEndToEndPublicKey(account), privateKey: CCUtility.getEndToEndPrivateKey(account), publicKey: CCUtility.getEndToEndPublicKey(account), userId: userId) {
                let signatureX = signatureData.base64EncodedString()
                print(signatureX)
            }

            //
            // users
            //

            if let users {
                for user in users {

                    var decryptedMetadataKey: Data?
                    var decryptedFiledropKey: Data?
                    var metadataKey: String?
                    var filedropKey: String?

                    if let encryptedMetadataKey = user.encryptedMetadataKey {
                        let data = Data(base64Encoded: encryptedMetadataKey)
                        if let decrypted = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(data, privateKey: CCUtility.getEndToEndPrivateKey(account)) {
                            decryptedMetadataKey = decrypted
                            metadataKey = decrypted.base64EncodedString()
                        }
                    }

                    if let encryptedFiledropKey = user.encryptedFiledropKey {
                        let data = Data(base64Encoded: encryptedFiledropKey)
                        if let decrypted = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(data, privateKey: CCUtility.getEndToEndPrivateKey(account)) {
                            decryptedFiledropKey = decrypted
                            filedropKey = decrypted.base64EncodedString()
                        }
                    }

                    NCManageDatabase.shared.addE2EUsersV2(account: account,
                                                          serverUrl: serverUrl,
                                                          ocIdServerUrl: ocIdServerUrl,
                                                          userId: user.userId,
                                                          certificate: user.certificate,
                                                          encryptedFiledropKey: user.encryptedFiledropKey,
                                                          encryptedMetadataKey: user.encryptedMetadataKey,
                                                          decryptedFiledropKey: decryptedFiledropKey,
                                                          decryptedMetadataKey: decryptedMetadataKey,
                                                          filedropKey: filedropKey,
                                                          metadataKey: metadataKey)
                }
            }

            //
            // metadata
            //

            if let tableE2eUsersV2 = NCManageDatabase.shared.getE2EUsersV2(account: account, ocIdServerUrl: directoryTop.ocId, userId: userId),
               let metadataKey = tableE2eUsersV2.metadataKey,
               let decryptedMetadataKey = tableE2eUsersV2.decryptedMetadataKey {

                // CIPHERTEXT

                if let decrypted = NCEndToEndEncryption.sharedManager().decryptPayloadFile(metadata.ciphertext, key: metadataKey, initializationVector: metadata.nonce, authenticationTag: metadata.authenticationTag) {
                    if decrypted.isGzipped {
                        do {
                            let data = try decrypted.gunzipped()
                            if let jsonText = String(data: data, encoding: .utf8) {
                                print(jsonText)
                            }

                            let json = try JSONDecoder().decode(E2eeV20.ciphertext.self, from: data)

                            // Checksums check
                            if let keyChecksums = json.keyChecksums,
                                let hash = NCEndToEndEncryption.sharedManager().createSHA256(decryptedMetadataKey),
                                !keyChecksums.contains(hash) {
                                return NKError(errorCode: NCGlobal.shared.errorE2EEKeyChecksums, errorDescription: NSLocalizedString("_e2ee_checksums_error_", comment: ""))
                            }

                            NCManageDatabase.shared.addE2eMetadataV2(account: account, serverUrl: serverUrl, ocIdServerUrl: ocIdServerUrl, keyChecksums: json.keyChecksums, deleted: json.deleted ?? false, counter: json.counter, folders: json.folders, version: version)

                            if let files = json.files {
                                for file in files {
                                    addE2eEncryption(fileNameIdentifier: file.key, filename: file.value.filename, authenticationTag: file.value.authenticationTag, key: file.value.key, initializationVector: file.value.nonce, metadataKey: metadataKey, mimetype: file.value.mimetype)
                                }
                            }

                            if let folders = json.folders {
                                for folder in folders {
                                    addE2eEncryption(fileNameIdentifier: folder.key, filename: folder.value, authenticationTag: metadata.authenticationTag, key: metadataKey, initializationVector: metadata.nonce, metadataKey: metadataKey, mimetype: "httpd/unix-directory")
                                }
                            }

                        } catch let error {
                            return NKError(error: error)
                        }
                    } else {
                        return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: "Error unzip ciphertext")
                    }
                } else {
                    return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: "Error decrypt ciphertext")
                }
            }
        } catch let error {
            return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: error.localizedDescription)
        }

        return NKError()
    }
}

/* TEST CMS

if let cmsData = NCEndToEndEncryption.sharedManager().generateSignatureCMS(data, certificate: CCUtility.getEndToEndCertificate(account), privateKey: CCUtility.getEndToEndPrivateKey(account), publicKey: CCUtility.getEndToEndPublicKey(account), userId: userId) {

    let cms = cmsData.base64EncodedString()
    print(cms)

    let cmsTest = "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"

    let data = Data(base64Encoded: cmsTest)
    NCEndToEndEncryption.sharedManager().verifySignatureCMS(data, data: nil, publicKey: CCUtility.getEndToEndPublicKey(account), userId: userId)
}
 */
