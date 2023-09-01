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
            let users: [UsersFiledrop]?

            struct UsersFiledrop: Codable {
                let userId: String?
                let encryptedFiledropKey: String?
            }
        }

        let metadata: Metadata
        let users: [Users]?
        let filedrop: [Filedrop]?
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

        guard let directoryTop = NCUtility.shared.getDirectoryE2EETop(serverUrl: serverUrl, account: account) else {
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_"))
        }

        let isDirectoryTop = NCUtility.shared.isDirectoryE2EETop(account: account, serverUrl: serverUrl)
        var metadataKey: String?
        var keyChecksums: [String] = []
        var usersCodable: [E2eeV20.Users] = []
        var usersFileDropCodable: [E2eeV20.Filedrop.UsersFiledrop] = []
        var filesCodable: [String: E2eeV20.Files] = [:]
        var filedropCodable: [E2eeV20.Filedrop] = []
        var folders: [String: String] = [:]
        var counter: Int = 1

        func addUser(userId: String?, certificate: String?, key: Data) {

            guard let userId, let certificate else { return }

            if let metadataKeyEncrypted = NCEndToEndEncryption.sharedManager().encryptAsymmetricData(key, certificate: certificate) {
                let encryptedMetadataKey = metadataKeyEncrypted.base64EncodedString()

                NCManageDatabase.shared.addE2EUsersV2(account: account, serverUrl: serverUrl, ocIdServerUrl: ocIdServerUrl, userId: userId, certificate: certificate, encryptedFiledropKey: encryptedMetadataKey, encryptedMetadataKey: encryptedMetadataKey, filedropKey: key, metadataKey: key)
            }
        }

        if isDirectoryTop {

            guard var keyGenerated = NCEndToEndEncryption.sharedManager()?.generateKey() as? Data else {
                return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_"))
            }

            if let tableUserId = NCManageDatabase.shared.getE2EUsersV2(account: account, ocIdServerUrl: directoryTop.ocId, userId: userId),
               let metadataKey = tableUserId.metadataKey {
                keyGenerated = metadataKey
            } else {
                addUser(userId: userId, certificate: CCUtility.getEndToEndCertificate(account), key: keyGenerated)
            }
            // ADDUSERID
            if let addUserId {
                addUser(userId: addUserId, certificate: addCertificate, key: keyGenerated)
            }
            // REMOVEUSERID
            if let removeUserId {
                NCManageDatabase.shared.deleteE2EUsersV2(account: account, ocIdServerUrl: ocIdServerUrl, userId: removeUserId)
                if let users = NCManageDatabase.shared.getE2EUsersV2(account: account, ocIdServerUrl: ocIdServerUrl) {
                    for user in users {
                        if user.userId == userId { continue }
                        addUser(userId: user.userId, certificate: user.certificate, key: keyGenerated)
                    }
                }
            }
        }

        if let users = NCManageDatabase.shared.getE2EUsersV2(account: account, ocIdServerUrl: directoryTop.ocId) {
            for user in users {
                if isDirectoryTop {
                    usersCodable.append(E2eeV20.Users(userId: user.userId, certificate: user.certificate, encryptedMetadataKey: user.encryptedMetadataKey, encryptedFiledropKey: user.encryptedFiledropKey))
                    usersFileDropCodable.append(E2eeV20.Filedrop.UsersFiledrop(userId: user.userId, encryptedFiledropKey: user.encryptedFiledropKey))
                }
                if let hash = NCEndToEndEncryption.sharedManager().createSHA256(user.metadataKey) {
                    keyChecksums.append(hash)
                }
                if let addUserId, user.userId == addUserId {
                    metadataKey = user.metadataKey?.base64EncodedString()
                } else if user.userId == userId {
                    metadataKey = user.metadataKey?.base64EncodedString()
                }
            }
        }

        if let resultCounter = NCManageDatabase.shared.getCounterE2eMetadataV2(account: account, ocIdServerUrl: ocIdServerUrl) {
            counter = resultCounter + 1
        }

        // Create ciphertext
        let e2eEncryptions = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))

        for e2eEncryption in e2eEncryptions {
            if e2eEncryption.blob == "files" {
                let file = E2eeV20.Files(authenticationTag: e2eEncryption.authenticationTag, filename: e2eEncryption.fileName, key: e2eEncryption.key, mimetype: e2eEncryption.mimeType, nonce: e2eEncryption.initializationVector)
                filesCodable.updateValue(file, forKey: e2eEncryption.fileNameIdentifier)
            } else if e2eEncryption.blob == "folders" {
                folders[e2eEncryption.fileNameIdentifier] = e2eEncryption.fileName
            } else if e2eEncryption.blob == "filedrop" {
                let filedrop = E2eeV20.Files(authenticationTag: e2eEncryption.authenticationTag, filename: e2eEncryption.fileName, key: e2eEncryption.key, mimetype: e2eEncryption.mimeType, nonce: e2eEncryption.initializationVector)
                var authenticationTag: NSString?
                var initializationVector: NSString?
                do {
                    let json = try JSONEncoder().encode(filedrop)
                    let jsonZip = try json.gzipped()
                    let ciphertext = NCEndToEndEncryption.sharedManager().encryptPayloadFile(jsonZip, key: metadataKey, initializationVector: &initializationVector, authenticationTag: &authenticationTag)

                    guard var ciphertext, let initializationVector = initializationVector as? String, let authenticationTag = authenticationTag as? String else {
                        return (nil, nil, counter, NKError(errorCode: NCGlobal.shared.errorE2EEEncryptPayloadFile, errorDescription: "_e2e_error_"))
                    }

                    // Add initializationVector [ANDROID]
                    ciphertext = ciphertext + "|" + initializationVector

                    let filedrop = E2eeV20.Filedrop(ciphertext: ciphertext, nonce: initializationVector, authenticationTag: authenticationTag, users: usersFileDropCodable)
                    filedropCodable.append(filedrop)

                } catch let error {
                    return (nil, nil, counter, NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription))
                }
            }
        }

        do {
            var authenticationTag: NSString?
            var initializationVector: NSString?
            let json = try JSONEncoder().encode(E2eeV20.ciphertext(counter: counter, deleted: false, keyChecksums: keyChecksums, files: filesCodable, folders: folders))
            let jsonZip = try json.gzipped()
            let ciphertextMetadata = NCEndToEndEncryption.sharedManager().encryptPayloadFile(jsonZip, key: metadataKey, initializationVector: &initializationVector, authenticationTag: &authenticationTag)
            guard var ciphertextMetadata, let initializationVector = initializationVector as? String, let authenticationTag = authenticationTag as? String else {
                return (nil, nil, counter, NKError(errorCode: NCGlobal.shared.errorE2EEEncryptPayloadFile, errorDescription: "_e2e_error_"))
            }

            // Add initializationVector [ANDROID]
            ciphertextMetadata = ciphertextMetadata + "|" + initializationVector

            let metadataCodable = E2eeV20.Metadata(ciphertext: ciphertextMetadata, nonce: initializationVector, authenticationTag: authenticationTag)
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

    func decodeMetadataV20(_ json: String, signature: String?, serverUrl: String, account: String, ocIdServerUrl: String, urlBase: String, userId: String) -> NKError {

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
            let filesdrop = json.filedrop
            let version = json.version as String? ?? NCGlobal.shared.e2eeVersionV20

            if let users {
                for user in users {

                    var metadataKey: Data?
                    var filedropKey: Data?

                    if let encryptedMetadataKey = user.encryptedMetadataKey {
                        let data = Data(base64Encoded: encryptedMetadataKey)
                        if let decrypted = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(data, privateKey: CCUtility.getEndToEndPrivateKey(account)) {
                            metadataKey = decrypted
                        }
                    }

                    if let encryptedFiledropKey = user.encryptedFiledropKey {
                        let data = Data(base64Encoded: encryptedFiledropKey)
                        if let decrypted = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(data, privateKey: CCUtility.getEndToEndPrivateKey(account)) {
                            filedropKey = decrypted
                        }
                    }

                    NCManageDatabase.shared.addE2EUsersV2(account: account, serverUrl: serverUrl, ocIdServerUrl: ocIdServerUrl, userId: user.userId, certificate: user.certificate, encryptedFiledropKey: user.encryptedFiledropKey, encryptedMetadataKey: user.encryptedMetadataKey, filedropKey: filedropKey, metadataKey: metadataKey)
                }
            }

            guard let tableE2eUsersV2 = NCManageDatabase.shared.getE2EUsersV2(account: account, ocIdServerUrl: directoryTop.ocId, userId: userId),
                  let metadataKey = tableE2eUsersV2.metadataKey?.base64EncodedString(),
                  let decryptedMetadataKey = tableE2eUsersV2.metadataKey else {
                return NKError(errorCode: NCGlobal.shared.errorE2EENoUserFound, errorDescription: "_e2e_error_")
            }

            // SIGNATURE CHECK
            guard let signature,
                  verifySignature(account: account, signature: signature, userId: tableE2eUsersV2.userId, metadata: metadata, users: users, version: version, certificate: tableE2eUsersV2.certificate) else {
                return NKError(errorCode: NCGlobal.shared.errorE2EEKeyVerifySignature, errorDescription: "_e2e_error_")

            }

            // FILEDROP
            if let filesdrop, let filedropKey = tableE2eUsersV2.filedropKey?.base64EncodedString() {
                for filedrop in filesdrop {
                    guard let decryptedFiledrop = NCEndToEndEncryption.sharedManager().decryptPayloadFile(filedrop.ciphertext, key: filedropKey, initializationVector: filedrop.nonce, authenticationTag: filedrop.authenticationTag),
                          decryptedFiledrop.isGzipped else {
                        return NKError(errorCode: NCGlobal.shared.errorE2EEKeyFiledropCiphertext, errorDescription: "_e2e_error_")
                    }
                    let data = try decryptedFiledrop.gunzipped()
                    if let jsonText = String(data: data, encoding: .utf8) { print(jsonText) }
                    let file = try JSONDecoder().decode(E2eeV20.Files.self, from: data)
                    print(file)
                    addE2eEncryption(fileNameIdentifier: file.key, filename: file.filename, authenticationTag: file.authenticationTag, key: file.key, initializationVector: file.nonce, metadataKey: filedropKey, mimetype: file.mimetype, blob: "filedrop")
                }
            }

            // CIPHERTEXT METADATA
            guard let decryptedMetadata = NCEndToEndEncryption.sharedManager().decryptPayloadFile(metadata.ciphertext, key: metadataKey, initializationVector: metadata.nonce, authenticationTag: metadata.authenticationTag),
                  decryptedMetadata.isGzipped else {
                return NKError(errorCode: NCGlobal.shared.errorE2EEKeyCiphertext, errorDescription: "_e2e_error_")
            }

            let data = try decryptedMetadata.gunzipped()
            if let jsonText = String(data: data, encoding: .utf8) { print(jsonText) }
            let jsonCiphertextMetadata = try JSONDecoder().decode(E2eeV20.ciphertext.self, from: data)

            // CHECKSUM CHECK
            guard let keyChecksums = jsonCiphertextMetadata.keyChecksums,
                  let hash = NCEndToEndEncryption.sharedManager().createSHA256(decryptedMetadataKey),
                  keyChecksums.contains(hash) else {
                return NKError(errorCode: NCGlobal.shared.errorE2EEKeyChecksums, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
            }

            print("\n\nCOUNTER -------------------------------")
            print("Counter: \(jsonCiphertextMetadata.counter)")

            // COUNTER CHECK
            if let resultCounter = NCManageDatabase.shared.getCounterE2eMetadataV2(account: account, ocIdServerUrl: ocIdServerUrl) {
                print("Counter saved: \(resultCounter)")
                if jsonCiphertextMetadata.counter < resultCounter {
                    // TODO: whats happen with < ?
                    NCContentPresenter.shared.showError(error: NKError(errorCode: NCGlobal.shared.errorE2EECounter, errorDescription: NSLocalizedString("_e2e_error_", comment: "")))
                } else if jsonCiphertextMetadata.counter > resultCounter {
                    print("Counter UPDATED: \(jsonCiphertextMetadata.counter)")
                    NCManageDatabase.shared.updateCounterE2eMetadataV2(account: account, ocIdServerUrl: ocIdServerUrl, counter: jsonCiphertextMetadata.counter)
                }
            } else {
                print("Counter RESET: \(jsonCiphertextMetadata.counter)")
                NCManageDatabase.shared.updateCounterE2eMetadataV2(account: account, ocIdServerUrl: ocIdServerUrl, counter: jsonCiphertextMetadata.counter)
            }

            // DELETE CHECK
            if let deleted = jsonCiphertextMetadata.deleted, deleted {
                // TODO: We need to check deleted, id yes ???
            }

            NCManageDatabase.shared.addE2eMetadataV2(account: account,
                                                     serverUrl: serverUrl,
                                                     ocIdServerUrl: ocIdServerUrl,
                                                     keyChecksums: jsonCiphertextMetadata.keyChecksums,
                                                     deleted: jsonCiphertextMetadata.deleted ?? false,
                                                     folders: jsonCiphertextMetadata.folders,
                                                     version: version)

            if let files = jsonCiphertextMetadata.files {
                print("\nFILES ---------------------------------\n")
                for file in files {
                    addE2eEncryption(fileNameIdentifier: file.key, filename: file.value.filename, authenticationTag: file.value.authenticationTag, key: file.value.key, initializationVector: file.value.nonce, metadataKey: metadataKey, mimetype: file.value.mimetype, blob: "files")

                    print("filename: \(file.value.filename)")
                    print("fileNameIdentifier: \(file.key)")
                    print("mimetype: \(file.value.mimetype)")
                    print("\n")
                }
            }

            if let folders = jsonCiphertextMetadata.folders {
                print("FOLDERS--------------------------------\n")
                for folder in folders {
                    addE2eEncryption(fileNameIdentifier: folder.key, filename: folder.value, authenticationTag: metadata.authenticationTag, key: metadataKey, initializationVector: metadata.nonce, metadataKey: metadataKey, mimetype: "httpd/unix-directory", blob: "folders")

                    print("filename: \(folder.value)")
                    print("fileNameIdentifier: \(folder.key)")
                    print("\n")
                }
            }

            print("---------------------------------------\n\n")

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
