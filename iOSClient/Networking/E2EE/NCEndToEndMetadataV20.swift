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

    struct E2eeV20: Codable {

        struct Files: Codable {
            let authenticationTag: String
            let filename: String
            let key: String
            let mimetype: String
            let nonce: String
        }

        struct ciphertext: Codable {
            let counter: Int
            let deleted: Bool?
            let keyChecksums: [String]?
            let files: [String: Files]?
            let folders: [String: String]?
        }

        struct Metadata: Codable {
            let ciphertext: String
            let nonce: String
            let authenticationTag: String
        }

        struct Users: Codable {
            let userId: String
            let certificate: String
            let encryptedMetadataKey: String?
            let encryptedFiledropKey: String?
        }

        struct Filedrop: Codable {
            let ciphertext: String?
            let nonce: String?
            let authenticationTag: String?
            let users: [String: UsersFiledrop]?

            struct UsersFiledrop: Codable {
                let userId: String?
                let encryptedFiledropKey: String?
            }
        }

        let metadata: Metadata
        let users: [Users]?
        let filedrop: [String: Filedrop]?
        let version: String
    }

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

    func encodeMetadataV20(account: String, serverUrl: String, ocIdServerUrl: String, userId: String, addUserId: String?, addCertificate: String?, removeUserId: String?) -> (metadata: String?, signature: String?, counter: Int, error: NKError) {

        guard let keyGenerated = NCEndToEndEncryption.sharedManager()?.generateKey() as? Data,
              let directoryTop = NCUtility.shared.getDirectoryE2EETop(serverUrl: serverUrl, account: account) else {
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_"))
        }

        let isDirectoryTop = NCUtility.shared.isDirectoryE2EETop(account: account, serverUrl: serverUrl)
        var metadataKey: String?
        var keyChecksums: [String] = []
        var usersCodable: [E2eeV20.Users] = []
        var filedropCodable: [String: E2eeV20.Filedrop] = [:]
        var folders: [String: String] = [:]
        var counter: Int = 1

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
                } else if user.userId == userId {
                    metadataKey = user.metadataKey
                }
            }
        }

        if let resultCounter = NCManageDatabase.shared.getCounterE2eMetadataV2(account: account, ocIdServerUrl: ocIdServerUrl) {
            counter = resultCounter + 1
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

        let ciphertext = E2eeV20.ciphertext(counter: counter, deleted: false, keyChecksums: keyChecksums, files: filesCodable, folders: folders)
        var authenticationTag: NSString?
        var initializationVector: NSString?

        do {
            let json = try JSONEncoder().encode(ciphertext)
            let jsonZip = try json.gzipped()
            let ciphertext = NCEndToEndEncryption.sharedManager().encryptPayloadFile(jsonZip, key: metadataKey, initializationVector: &initializationVector, authenticationTag: &authenticationTag)

            guard var ciphertext, let initializationVector = initializationVector as? String, let authenticationTag = authenticationTag as? String else {
                return (nil, nil, counter, NKError(errorCode: NCGlobal.shared.errorE2EEEncryptPayloadFile, errorDescription: "_e2e_error_"))
            }

            // Add initializationVector [ANDROID]
            ciphertext = ciphertext + "|" + initializationVector

            let metadataCodable = E2eeV20.Metadata(ciphertext: ciphertext, nonce: initializationVector, authenticationTag: authenticationTag)
            let e2eeCodable = E2eeV20(metadata: metadataCodable, users: usersCodable, filedrop: filedropCodable, version: NCGlobal.shared.e2eeVersionV20)
            let e2eeData = try JSONEncoder().encode(e2eeCodable)
            e2eeData.printJson()

            let e2eeJson = String(data: e2eeData, encoding: .utf8)
            let signature = createSignature(account: account, userId: userId, metadata: metadataCodable, users: usersCodable, version: NCGlobal.shared.e2eeVersionV20, certificate: CCUtility.getEndToEndCertificate(account))

            return (e2eeJson, signature, counter, NKError())

        } catch let error {
            return (nil, nil, counter, NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription))
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata V2.0
    // --------------------------------------------------------------------------------------------

    func decodeMetadataV20(_ json: String, signature: String?, serverUrl: String, account: String, ocIdServerUrl: String, urlBase: String, userId: String, ownerId: String?) -> NKError {

        guard let data = json.data(using: .utf8),
              let directoryTop = NCUtility.shared.getDirectoryE2EETop(serverUrl: serverUrl, account: account) else {
            return NKError(errorCode: NCGlobal.shared.errorE2EEKeyDecodeMetadata, errorDescription: "_e2e_error_")
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
            let version = json.version as String? ?? NCGlobal.shared.e2eeVersionV20

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

            if let tableE2eUsersV2 = NCManageDatabase.shared.getE2EUsersV2(account: account, ocIdServerUrl: directoryTop.ocId, userId: userId),
               let metadataKey = tableE2eUsersV2.metadataKey,
               let decryptedMetadataKey = tableE2eUsersV2.decryptedMetadataKey {

                // SIGNATURE CHECK
                guard let signature,
                      verifySignature(account: account, signature: signature, userId: tableE2eUsersV2.userId, metadata: metadata, users: users, version: version, certificate: tableE2eUsersV2.certificate) else {
                    return NKError(errorCode: NCGlobal.shared.errorE2EEKeyVerifySignature, errorDescription: "_e2e_error_")

                }

                // CIPHERTEXT
                guard let decrypted = NCEndToEndEncryption.sharedManager().decryptPayloadFile(metadata.ciphertext, key: metadataKey, initializationVector: metadata.nonce, authenticationTag: metadata.authenticationTag),
                      decrypted.isGzipped else {
                    return NKError(errorCode: NCGlobal.shared.errorE2EEKeyCiphertext, errorDescription: "_e2e_error_")
                }

                let data = try decrypted.gunzipped()
                if let jsonText = String(data: data, encoding: .utf8) {
                    print(jsonText)
                }

                let json = try JSONDecoder().decode(E2eeV20.ciphertext.self, from: data)

                // Check "checksums"
                guard let keyChecksums = json.keyChecksums,
                      let hash = NCEndToEndEncryption.sharedManager().createSHA256(decryptedMetadataKey),
                      keyChecksums.contains(hash) else {
                    return NKError(errorCode: NCGlobal.shared.errorE2EEKeyChecksums, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
                }

                // Check "counter"
                if let resultCounter = NCManageDatabase.shared.getCounterE2eMetadataV2(account: account, ocIdServerUrl: ocIdServerUrl) {
                    if json.counter > resultCounter {
                        NKError(errorCode: NCGlobal.shared.errorE2EECounter, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
                    }
                }

                // Check "deleted"
                if let deleted = json.deleted,
                    deleted {
                    // TODO: We need to check deleted, id yes ???
                }

                NCManageDatabase.shared.addE2eMetadataV2(account: account, serverUrl: serverUrl, ocIdServerUrl: ocIdServerUrl, keyChecksums: json.keyChecksums, deleted: json.deleted ?? false, folders: json.folders, version: version)

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
            }
        } catch let error {
            return NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription)
        }

        return NKError()
    }

    // MARK: -

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
                return signatureData.base64EncodedString()
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }

        return nil
    }

    func verifySignature(account: String, signature: String, userId: String, metadata: E2eeV20.Metadata, users: [E2eeV20.Users]?, version: String, certificate: String) -> Bool {

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
                return NCEndToEndEncryption.sharedManager().verifySignatureCMS(signatureData, data: base64Data, certificates: certificates)
            }

        } catch {
            print("Error: \(error.localizedDescription)")
        }

        return false
    }
}
