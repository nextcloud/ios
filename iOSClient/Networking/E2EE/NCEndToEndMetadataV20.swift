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

    struct E2eeV20Signature: Codable {

        struct Metadata: Codable {
            let ciphertext: String
            let nonce: String
            let authenticationTag: String
        }

        struct Users: Codable {
            let userId: String
            let certificate: String
            let encryptedMetadataKey: String?
        }

        let metadata: Metadata
        let users: [Users]?
        let version: String
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Ecode JSON Metadata V2.0
    // --------------------------------------------------------------------------------------------

    func encoderMetadataV20(account: String, serverUrl: String, ocIdServerUrl: String, userId: String, addUserId: String?, addCertificate: String?, removeUserId: String?) -> (metadata: String?, signature: String?) {

        guard let keyGenerated = NCEndToEndEncryption.sharedManager()?.generateKey() as? Data,
              let directoryTop = NCUtility.shared.getDirectoryE2EETop(serverUrl: serverUrl, account: account) else {
            return (nil, nil)
        }

        let isDirectoryTop = NCUtility.shared.isDirectoryE2EETop(account: account, serverUrl: serverUrl)
        var metadataKey: String?
        var userCertificate: String = ""
        var keyChecksums: [String] = []
        var usersCodable: [E2eeV20.Users] = []
        var filedropCodable: [String: E2eeV20.Filedrop] = [:]
        var folders: [String: String] = [:]

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

            if let removeUserId {
                NCManageDatabase.shared.deleteE2EUsersV2(account: account, ocIdServerUrl: ocIdServerUrl, userId: removeUserId)
            }

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
                    userCertificate = user.certificate
                } else if user.userId == userId {
                    metadataKey = user.metadataKey
                    userCertificate = user.certificate
                }
            }
        }

        guard let e2eMetadataV2 = NCManageDatabase.shared.incrementCounterE2eMetadataV2(account: account, serverUrl: serverUrl, ocIdServerUrl: ocIdServerUrl, version: NCGlobal.shared.e2eeVersionV20) else {
            return (nil, nil)
        }

        // Create ciphertext
        let e2eEncryptions = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))
        var filesCodable: [String: E2eeV20.Files] = [:]

        for e2eEncryption in e2eEncryptions {
            if e2eEncryption.blob == "files" {
                let file = E2eeV20.Files(authenticationTag: e2eEncryption.authenticationTag, filename: e2eEncryption.fileName, key: e2eEncryption.key, mimetype: e2eEncryption.mimeType, nonce: e2eEncryption.initializationVector)
                filesCodable.updateValue(file, forKey: e2eEncryption.fileNameIdentifier)
            } else if e2eEncryption.blob == "folders" {
                folders[e2eEncryption.fileNameIdentifier] = e2eEncryption.fileName
            }
        }

        let ciphertext = E2eeV20.ciphertext(counter: e2eMetadataV2.counter, deleted: false, keyChecksums: keyChecksums, files: filesCodable, folders: folders)
        var authenticationTag: NSString?
        var initializationVector: NSString?

        do {
            let json = try JSONEncoder().encode(ciphertext)
            let jsonZip = try json.gzipped()
            let ciphertext = NCEndToEndEncryption.sharedManager().encryptPayloadFile(jsonZip, key: metadataKey, initializationVector: &initializationVector, authenticationTag: &authenticationTag)

            guard var ciphertext, let initializationVector = initializationVector as? String, let authenticationTag = authenticationTag as? String else {
                return (nil, nil)
            }

            // Add initializationVector [ANDROID]
            ciphertext = ciphertext + "|" + initializationVector

            let metadataCodable = E2eeV20.Metadata(ciphertext: ciphertext, nonce: initializationVector, authenticationTag: authenticationTag)
            let e2eeCodable = E2eeV20(metadata: metadataCodable, users: usersCodable, filedrop: filedropCodable, version: NCGlobal.shared.e2eeVersionV20)
            let e2eeData = try JSONEncoder().encode(e2eeCodable)
            e2eeData.printJson()

            let e2eeJson = String(data: e2eeData, encoding: .utf8)
            let signature = createSignature(account: account, userId: userId, metadata: metadataCodable, users: usersCodable, version: NCGlobal.shared.e2eeVersionV20, certificate: userCertificate)
            return (e2eeJson, signature)

        } catch let error {
            print("Serious internal error in encoding e2ee (" + error.localizedDescription + ")")
            return (nil, nil)
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata V2.0
    // --------------------------------------------------------------------------------------------

    func decoderMetadataV20(_ json: String, signature: String?, serverUrl: String, account: String, ocIdServerUrl: String, urlBase: String, userId: String, ownerId: String?) -> NKError {

        guard let data = json.data(using: .utf8),
              let directoryTop = NCUtility.shared.getDirectoryE2EETop(serverUrl: serverUrl, account: account) else {
            return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: "Error decoding JSON")
        }

        func addE2eEncryption(fileNameIdentifier: String, filename: String, authenticationTag: String, key: String, initializationVector: String, metadataKey: String, mimetype: String, blob: String) {

            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {

                let object = tableE2eEncryption.init(account: account, ocIdServerUrl: ocIdServerUrl, fileNameIdentifier: fileNameIdentifier)

                object.authenticationTag = authenticationTag
                object.blob = blob
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

                // SIGNATURE CHECK
                if let signature,
                    !verifySignature(signature: signature, account: account, userId: tableE2eUsersV2.userId, metadata: metadata, users: users, version: version, certificate: tableE2eUsersV2.certificate) {
                    return NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: "Error verify signature")
                }

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
                                    addE2eEncryption(fileNameIdentifier: file.key, filename: file.value.filename, authenticationTag: file.value.authenticationTag, key: file.value.key, initializationVector: file.value.nonce, metadataKey: metadataKey, mimetype: file.value.mimetype, blob: "files")
                                }
                            }

                            if let folders = json.folders {
                                for folder in folders {
                                    addE2eEncryption(fileNameIdentifier: folder.key, filename: folder.value, authenticationTag: metadata.authenticationTag, key: metadataKey, initializationVector: metadata.nonce, metadataKey: metadataKey, mimetype: "httpd/unix-directory", blob: "folders")
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

    func createSignature(account: String, userId: String, metadata: E2eeV20.Metadata, users: [E2eeV20.Users]?, version: String, certificate: String) -> String? {

        guard let users else { return nil }

        var usersSignatureCodable: [E2eeV20Signature.Users] = []
        for user in users {
            usersSignatureCodable.append(E2eeV20Signature.Users(userId: user.userId, certificate: user.certificate, encryptedMetadataKey: user.encryptedMetadataKey))
        }
        let signatureCodable = E2eeV20Signature(metadata: E2eeV20Signature.Metadata(ciphertext: metadata.ciphertext, nonce: metadata.nonce, authenticationTag: metadata.authenticationTag), users: usersSignatureCodable, version: version)

        do {
            let jsonEncoder = JSONEncoder()
            let json = try jsonEncoder.encode(signatureCodable)
            let dataSerialization = try JSONSerialization.jsonObject(with: json, options: [])
            let decoded = try? JSONSerialization.data(withJSONObject: dataSerialization, options: [.sortedKeys, .withoutEscapingSlashes])
            let base64 = decoded!.base64EncodedString()
            if let base64Data = base64.data(using: .utf8),
               let signatureData = NCEndToEndEncryption.sharedManager().generateSignatureCMS(base64Data, certificate: certificate, privateKey: CCUtility.getEndToEndPrivateKey(account), userId: userId) {
                let signature = signatureData.base64EncodedString()
                return signature
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }

        return nil
    }

    func verifySignature(signature: String, account: String, userId: String, metadata: E2eeV20.Metadata, users: [E2eeV20.Users]?, version: String, certificate: String) -> Bool {

        guard let users else { return false }

        var usersSignatureCodable: [E2eeV20Signature.Users] = []
        for user in users {
            usersSignatureCodable.append(E2eeV20Signature.Users(userId: user.userId, certificate: user.certificate, encryptedMetadataKey: user.encryptedMetadataKey))
        }
        let signatureCodable = E2eeV20Signature(metadata: E2eeV20Signature.Metadata(ciphertext: metadata.ciphertext, nonce: metadata.nonce, authenticationTag: metadata.authenticationTag), users: usersSignatureCodable, version: version)

        do {
            let jsonEncoder = JSONEncoder()
            let json = try jsonEncoder.encode(signatureCodable)
            let dataSerialization = try JSONSerialization.jsonObject(with: json, options: [])
            let decoded = try? JSONSerialization.data(withJSONObject: dataSerialization, options: [.sortedKeys, .withoutEscapingSlashes])
            let base64 = decoded!.base64EncodedString()
            if let base64Data = base64.data(using: .utf8),
               let signatureData = Data(base64Encoded: signature) {
                let certificates = users.map { $0.certificate }
                NCEndToEndEncryption.sharedManager().verifySignatureCMS2(signatureData, data: base64Data, certificates: certificates)
                //return NCEndToEndEncryption.sharedManager().verifySignatureCMS(signatureData, data: base64Data, publicKey: CCUtility.getEndToEndPublicKey(account), userId: userId)
            }

        } catch {
            print("Error: \(error.localizedDescription)")
        }

        return false
    }
}
