//
//  NCEndToEndMetadata.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/11/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
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

import UIKit
import NextcloudKit

class NCEndToEndMetadata: NSObject {

    struct E2eeV1: Codable {

        struct Metadata: Codable {
            let metadataKeys: [String: String]
            let version: Double
        }

        struct Encrypted: Codable {
            let key: String
            let filename: String
            let mimetype: String
            let version: Double
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
        }

        struct Encrypted: Codable {
            let key: String
            let filename: String
            let mimetype: String
            let version: Double
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
        }

        let metadata: Metadata
        let files: [String: Files]?
        let filedrop: [String: Filedrop]?
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Encode JSON Metadata V1.2
    // --------------------------------------------------------------------------------------------

    func encoderMetadata(_ items: [tableE2eEncryption], account: String, serverUrl: String) -> String? {

        let encoder = JSONEncoder()
        var metadataKey: String = ""
        let metadataVersion = 1.2
        var files: [String: E2eeV12.Files] = [:]
        var filesCodable: [String: E2eeV12.Files]?
        var filedrop: [String: E2eeV12.Filedrop] = [:]
        var filedropCodable: [String: E2eeV12.Filedrop]?
        let privateKey = CCUtility.getEndToEndPrivateKey(account)

        for item in items {

            //
            // metadata
            //
            if let metadatakey = (item.metadataKey.data(using: .utf8)?.base64EncodedString()),
               let metadataKeyEncrypted = NCEndToEndEncryption.sharedManager().encryptAsymmetricString(metadatakey, publicKey: nil, privateKey: privateKey) {
                metadataKey = metadataKeyEncrypted.base64EncodedString()
            }

            //
            // files
            //
            if item.blob == "files" {
                let encrypted = E2eeV12.Encrypted(key: item.key, filename: item.fileName, mimetype: item.mimeType, version: item.version)
                do {
                    // Create "encrypted"
                    let json = try encoder.encode(encrypted)
                    let encryptedString = String(data: json, encoding: .utf8)
                    if let encrypted = NCEndToEndEncryption.sharedManager().encryptEncryptedJson(encryptedString, key: item.metadataKey) {
                        let record = E2eeV12.Files(initializationVector: item.initializationVector, authenticationTag: item.authenticationTag, encrypted: encrypted)
                        files.updateValue(record, forKey: item.fileNameIdentifier)
                    }
                } catch let error {
                    print("Serious internal error in encoding metadata (" + error.localizedDescription + ")")
                    return nil
                }
            }

            //
            // filedrop
            //
            if item.blob == "filedrop" {
                let encrypted = E2eeV12.Encrypted(key: item.key, filename: item.fileName, mimetype: item.mimeType, version: item.version)
                do {
                    // Create "encrypted"
                    let json = try encoder.encode(encrypted)
                    let encryptedString = (json.base64EncodedString())
                    if let encryptedData = NCEndToEndEncryption.sharedManager().encryptAsymmetricString(encryptedString, publicKey: nil, privateKey: privateKey) {
                        let encrypted = encryptedData.base64EncodedString()
                        let record = E2eeV12.Filedrop(initializationVector: item.initializationVector, authenticationTag: item.authenticationTag, encrypted: encrypted)
                        filedrop.updateValue(record, forKey: item.fileNameIdentifier)
                    }
                } catch let error {
                    print("Serious internal error in encoding metadata (" + error.localizedDescription + ")")
                    return nil
                }
            }
        }

        // Create Json
        let metadata = E2eeV12.Metadata(metadataKey: metadataKey, version: metadataVersion)
        if !files.isEmpty { filesCodable = files }
        if !filedrop.isEmpty { filedropCodable = filedrop }
        let e2ee = E2eeV12(metadata: metadata, files: filesCodable, filedrop: filedropCodable)
        do {
            let data = try encoder.encode(e2ee)
            data.printJson()
            let jsonString = String(data: data, encoding: .utf8)
            return jsonString
        } catch let error {
            print("Serious internal error in encoding e2ee (" + error.localizedDescription + ")")
            return nil
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata Bridge
    // --------------------------------------------------------------------------------------------

    func decoderMetadata(_ json: String, serverUrl: String, account: String, urlBase: String, userId: String, ownerId: String?) -> Bool {
        guard let data = json.data(using: .utf8) else { return false }

        data.printJson()

        let decoder = JSONDecoder()

        if (try? decoder.decode(E2eeV1.self, from: data)) != nil {
            return decoderMetadataV1(json, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId)
        } else if (try? decoder.decode(E2eeV12.self, from: data)) != nil {
            return decoderMetadataV12(json, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId, ownerId: ownerId)
        } else {
            return false
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata V1
    // --------------------------------------------------------------------------------------------

    func decoderMetadataV1(_ json: String, serverUrl: String, account: String, urlBase: String, userId: String) -> Bool {
        guard let data = json.data(using: .utf8) else { return false }

        let decoder = JSONDecoder()
        let privateKey = CCUtility.getEndToEndPrivateKey(account)

        do {
            data.printJson()
            let json = try decoder.decode(E2eeV1.self, from: data)

            let metadata = json.metadata
            let files = json.files
            var metadataKeys: [String: String] = [:]
            let metadataVersion = metadata.version

            //
            // metadata
            //
            for metadataKey in metadata.metadataKeys {
                let data = Data(base64Encoded: metadataKey.value)
                if let decrypted = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(data, privateKey: privateKey),
                   let keyData = Data(base64Encoded: decrypted) {
                    let key = String(data: keyData, encoding: .utf8)
                    metadataKeys[metadataKey.key] = key
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

                    if let decrypted = NCEndToEndEncryption.sharedManager().decryptEncryptedJson(encrypted, key: metadataKey),
                       let decryptedData = Data(base64Encoded: decrypted) {
                        do {
                            let encrypted = try decoder.decode(E2eeV1.Encrypted.self, from: decryptedData)

                            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {

                                let object = tableE2eEncryption()

                                object.account = account
                                object.authenticationTag = authenticationTag ?? ""
                                object.blob = "files"
                                object.fileName = encrypted.filename
                                object.fileNameIdentifier = fileNameIdentifier
                                object.fileNamePath = CCUtility.returnFileNamePath(fromFileName: encrypted.filename, serverUrl: serverUrl, urlBase: urlBase, userId: userId, account: account)
                                object.key = encrypted.key
                                object.initializationVector = initializationVector
                                object.metadataKey = metadataKey
                                object.metadataKeyIndex = metadataKeyIndex
                                object.metadataVersion = metadataVersion
                                object.mimeType = encrypted.mimetype
                                object.serverUrl = serverUrl
                                object.version = encrypted.version

                                // If exists remove records
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNamePath == %@", object.account, object.fileNamePath))
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNameIdentifier == %@", object.account, object.fileNameIdentifier))

                                // Write file parameter for decrypted on DB
                                NCManageDatabase.shared.addE2eEncryption(object)

                                // Update metadata on tableMetadata
                                metadata.fileNameView = encrypted.filename

                                let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: encrypted.filename, mimeType: metadata.contentType, directory: metadata.directory)

                                metadata.contentType = results.mimeType
                                metadata.iconName = results.iconName
                                metadata.classFile = results.classFile

                                NCManageDatabase.shared.addMetadata(metadata)
                            }

                        } catch let error {
                            print("Serious internal error in decoding files (" + error.localizedDescription + ")")
                            return false
                        }
                    }
                }
            }
        } catch let error {
            print("Serious internal error in decoding metadata (" + error.localizedDescription + ")")
            return false
        }

        return true
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata V12
    // --------------------------------------------------------------------------------------------

    func decoderMetadataV12(_ json: String, serverUrl: String, account: String, urlBase: String, userId: String, ownerId: String?) -> Bool {
        guard let data = json.data(using: .utf8) else { return false }

        let decoder = JSONDecoder()
        let privateKey = CCUtility.getEndToEndPrivateKey(account)

        do {
            data.printJson()
            let json = try decoder.decode(E2eeV12.self, from: data)

            let metadata = json.metadata
            let files = json.files
            let filedrop = json.filedrop
            var metadataKey = ""
            let metadataVersion = metadata.version

            //
            // metadata
            //
            let data = Data(base64Encoded: metadata.metadataKey)
            if let decrypted = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(data, privateKey: privateKey),
                let keyData = Data(base64Encoded: decrypted),
                let key = String(data: keyData, encoding: .utf8) {
                metadataKey = key
            } else {
                print("Serious internal error in decoding metadataKey")
                return false
            }

            //
            // files
            //
            if let files = files {
                for files in files {
                    let fileNameIdentifier = files.key
                    let files = files.value as E2eeV12.Files

                    let encrypted = files.encrypted
                    let authenticationTag = files.authenticationTag
                    let initializationVector = files.initializationVector

                    if let decrypted = NCEndToEndEncryption.sharedManager().decryptEncryptedJson(encrypted, key: metadataKey),
                       let decryptedData = Data(base64Encoded: decrypted) {
                        do {
                            decryptedData.printJson()
                            let encrypted = try decoder.decode(E2eeV12.Encrypted.self, from: decryptedData)

                            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {

                                let object = tableE2eEncryption()

                                object.account = account
                                object.authenticationTag = authenticationTag ?? ""
                                object.blob = "files"
                                object.fileName = encrypted.filename
                                object.fileNameIdentifier = fileNameIdentifier
                                object.fileNamePath = CCUtility.returnFileNamePath(fromFileName: encrypted.filename, serverUrl: serverUrl, urlBase: urlBase, userId: userId, account: account)
                                object.key = encrypted.key
                                object.initializationVector = initializationVector
                                object.metadataKey = metadataKey
                                object.metadataVersion = metadataVersion
                                object.mimeType = encrypted.mimetype
                                object.serverUrl = serverUrl
                                object.version = encrypted.version

                                // If exists remove records
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNamePath == %@", object.account, object.fileNamePath))
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNameIdentifier == %@", object.account, object.fileNameIdentifier))

                                // Write file parameter for decrypted on DB
                                NCManageDatabase.shared.addE2eEncryption(object)

                                // Update metadata on tableMetadata
                                metadata.fileNameView = encrypted.filename

                                let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: encrypted.filename, mimeType: metadata.contentType, directory: metadata.directory)

                                metadata.contentType = results.mimeType
                                metadata.iconName = results.iconName
                                metadata.classFile = results.classFile

                                NCManageDatabase.shared.addMetadata(metadata)
                            }

                        } catch let error {
                            print("Serious internal error in decoding files (" + error.localizedDescription + ")")
                            return false
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

                    let encrypted = filedrop.encrypted
                    let authenticationTag = filedrop.authenticationTag
                    let initializationVector = filedrop.initializationVector

                    /*
                    if let encryptedData = NSData(base64Encoded: encrypted, options: NSData.Base64DecodingOptions(rawValue: 0)),
                       let encryptedBase64 = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(encryptedData as Data?, privateKey: privateKey),
                       let encryptedBase64Data = Data(base64Encoded: encryptedBase64, options: NSData.Base64DecodingOptions(rawValue: 0)),
                       let encrypted = String(data: encryptedBase64Data, encoding: .utf8),
                       let encryptedData = encrypted.data(using: .utf8) {
                     */

                    let data = Data(base64Encoded: encrypted)
                    if let decrypted = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(data, privateKey: privateKey),
                       let decryptedData = Data(base64Encoded: decrypted) {
                        do {
                            let encrypted = try decoder.decode(E2eeV1.Encrypted.self, from: decryptedData)

                            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {

                                let object = tableE2eEncryption()

                                object.account = account
                                object.authenticationTag = authenticationTag ?? ""
                                object.blob = "filedrop"
                                object.fileName = encrypted.filename
                                object.fileNameIdentifier = fileNameIdentifier
                                object.fileNamePath = CCUtility.returnFileNamePath(fromFileName: encrypted.filename, serverUrl: serverUrl, urlBase: urlBase, userId: userId, account: account)
                                object.key = encrypted.key
                                object.initializationVector = initializationVector
                                object.metadataKey = metadataKey
                                object.metadataVersion = metadataVersion
                                object.mimeType = encrypted.mimetype
                                object.serverUrl = serverUrl
                                object.version = encrypted.version

                                // If exists remove records
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNamePath == %@", object.account, object.fileNamePath))
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNameIdentifier == %@", object.account, object.fileNameIdentifier))

                                // Write file parameter for decrypted on DB
                                NCManageDatabase.shared.addE2eEncryption(object)

                                // Update metadata on tableMetadata
                                metadata.fileNameView = encrypted.filename

                                let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: encrypted.filename, mimeType: metadata.contentType, directory: metadata.directory)

                                metadata.contentType = results.mimeType
                                metadata.iconName = results.iconName
                                metadata.classFile = results.classFile

                                NCManageDatabase.shared.addMetadata(metadata)
                            }

                        } catch let error {
                            print("Serious internal error in decoding filedrop (" + error.localizedDescription + ")")
                            return false
                        }
                    }
                }
            }

        } catch let error {
            print("Serious internal error in decoding metadata (" + error.localizedDescription + ")")
            return false
        }

        return true
    }
}
