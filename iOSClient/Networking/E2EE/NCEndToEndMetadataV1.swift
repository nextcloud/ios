//
//  NCEndToEndMetadataV1.swift
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
import UIKit
import NextcloudKit

extension NCEndToEndMetadata {

    struct E2eeV1: Codable {

        struct Metadata: Codable {
            let metadataKeys: [String: String]
            let version: Double
        }

        struct Encrypted: Codable {
            let key: String
            let filename: String
            let mimetype: String
        }

        struct Files: Codable {
            let initializationVector: String
            let authenticationTag: String?
            let metadataKey: Int
            let encrypted: String
        }

        let metadata: Metadata
        let files: [String: Files]?
    }

    struct E2eeV12: Codable {

        struct Metadata: Codable {
            let metadataKey: String
            let version: Double
            let checksum: String?
        }

        struct Encrypted: Codable {
            let key: String
            let filename: String
            let mimetype: String
        }

        struct Files: Codable {
            let initializationVector: String
            let authenticationTag: String?
            let encrypted: String
        }

        struct Filedrop: Codable {
            let initializationVector: String
            let authenticationTag: String?
            let encrypted: String
            let encryptedKey: String?
            let encryptedTag: String?
            let encryptedInitializationVector: String?
        }

        let metadata: Metadata
        let files: [String: Files]?
        let filedrop: [String: Filedrop]?
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Ecode JSON Metadata V1.2
    // --------------------------------------------------------------------------------------------

    func encodeMetadataV12(account: String, serverUrl: String, ocIdServerUrl: String) -> (metadata: String?, signature: String?, counter: Int, error: NKError) {

        let encoder = JSONEncoder()
        var metadataKey: String = ""
        let metadataVersion = 1.2
        var files: [String: E2eeV12.Files] = [:]
        var filesCodable: [String: E2eeV12.Files]?
        var filedrop: [String: E2eeV12.Filedrop] = [:]
        var filedropCodable: [String: E2eeV12.Filedrop]?
        let privateKey = NCKeychain().getEndToEndPrivateKey(account: account)
        var fileNameIdentifiers: [String] = []

        let e2eEncryptions = self.database.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))

        //
        // metadata
        //
        if e2eEncryptions.isEmpty, let key = NCEndToEndEncryption.shared().generateKey() as? NSData {

            if let key = key.base64EncodedString().data(using: .utf8)?.base64EncodedString().data(using: .utf8),
               let metadataKeyEncrypted = NCEndToEndEncryption.shared().encryptAsymmetricData(key, privateKey: privateKey) {
                metadataKey = metadataKeyEncrypted.base64EncodedString()
            }

        } else if let metadatakey = (e2eEncryptions.first!.metadataKey.data(using: .utf8)?.base64EncodedString().data(using: .utf8)),
                  let metadataKeyEncrypted = NCEndToEndEncryption.shared().encryptAsymmetricData(metadatakey, privateKey: privateKey) {

            metadataKey = metadataKeyEncrypted.base64EncodedString()
        }

        for e2eEncryption in e2eEncryptions {

            //
            // files & folders
            //
            if e2eEncryption.blob == "files" || e2eEncryption.blob == "folders" {
                let encrypted = E2eeV12.Encrypted(key: e2eEncryption.key, filename: e2eEncryption.fileName, mimetype: e2eEncryption.mimeType)
                do {
                    // Create "encrypted"
                    var json = try encoder.encode(encrypted)
                    json = json.base64EncodedString().data(using: .utf8)!
                    if let encrypted = NCEndToEndEncryption.shared().encryptPayloadFile(json, key: e2eEncryption.metadataKey) {
                        let record = E2eeV12.Files(initializationVector: e2eEncryption.initializationVector, authenticationTag: e2eEncryption.authenticationTag, encrypted: encrypted)
                        files.updateValue(record, forKey: e2eEncryption.fileNameIdentifier)
                    }
                    fileNameIdentifiers.append(e2eEncryption.fileNameIdentifier)
                } catch let error {
                    return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription))
                }
            }

            //
            // filedrop
            //
            if e2eEncryption.blob == "filedrop" {

                var encryptedKey: String?
                var encryptedInitializationVector: NSString?
                var encryptedTag: NSString?

                if let metadataKeyFiledrop = (e2eEncryption.metadataKey.data(using: .utf8)?.base64EncodedString().data(using: .utf8)),
                   let metadataKeyEncrypted = NCEndToEndEncryption.shared().encryptAsymmetricData(metadataKeyFiledrop, privateKey: privateKey) {
                    encryptedKey = metadataKeyEncrypted.base64EncodedString()
                }
                let encrypted = E2eeV12.Encrypted(key: e2eEncryption.key, filename: e2eEncryption.fileName, mimetype: e2eEncryption.mimeType)
                do {
                    // Create "encrypted"
                    var json = try encoder.encode(encrypted)
                    json = json.base64EncodedString().data(using: .utf8)!
                    if let encrypted = NCEndToEndEncryption.shared().encryptPayloadFile(json, key: e2eEncryption.metadataKey, initializationVector: &encryptedInitializationVector, authenticationTag: &encryptedTag) {
                        let record = E2eeV12.Filedrop(initializationVector: e2eEncryption.initializationVector, authenticationTag: e2eEncryption.authenticationTag, encrypted: encrypted, encryptedKey: encryptedKey, encryptedTag: encryptedTag as? String, encryptedInitializationVector: encryptedInitializationVector as? String)
                        filedrop.updateValue(record, forKey: e2eEncryption.fileNameIdentifier)
                    }
                } catch let error {
                    return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription))
                }
            }
        }

        // Create checksum
        let passphrase = NCKeychain().getEndToEndPassphrase(account: account)?.replacingOccurrences(of: " ", with: "") ?? ""
        let dataChecksum = (passphrase + fileNameIdentifiers.sorted().joined() + metadataKey).data(using: .utf8)
        let checksum = NCEndToEndEncryption.shared().createSHA256(dataChecksum)

        // Create Json
        let metadata = E2eeV12.Metadata(metadataKey: metadataKey, version: metadataVersion, checksum: checksum)
        if !files.isEmpty { filesCodable = files }
        if !filedrop.isEmpty { filedropCodable = filedrop }
        let e2ee = E2eeV12(metadata: metadata, files: filesCodable, filedrop: filedropCodable)
        do {
            let data = try encoder.encode(e2ee)
            data.printJson()
            let jsonString = String(data: data, encoding: .utf8)
            // Updated metadata to 1.2
            if self.database.getE2eMetadata(account: account, serverUrl: serverUrl) == nil {
                self.database.setE2eMetadata(account: account, serverUrl: serverUrl, metadataKey: metadataKey, version: metadataVersion)
            }
            return (jsonString, nil, 0, NKError())
        } catch let error {
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription))
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata V1.2
    // --------------------------------------------------------------------------------------------

    func decodeMetadataV12(_ json: String, serverUrl: String, ocIdServerUrl: String, session: NCSession.Session) -> NKError {

        guard let data = json.data(using: .utf8) else {
            return NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: "_e2e_error_")
        }

        let decoder = JSONDecoder()
        let privateKey = NCKeychain().getEndToEndPrivateKey(account: session.account)
        var metadataVersion: Double = 0
        var metadataKey = ""

        do {
            let json = try decoder.decode(E2eeV12.self, from: data)

            let metadata = json.metadata
            let files = json.files
            let filedrop = json.filedrop
            var fileNameIdentifiers: [String] = []

            metadataVersion = metadata.version

            //
            // metadata
            //
            let data = Data(base64Encoded: metadata.metadataKey)

            if let decrypted = NCEndToEndEncryption.shared().decryptAsymmetricData(data, privateKey: privateKey),
                let keyData = Data(base64Encoded: decrypted),
                let key = String(data: keyData, encoding: .utf8) {
                metadataKey = key
            } else {
                return NKError(errorCode: NCGlobal.shared.errorE2EEKeyDecodeMetadata, errorDescription: "_e2e_error_")
            }

            // DATA
            self.database.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))

            //
            // files
            //
            if let files = files {
                for file in files {
                    let fileNameIdentifier = file.key
                    let files = file.value as E2eeV12.Files
                    let encrypted = files.encrypted
                    let authenticationTag = files.authenticationTag
                    let initializationVector = files.initializationVector

                    fileNameIdentifiers.append(fileNameIdentifier)

                    if let decrypted = NCEndToEndEncryption.shared().decryptPayloadFile(encrypted, key: metadataKey),
                       let decryptedData = Data(base64Encoded: decrypted) {
                        do {
                            decryptedData.printJson()
                            let encrypted = try decoder.decode(E2eeV12.Encrypted.self, from: decryptedData)

                            if let metadata = self.database.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", session.account, fileNameIdentifier)) {

                                let object = tableE2eEncryption.init(account: session.account, ocIdServerUrl: ocIdServerUrl, fileNameIdentifier: fileNameIdentifier)

                                object.authenticationTag = authenticationTag ?? ""
                                object.blob = "files"
                                object.fileName = encrypted.filename
                                object.key = encrypted.key
                                object.initializationVector = initializationVector
                                object.metadataKey = metadataKey
                                object.version = "\(metadataVersion)"
                                object.mimeType = encrypted.mimetype
                                object.serverUrl = serverUrl

                                // Write file parameter for decrypted on DB
                                self.database.addE2eEncryption(object)

                                // Update metadata on tableMetadata
                                metadata.fileNameView = encrypted.filename

                                let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: encrypted.filename, mimeType: metadata.contentType, directory: metadata.directory, account: session.account)

                                metadata.contentType = results.mimeType
                                metadata.iconName = results.iconName
                                metadata.classFile = results.classFile

                                self.database.addMetadata(metadata)
                            }

                        } catch let error {
                            return NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription)
                        }
                    }
                }
            }

            //
            // filedrop
            //
            if let filedrop = filedrop {
                for filedrop in filedrop {
                    let fileNameIdentifier = filedrop.key
                    let filedrop = filedrop.value as E2eeV12.Filedrop
                    var metadataKeyFiledrop: String?

                    if let encryptedKey = filedrop.encryptedKey,
                       let data = Data(base64Encoded: encryptedKey),
                       let decrypted = NCEndToEndEncryption.shared().decryptAsymmetricData(data, privateKey: privateKey) {
                        let keyData = Data(base64Encoded: decrypted)
                        metadataKeyFiledrop = String(data: keyData!, encoding: .utf8)
                    }

                    if let decrypted = NCEndToEndEncryption.shared().decryptPayloadFile(filedrop.encrypted, key: metadataKeyFiledrop, initializationVector: filedrop.encryptedInitializationVector, authenticationTag: filedrop.encryptedTag),
                       let decryptedData = Data(base64Encoded: decrypted) {
                        do {
                            decryptedData.printJson()
                            let encrypted = try decoder.decode(E2eeV1.Encrypted.self, from: decryptedData)

                            if let metadata = self.database.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", session.account, fileNameIdentifier)) {

                                let object = tableE2eEncryption.init(account: session.account, ocIdServerUrl: ocIdServerUrl, fileNameIdentifier: fileNameIdentifier)

                                object.authenticationTag = filedrop.authenticationTag ?? ""
                                object.blob = "filedrop"
                                object.fileName = encrypted.filename
                                object.key = encrypted.key
                                object.initializationVector = filedrop.initializationVector
                                object.metadataKey = metadataKey
                                object.version = "\(metadataVersion)"
                                object.mimeType = encrypted.mimetype
                                object.serverUrl = serverUrl

                                // Write file parameter for decrypted on DB
                                self.database.addE2eEncryption(object)

                                // Update metadata on tableMetadata
                                metadata.fileNameView = encrypted.filename

                                let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: encrypted.filename, mimeType: metadata.contentType, directory: metadata.directory, account: session.account)

                                metadata.contentType = results.mimeType
                                metadata.iconName = results.iconName
                                metadata.classFile = results.classFile

                                self.database.addMetadata(metadata)
                            }

                        } catch let error {
                            return NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription)
                        }
                    }
                }
            }

            // verify checksum
            let passphrase = NCKeychain().getEndToEndPassphrase(account: session.account)?.replacingOccurrences(of: " ", with: "") ?? ""
            let dataChecksum = (passphrase + fileNameIdentifiers.sorted().joined() + metadata.metadataKey).data(using: .utf8)
            let checksum = NCEndToEndEncryption.shared().createSHA256(dataChecksum)
            if metadata.checksum != checksum {
                return NKError(errorCode: NCGlobal.shared.errorE2EEKeyChecksums, errorDescription: "_e2e_error_")
            }
        } catch let error {
            return NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription)
        }

        return NKError()
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata V1.1
    // --------------------------------------------------------------------------------------------

    func decodeMetadataV1(_ json: String, serverUrl: String, ocIdServerUrl: String, session: NCSession.Session) -> NKError {

        guard let data = json.data(using: .utf8) else {
            return NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: "_e2e_error_")
        }

        let decoder = JSONDecoder()
        let privateKey = NCKeychain().getEndToEndPrivateKey(account: session.account)
        var metadataVersion: Double = 0

        do {
            let json = try decoder.decode(E2eeV1.self, from: data)

            let metadata = json.metadata
            let files = json.files
            var metadataKeys: [String: String] = [:]

            metadataVersion = metadata.version

            // DATA
            self.database.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))

            //
            // metadata
            //
            for metadataKey in metadata.metadataKeys {
                let data = Data(base64Encoded: metadataKey.value)
                if let decrypted = NCEndToEndEncryption.shared().decryptAsymmetricData(data, privateKey: privateKey),
                   let keyData = Data(base64Encoded: decrypted) {
                    let key = String(data: keyData, encoding: .utf8)
                    metadataKeys[metadataKey.key] = key
                }
            }

            //
            // verify version
            //
            if let tableE2eMetadata = self.database.getE2eMetadata(account: session.account, serverUrl: serverUrl) {
                if tableE2eMetadata.version > metadataVersion {
                    return NKError(errorCode: NCGlobal.shared.errorE2EEVersion, errorDescription: "Version \(tableE2eMetadata.version)")
                }
            }

            //
            // files
            //
            if let files = files {
                for files in files {
                    let fileNameIdentifier = files.key
                    let files = files.value as E2eeV1.Files

                    let encrypted = files.encrypted
                    let authenticationTag = files.authenticationTag
                    guard let metadataKey = metadataKeys["\(files.metadataKey)"] else { continue }
                    let metadataKeyIndex = files.metadataKey
                    let initializationVector = files.initializationVector

                    if let decrypted = NCEndToEndEncryption.shared().decryptPayloadFile(encrypted, key: metadataKey),
                       let decryptedData = Data(base64Encoded: decrypted) {
                        do {
                            let encrypted = try decoder.decode(E2eeV1.Encrypted.self, from: decryptedData)

                            if let metadata = self.database.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", session.account, fileNameIdentifier)) {

                                let object = tableE2eEncryption.init(account: session.account, ocIdServerUrl: ocIdServerUrl, fileNameIdentifier: fileNameIdentifier)

                                object.authenticationTag = authenticationTag ?? ""
                                object.blob = "files"
                                object.fileName = encrypted.filename
                                object.key = encrypted.key
                                object.initializationVector = initializationVector
                                object.metadataKey = metadataKey
                                object.metadataKeyIndex = metadataKeyIndex
                                object.version = "\(metadataVersion)"
                                object.mimeType = encrypted.mimetype
                                object.serverUrl = serverUrl

                                // Write file parameter for decrypted on DB
                                self.database.addE2eEncryption(object)

                                // Update metadata on tableMetadata
                                metadata.fileNameView = encrypted.filename

                                let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: encrypted.filename, mimeType: metadata.contentType, directory: metadata.directory, account: session.account)

                                metadata.contentType = results.mimeType
                                metadata.iconName = results.iconName
                                metadata.classFile = results.classFile

                                self.database.addMetadata(metadata)
                            }

                        } catch let error {
                            return NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription)
                        }
                    }
                }
            }
        } catch let error {
            return NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: error.localizedDescription)
        }

        return NKError()
    }
}
