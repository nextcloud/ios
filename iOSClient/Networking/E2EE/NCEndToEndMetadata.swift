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

    struct E2ee: Codable {

        struct Metadata: Codable {
            let metadataKeys: [String: String]
            let version: Int
        }

        struct Sharing: Codable {
            let recipient: [String: String]
        }

        struct Encrypted: Codable {
            let key: String
            let filename: String
            let mimetype: String
            let version: Int
        }

        struct Files: Codable {
            let initializationVector: String
            let authenticationTag: String
            let metadataKey: Int                // Number of metadataKey
            let encrypted: String               // encryptedFileAttributes
        }

        struct Filedrop: Codable {
            let initializationVector: String
            let authenticationTag: String?
            let metadataKey: Int                // Number of metadataKey
            let encrypted: String               // encryptedFileAttributes
        }

        let metadata: Metadata
        let files: [String: Files]?
        let filedrop: [String: Filedrop]?
        let sharing: Sharing?
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Encode / Decode JSON Metadata
    // --------------------------------------------------------------------------------------------

    func encoderMetadata(_ recordsE2eEncryption: [tableE2eEncryption], privateKey: String, serverUrl: String) -> String? {

        let jsonEncoder = JSONEncoder()
        var files: [String: E2ee.Files] = [:]
        var version = 1
        var metadataKeysDictionary: [String: String] = [:]

        for recordE2eEncryption in recordsE2eEncryption {

            // *** metadataKey ***

            // Encode64 for Android compatibility
            let metadatakey = (recordE2eEncryption.metadataKey.data(using: .utf8)?.base64EncodedString())!

            guard let metadataKeyEncryptedData = NCEndToEndEncryption.sharedManager().encryptAsymmetricString(metadatakey, publicKey: nil, privateKey: privateKey) else {
                return nil
            }

            let metadataKeyEncryptedBase64 = metadataKeyEncryptedData.base64EncodedString()

            metadataKeysDictionary["\(recordE2eEncryption.metadataKeyIndex)"] = metadataKeyEncryptedBase64

            // *** File ***

            let encrypted = E2ee.Encrypted(key: recordE2eEncryption.key, filename: recordE2eEncryption.fileName, mimetype: recordE2eEncryption.mimeType, version: recordE2eEncryption.version)

            do {

                // Create "encrypted"
                let encryptedJsonData = try jsonEncoder.encode(encrypted)
                let encryptedJsonString = String(data: encryptedJsonData, encoding: .utf8)

                guard let encryptedEncryptedJson = NCEndToEndEncryption.sharedManager().encryptEncryptedJson(encryptedJsonString, key: recordE2eEncryption.metadataKey) else {
                    print("Serious internal error in encoding metadata")
                    return nil
                }

                let e2eMetadataFilesKey = E2ee.Files(initializationVector: recordE2eEncryption.initializationVector, authenticationTag: recordE2eEncryption.authenticationTag, metadataKey: 0, encrypted: encryptedEncryptedJson)

                files.updateValue(e2eMetadataFilesKey, forKey: recordE2eEncryption.fileNameIdentifier)

            } catch let error {
                print("Serious internal error in encoding metadata (" + error.localizedDescription + ")")
                return nil
            }

            version = recordE2eEncryption.version
        }

        // Create Json metadataKeys
        // e2eMetadataKey = e2eMetadata.metadataKeyCodable(metadataKeys: ["0":metadataKeyEncryptedBase64], version: version)
        let e2eMetadataKey = E2ee.Metadata(metadataKeys: metadataKeysDictionary, version: version)

        // Create final Json e2emetadata
        let e2emetadata = E2ee(metadata: e2eMetadataKey, files: files, filedrop: nil, sharing: nil)

        do {

            let jsonData = try jsonEncoder.encode(e2emetadata)
            let jsonString = String(data: jsonData, encoding: .utf8)
            print("JSON String : " + jsonString!)

            return jsonString

        } catch let error {
            print("Serious internal error in encoding metadata (" + error.localizedDescription + ")")
            return nil
        }
    }

    func decoderMetadata(_ e2eMetaDataJSON: String, privateKey: String, serverUrl: String, account: String, urlBase: String, userId: String) -> Bool {
        guard let data = e2eMetaDataJSON.data(using: .utf8) else { return false }

        let jsonDecoder = JSONDecoder()
        // let dataQuickLook = (data as! NSData)

        do {

            let decode = try jsonDecoder.decode(E2ee.self, from: data)

            let metadata = decode.metadata
            let sharing = decode.sharing
            let files = decode.files
            let filedrop = decode.filedrop
            var metadataKeys: [String: String] = [:]

            // metadata

            for metadataKey in metadata.metadataKeys {

                if let metadataKeyData: NSData = NSData(base64Encoded: metadataKey.value, options: NSData.Base64DecodingOptions(rawValue: 0)),
                   let metadataKeyBase64 = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(metadataKeyData as Data?, privateKey: privateKey),
                   let metadataKeyBase64Data = Data(base64Encoded: metadataKeyBase64, options: NSData.Base64DecodingOptions(rawValue: 0)),
                   let key = String(data: metadataKeyBase64Data, encoding: .utf8) {
                    metadataKeys[metadataKey.key] = key
                }
            }

            // sharing

            if let sharing = sharing { }

            // files

            if let files = files {
                for file in files {

                    let files = file.value as E2ee.Files

                    let fileNameIdentifier = file.key
                    let encrypted = files.encrypted
                    let authenticationTag = files.authenticationTag
                    guard let metadataKey = metadataKeys["\(files.metadataKey)"] else { continue }
                    let metadataKeyIndex = files.metadataKey
                    let initializationVector = files.initializationVector

                    if let encrypted = NCEndToEndEncryption.sharedManager().decryptEncryptedJson(encrypted, key: metadataKey), let encryptedData = encrypted.data(using: .utf8) {
                        do {
                            let encrypted = try jsonDecoder.decode(E2ee.Encrypted.self, from: encryptedData)

                            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {
                                let metadata = tableMetadata.init(value: metadata)

                                let object = tableE2eEncryption()

                                object.account = account
                                object.authenticationTag = authenticationTag
                                object.blob = "files"
                                object.fileName = encrypted.filename
                                object.fileNameIdentifier = fileNameIdentifier
                                object.fileNamePath = CCUtility.returnFileNamePath(fromFileName: encrypted.filename, serverUrl: serverUrl, urlBase: urlBase, userId: userId, account: account)
                                object.key = encrypted.key
                                object.initializationVector = initializationVector
                                object.metadataKey = metadataKey
                                object.metadataKeyIndex = metadataKeyIndex
                                object.metadataVersion = 1
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

                                let results = NKCommon.shared.getInternalType(fileName: encrypted.filename, mimeType: metadata.contentType, directory: metadata.directory)

                                metadata.contentType = results.mimeType
                                metadata.iconName = results.iconName
                                metadata.classFile = results.classFile

                                NCManageDatabase.shared.addMetadata(metadata)
                            }

                        } catch let error {
                            print("Serious internal error in decoding metadata (" + error.localizedDescription + ")")
                            return false
                        }
                    }
                }
            }

            // filedrop

            if let filedrop = filedrop {
            }

        } catch let error {
            print("Serious internal error in decoding metadata (" + error.localizedDescription + ")")
            return false
        }

        return true
    }
}
