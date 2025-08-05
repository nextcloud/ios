// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import Gzip

extension NCEndToEndMetadata {
    struct E2eeV20: Codable {

        struct Metadata: Codable {
            let ciphertext: String
            let nonce: String
            let authenticationTag: String

            struct ciphertext: Codable {
                let counter: Int
                let deleted: Bool?
                let keyChecksums: [String]?
                let files: [String: Files]?
                let folders: [String: String]?

                struct Files: Codable {
                    let authenticationTag: String
                    let filename: String
                    let key: String
                    let mimetype: String
                    let nonce: String
                }
            }
        }

        struct Users: Codable {
            let userId: String
            let certificate: String
            let encryptedMetadataKey: String?
        }

        struct Filedrop: Codable {
            let ciphertext: String
            let nonce: String
            let authenticationTag: String
            let users: [UsersFiledrop]

            struct UsersFiledrop: Codable {
                let userId: String
                let encryptedFiledropKey: String
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

    func encodeMetadataV20(serverUrl: String, ocIdServerUrl: String, addUserId: String?, addCertificate: String?, removeUserId: String?, session: NCSession.Session) async -> (metadata: String?, signature: String?, counter: Int, error: NKError) {
        guard let directoryTop = await utilityFileSystem.getMetadataE2EETopAsync(serverUrl: serverUrl, session: session) else {
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorE2EEKeyDirectoryTop, errorDescription: "_e2e_error_"))
        }
        guard let certificate = NCPreferences().getEndToEndCertificate(account: session.account) else {
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_ \(NCGlobal.shared.errorUnexpectedResponseFromDB)"))
        }

        let isDirectoryTop = serverUrl == directoryTop.serverUrlFileName
        let directoryTopOcId = directoryTop.ocId

        var metadataKey: String?
        var keyChecksums: [String] = []
        var usersCodable: [E2eeV20.Users] = []
        var filesCodable: [String: E2eeV20.Metadata.ciphertext.Files] = [:]
        var folders: [String: String] = [:]
        var counter: Int = 1

        func addUser(userId: String?, certificate: String?, key: Data) async {
            guard let userId, let certificate else { return }

            if let metadataKeyEncrypted = NCEndToEndEncryption.shared().encryptAsymmetricData(key, certificate: certificate) {
                let encryptedMetadataKey = metadataKeyEncrypted.base64EncodedString()
                await self.database.addE2EUsersAsync(account: session.account, serverUrl: serverUrl, ocIdServerUrl: ocIdServerUrl, userId: userId, certificate: certificate, encryptedMetadataKey: encryptedMetadataKey, metadataKey: key)
            }
        }

        if isDirectoryTop {
            guard var key = NCEndToEndEncryption.shared().generateKey() else {
                return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_"))
            }
            if let tableUserId = await self.database.getE2EUserAsync(account: session.account, directoryTopOcId: directoryTopOcId, userId: session.userId),
               let metadataKey = tableUserId.metadataKey {
                key = metadataKey
            } else {
                await addUser(userId: session.userId, certificate: certificate, key: key)
            }
            // ADDUSERID
            if let addUserId {
                await addUser(userId: addUserId, certificate: addCertificate, key: key)
            }
            // REMOVEUSERID
            if let removeUserId {
                await self.database.deleteE2EUsersAsync(account: session.account, ocIdServerUrl: ocIdServerUrl, userId: removeUserId)
            }

            let users = await self.database.getE2EUsersAsync(account: session.account, directoryTopOcId: directoryTopOcId)
            for user in users {
                await addUser(userId: user.userId, certificate: user.certificate, key: key)
            }

            metadataKey = key.base64EncodedString()

        } else {
            guard let tableUserId = await self.database.getE2EUserAsync(account: session.account, directoryTopOcId: directoryTopOcId, userId: session.userId), let key = tableUserId.metadataKey else {
                return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_"))
            }

            metadataKey = key.base64EncodedString()
        }

        // USERS
        // CHECKSUM
        //
        let users = await self.database.getE2EUsersAsync(account: session.account, directoryTopOcId: directoryTopOcId)
        for user in users {
            if isDirectoryTop {
                usersCodable.append(E2eeV20.Users(userId: user.userId, certificate: user.certificate, encryptedMetadataKey: user.encryptedMetadataKey))
            }
            if let hash = NCEndToEndEncryption.shared().createSHA256(user.metadataKey) {
                keyChecksums.append(hash)
            }
        }

        // COUNTER + 1
        //
        if let resultCounter = await self.database.getCounterE2eMetadataAsync(account: session.account, ocIdServerUrl: ocIdServerUrl) {
            counter = resultCounter + 1
        }

        // CIPERTEXT
        //
        let e2eEncryptions = await self.database.getE2eEncryptionsAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))

        for e2eEncryption in e2eEncryptions {
            if e2eEncryption.mimeType == "httpd/unix-directory" {
                folders[e2eEncryption.fileNameIdentifier] = e2eEncryption.fileName
            } else {
                let file = E2eeV20.Metadata.ciphertext.Files(authenticationTag: e2eEncryption.authenticationTag, filename: e2eEncryption.fileName, key: e2eEncryption.key, mimetype: e2eEncryption.mimeType, nonce: e2eEncryption.initializationVector)
                filesCodable.updateValue(file, forKey: e2eEncryption.fileNameIdentifier)
            }
        }

        do {
            var authenticationTag: NSString?
            var initializationVector: NSString?
            let json = try JSONEncoder().encode(E2eeV20.Metadata.ciphertext(counter: counter, deleted: false, keyChecksums: keyChecksums, files: filesCodable, folders: folders))
            let jsonZip = try json.gzipped()
            let ciphertextMetadata = NCEndToEndEncryption.shared().encryptPayloadFile(jsonZip, key: metadataKey, initializationVector: &initializationVector, authenticationTag: &authenticationTag)
            guard var ciphertextMetadata, let initializationVector = initializationVector as? String, let authenticationTag = authenticationTag as? String else {
                return (nil, nil, counter, NKError(errorCode: NCGlobal.shared.errorE2EEEncryptPayloadFile, errorDescription: "_e2e_error_"))
            }

            // Add initializationVector [ANDROID]
            ciphertextMetadata = ciphertextMetadata + "|" + initializationVector

            let metadataCodable = E2eeV20.Metadata(ciphertext: ciphertextMetadata, nonce: initializationVector, authenticationTag: authenticationTag)
            let e2eeCodable = E2eeV20(metadata: metadataCodable, users: usersCodable, filedrop: nil, version: NCGlobal.shared.e2eeVersionV20)
            let e2eeData = try JSONEncoder().encode(e2eeCodable)
            e2eeData.printJson()

            let e2eeJson = String(data: e2eeData, encoding: .utf8)
            let signature = createSignature(metadata: metadataCodable, users: usersCodable, version: NCGlobal.shared.e2eeVersionV20, certificate: certificate, session: session)

            return (e2eeJson, signature, counter, NKError())

        } catch let error {
            return (nil, nil, counter, NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription))
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata V2.0
    // --------------------------------------------------------------------------------------------

    func decodeMetadataV20(_ json: String, signature: String?, serverUrl: String, ocIdServerUrl: String, session: NCSession.Session) async -> NKError {
        let global = NCGlobal.shared
        guard let data = json.data(using: .utf8),
              let directoryTop = await utilityFileSystem.getMetadataE2EETopAsync(serverUrl: serverUrl, session: session) else {
            return NKError(errorCode: NCGlobal.shared.errorE2EEKeyDirectoryTop, errorDescription: "_e2e_error_")
        }
        let directoryTopOcId = directoryTop.ocId
        let isDirectoryTop = serverUrl == directoryTop.serverUrlFileName

        nkLog(tag: global.logTagE2EE, message: "Start decode metadata v2.0. Directory top: \(directoryTop)")

        func addE2eEncryption(fileNameIdentifier: String, fileName: String, authenticationTag: String, key: String, initializationVector: String, metadataKey: String, mimetype: String) async {
            if let metadata = await self.database.getMetadataAsync(predicate: NSPredicate(format: "account == %@ AND fileName == %@", session.account, fileNameIdentifier)) {
                let object = tableE2eEncryption.init(account: session.account, ocIdServerUrl: ocIdServerUrl, fileNameIdentifier: fileNameIdentifier)

                object.authenticationTag = authenticationTag
                object.fileName = fileName
                object.key = key
                object.initializationVector = initializationVector
                object.metadataKey = metadataKey
                object.mimeType = mimetype
                object.serverUrl = serverUrl
                object.version = NCGlobal.shared.e2eeVersionV20

                // Write file parameter for decrypted on DB
                await self.database.addE2eEncryptionAsync(object)

                // Update metadata on tableMetadata
                metadata.fileNameView = fileName

                // Update type
                let results = await NKTypeIdentifiers.shared.getInternalType(fileName: fileName, mimeType: "", directory: false, account: session.account)
                metadata.contentType = results.mimeType
                metadata.iconName = results.iconName
                metadata.classFile = results.classFile
                metadata.typeIdentifier = results.typeIdentifier

                await self.database.addMetadataAsync(metadata)
            }
        }

        do {
            let json = try JSONDecoder().decode(E2eeV20.self, from: data)
            let metadata = json.metadata
            let users = json.users
            let filesdrop = json.filedrop
            let version = json.version as String? ?? NCGlobal.shared.e2eeVersionV20

            if isDirectoryTop {

                // SAVE IN DB ALL USER
                //
                if let users {
                    for user in users {
                        var metadataKey: Data?
                        if let encryptedMetadataKey = user.encryptedMetadataKey {
                            let data = Data(base64Encoded: encryptedMetadataKey)
                            if let decrypted = NCEndToEndEncryption.shared().decryptAsymmetricData(data, privateKey: NCPreferences().getEndToEndPrivateKey(account: session.account)) {
                                metadataKey = decrypted
                            }
                        }
                        await self.database.addE2EUsersAsync(account: session.account, serverUrl: serverUrl, ocIdServerUrl: ocIdServerUrl, userId: user.userId, certificate: user.certificate, encryptedMetadataKey: user.encryptedMetadataKey, metadataKey: metadataKey)
                    }
                }
            }

            // GET metadataKey, decryptedMetadataKey
            //
            guard let tableUser = await self.database.getE2EUserAsync(account: session.account, directoryTopOcId: directoryTopOcId, userId: session.userId),
                  let metadataKey = tableUser.metadataKey?.base64EncodedString(),
                  let decryptedMetadataKey = tableUser.metadataKey else {
                nkLog(tag: global.logTagE2EE, message: "Error user not found")
                return NKError(errorCode: NCGlobal.shared.errorE2EENoUserFound, errorDescription: "_e2e_error_")
            }

            // SIGNATURE CHECK
            //
            if let signature {
                if !verifySignature(account: session.account, signature: signature, userId: tableUser.userId, metadata: metadata, users: users, version: version, certificate: tableUser.certificate) {
                    nkLog(tag: global.logTagE2EE, message: "Error verify signature")
                    return NKError(errorCode: NCGlobal.shared.errorE2EEKeyVerifySignature, errorDescription: "_e2e_error_")
                }
            }

            // FILEDROP
            //
            if let filesdrop {
                for filedop in filesdrop {
                    let fileNameIdentifier = filedop.key
                    let ciphertext = filedop.value.ciphertext
                    let nonce = filedop.value.nonce
                    let authenticationTag = filedop.value.authenticationTag
                    for user in filedop.value.users where user.userId == session.userId {
                        let data = Data(base64Encoded: user.encryptedFiledropKey)
                        if let decryptedFiledropKey = NCEndToEndEncryption.shared().decryptAsymmetricData(data, privateKey: NCPreferences().getEndToEndPrivateKey(account: session.account)) {
                            let filedropKey = decryptedFiledropKey.base64EncodedString()
                            guard let decryptedFiledrop = NCEndToEndEncryption.shared().decryptPayloadFile(ciphertext, key: filedropKey, initializationVector: nonce, authenticationTag: authenticationTag),
                                  decryptedFiledrop.isGzipped else {
                                nkLog(tag: global.logTagE2EE, message: "Error Filedrop Ciphertext")
                                return NKError(errorCode: NCGlobal.shared.errorE2EEKeyFiledropCiphertext, errorDescription: "_e2e_error_")
                            }
                            let data = try decryptedFiledrop.gunzipped()
                            if let jsonText = String(data: data, encoding: .utf8) { print(jsonText) }
                            let file = try JSONDecoder().decode(E2eeV20.Metadata.ciphertext.Files.self, from: data)
                            print(file)
                            await addE2eEncryption(fileNameIdentifier: fileNameIdentifier, fileName: file.filename, authenticationTag: file.authenticationTag, key: file.key, initializationVector: file.nonce, metadataKey: filedropKey, mimetype: file.mimetype)
                        }
                    }
                }
            }

            // CIPHERTEXT METADATA
            //
            guard let decryptedMetadata = NCEndToEndEncryption.shared().decryptPayloadFile(metadata.ciphertext, key: metadataKey, initializationVector: metadata.nonce, authenticationTag: metadata.authenticationTag),
                  decryptedMetadata.isGzipped else {
                nkLog(tag: global.logTagE2EE, message: "Error Key Ciphertext")
                return NKError(errorCode: NCGlobal.shared.errorE2EEKeyCiphertext, errorDescription: "_e2e_error_")
            }
            let data = try decryptedMetadata.gunzipped()
            if let jsonText = String(data: data, encoding: .utf8) { print(jsonText) }
            let jsonCiphertextMetadata = try JSONDecoder().decode(E2eeV20.Metadata.ciphertext.self, from: data)

            // CHECKSUM CHECK
            //
            if let keyChecksums = jsonCiphertextMetadata.keyChecksums, !keyChecksums.isEmpty {
                guard let hash = NCEndToEndEncryption.shared().createSHA256(decryptedMetadataKey),
                      keyChecksums.contains(hash) else {
                    nkLog(tag: global.logTagE2EE, message: "Error Key Checksums")
                    return NKError(errorCode: NCGlobal.shared.errorE2EEKeyChecksums, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
                }
            }

            print("\n\nCOUNTER -------------------------------")
            print("Counter: \(jsonCiphertextMetadata.counter)")

            // COUNTER CHECK
            //
            if let resultCounter = await self.database.getCounterE2eMetadataAsync(account: session.account, ocIdServerUrl: ocIdServerUrl) {
                nkLog(tag: global.logTagE2EE, message: "COUNTER CHECK: counter saved \(resultCounter), counter UPDATED: \(jsonCiphertextMetadata.counter)")
                await self.database.updateCounterE2eMetadataAsync(account: session.account, ocIdServerUrl: ocIdServerUrl, counter: jsonCiphertextMetadata.counter)
                // TODO: whats happen with < ?
                /*
                if jsonCiphertextMetadata.counter < resultCounter {
                    //NCContentPresenter().showError(error: NKError(errorCode: NCGlobal.shared.errorE2EECounter, errorDescription: NSLocalizedString("_e2e_error_", comment: "")))
                } else if jsonCiphertextMetadata.counter > resultCounter {
                    print("Counter UPDATED: \(jsonCiphertextMetadata.counter)")
                    await self.database.updateCounterE2eMetadataAsync(account: session.account, ocIdServerUrl: ocIdServerUrl, counter: jsonCiphertextMetadata.counter)
                }
                */
            } else {
                nkLog(tag: global.logTagE2EE, message: "COUNTER CHECK: counter RESET: \(jsonCiphertextMetadata.counter)")
                await self.database.updateCounterE2eMetadataAsync(account: session.account, ocIdServerUrl: ocIdServerUrl, counter: jsonCiphertextMetadata.counter)
            }

            // DELETE CHECK
            //
            if let deleted = jsonCiphertextMetadata.deleted, deleted {
                // TODO: We need to check deleted, id yes ???
            }

            await self.database.addE2eMetadataAsync(account: session.account,
                                                    serverUrl: serverUrl,
                                                    ocIdServerUrl: ocIdServerUrl,
                                                    keyChecksums: jsonCiphertextMetadata.keyChecksums,
                                                    deleted: jsonCiphertextMetadata.deleted ?? false,
                                                    folders: jsonCiphertextMetadata.folders,
                                                    version: version)

            if let files = jsonCiphertextMetadata.files {
                print("\nFILES ---------------------------------\n")
                for file in files {
                    await addE2eEncryption(fileNameIdentifier: file.key, fileName: file.value.filename, authenticationTag: file.value.authenticationTag, key: file.value.key, initializationVector: file.value.nonce, metadataKey: metadataKey, mimetype: file.value.mimetype)

                    print("filename: \(file.value.filename)")
                    print("fileNameIdentifier: \(file.key)")
                    print("mimetype: \(file.value.mimetype)")
                    print("\n")
                }
            }

            if let folders = jsonCiphertextMetadata.folders {
                print("FOLDERS--------------------------------\n")
                for folder in folders {
                    await addE2eEncryption(fileNameIdentifier: folder.key, fileName: folder.value, authenticationTag: metadata.authenticationTag, key: metadataKey, initializationVector: metadata.nonce, metadataKey: metadataKey, mimetype: "httpd/unix-directory")

                    print("filename: \(folder.value)")
                    print("fileNameIdentifier: \(folder.key)")
                    print("\n")
                }
            }

            print("---------------------------------------\n\n")

        } catch let error {
            nkLog(tag: global.logTagE2EE, message: "Error decoding JSON V2.0: \(error.localizedDescription)")
            return NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription)
        }

        return NKError()
    }

    // MARK: -

    func createSignature(metadata: E2eeV20.Metadata, users: [E2eeV20.Users]?, version: String, certificate: String, session: NCSession.Session) -> String? {
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
               let signatureData = NCEndToEndEncryption.shared().generateSignatureCMS(base64Data, certificate: certificate, privateKey: NCPreferences().getEndToEndPrivateKey(account: session.account), userId: session.userId) {
                return signatureData.base64EncodedString()
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }

        return nil
    }

    func verifySignature(account: String, signature: String, userId: String, metadata: E2eeV20.Metadata, users: [E2eeV20.Users]?, version: String, certificate: String) -> Bool {
        var signatureCodable: E2eeV20Signature?
        var certificates: [String] = []

        if let users {
            var usersSignatureCodable: [E2eeV20Signature.Users] = []
            for user in users {
                usersSignatureCodable.append(E2eeV20Signature.Users(userId: user.userId, certificate: user.certificate, encryptedMetadataKey: user.encryptedMetadataKey))
            }
            signatureCodable = E2eeV20Signature(metadata: E2eeV20Signature.Metadata(ciphertext: metadata.ciphertext, nonce: metadata.nonce, authenticationTag: metadata.authenticationTag), users: usersSignatureCodable, version: version)
            certificates = users.map { $0.certificate }
        } else {
            signatureCodable = E2eeV20Signature(metadata: E2eeV20Signature.Metadata(ciphertext: metadata.ciphertext, nonce: metadata.nonce, authenticationTag: metadata.authenticationTag), users: nil, version: version)
            certificates = [certificate]
        }

        do {
            let jsonEncoder = JSONEncoder()
            let json = try jsonEncoder.encode(signatureCodable)
            let dataSerialization = try JSONSerialization.jsonObject(with: json, options: [])
            if var dataSerialization = dataSerialization as? [String: Any?] {
                dataSerialization = dataSerialization.compactMapValues { $0 }
                let decodedSignatureCodable = try JSONSerialization.data(withJSONObject: dataSerialization, options: [.sortedKeys, .withoutEscapingSlashes])
                let base64 = decodedSignatureCodable.base64EncodedString()
                if let data = base64.data(using: .utf8), let signatureData = Data(base64Encoded: signature) {
                    return NCEndToEndEncryption.shared().verifySignatureCMS(signatureData, data: data, certificates: certificates)
                }
            }

        } catch {
            print("Error: \(error.localizedDescription)")
        }

        return false
    }
}
