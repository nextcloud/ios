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
import SwiftyJSON

class NCEndToEndMetadata: NSObject {

    struct E2eMetadata: Codable {

        struct MetadataKeyCodable: Codable {
            let metadataKeys: [String: String]
            let version: Int
        }

        struct SharingCodable: Codable {

            let recipient: [String: String]
        }

        struct EncryptedFileAttributes: Codable {

            let key: String
            let filename: String
            let mimetype: String
            let version: Int
        }

        struct FilesCodable: Codable {

            let initializationVector: String
            let authenticationTag: String?
            let metadataKey: Int                // Number of metadataKey
            let encrypted: String               // encryptedFileAttributes
        }

        let files: [String: FilesCodable]
        let metadata: MetadataKeyCodable
        let sharing: SharingCodable?
    }

    @objc static let shared: NCEndToEndMetadata = {
        let instance = NCEndToEndMetadata()
        return instance
    }()

    // --------------------------------------------------------------------------------------------
    // MARK: Encode / Decode JSON Metadata
    // --------------------------------------------------------------------------------------------

    @objc func encoderMetadata(_ recordsE2eEncryption: [tableE2eEncryption], privateKey: String, serverUrl: String) -> String? {

        let jsonEncoder = JSONEncoder()
        var files: [String: E2eMetadata.FilesCodable] = [:]
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

            let encrypted = E2eMetadata.EncryptedFileAttributes(key: recordE2eEncryption.key, filename: recordE2eEncryption.fileName, mimetype: recordE2eEncryption.mimeType, version: recordE2eEncryption.version)

            do {

                // Create "encrypted"
                let encryptedJsonData = try jsonEncoder.encode(encrypted)
                let encryptedJsonString = String(data: encryptedJsonData, encoding: .utf8)

                guard let encryptedEncryptedJson = NCEndToEndEncryption.sharedManager().encryptEncryptedJson(encryptedJsonString, key: recordE2eEncryption.metadataKey) else {
                    print("Serious internal error in encoding metadata")
                    return nil
                }

                let e2eMetadataFilesKey = E2eMetadata.FilesCodable(initializationVector: recordE2eEncryption.initializationVector, authenticationTag: recordE2eEncryption.authenticationTag, metadataKey: 0, encrypted: encryptedEncryptedJson)

                files.updateValue(e2eMetadataFilesKey, forKey: recordE2eEncryption.fileNameIdentifier)

            } catch let error {
                print("Serious internal error in encoding metadata (" + error.localizedDescription + ")")
                return nil
            }

            version = recordE2eEncryption.version
        }

        // Create Json metadataKeys
        // e2eMetadataKey = e2eMetadata.metadataKeyCodable(metadataKeys: ["0":metadataKeyEncryptedBase64], version: version)
        let e2eMetadataKey = E2eMetadata.MetadataKeyCodable(metadataKeys: metadataKeysDictionary, version: version)

        // Create final Json e2emetadata
        let e2emetadata = E2eMetadata(files: files, metadata: e2eMetadataKey, sharing: nil)

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

    @discardableResult
    @objc func decoderMetadata(_ e2eMetaDataJSON: String, privateKey: String, serverUrl: String, account: String, urlBase: String, userId: String) -> Bool {
        guard let data = e2eMetaDataJSON.data(using: .utf8) else { return false }

        do {
            let json = try JSON(data: data)

            let metadata = json["metadata"]
            var metadataKeys: [Int: String] = [:]

            let files = json["files"]
            let filedrop = json["filedrop"]

            //
            // ---[ metadata ]---
            //
            let metadataVersion = metadata["version"].intValue
            // metadataKeys
            let metadataMetadataKeys = metadata["metadataKeys"]
            for (key, value): (String, JSON) in metadataMetadataKeys {
                if let encryptedMetadataKey = value.string,
                   let index = Int(key),
                   let metadataKeyEncryptedData = NSData(base64Encoded: encryptedMetadataKey, options: NSData.Base64DecodingOptions(rawValue: 0)),
                   let metadataKeyBase64 = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(metadataKeyEncryptedData as Data?, privateKey: privateKey),
                   let metadataKeyBase64Data = Data(base64Encoded: metadataKeyBase64, options: NSData.Base64DecodingOptions(rawValue: 0)),
                   let metadataKey = String(data: metadataKeyBase64Data, encoding: .utf8) {
                    metadataKeys[index] = metadataKey
                }
            }

            //
            // ---[ files ]---
            //
            for (key, subJson): (String, JSON) in files {
                let fileNameIdentifier = key
                let initializationVector = subJson["initializationVector"].stringValue
                let index = subJson["metadataKey"].intValue
                let authenticationTag = subJson["authenticationTag"].stringValue
                let encrypted = subJson["encrypted"].string
                if let metadataKey = metadataKeys[index],
                   let jsonString = NCEndToEndEncryption.sharedManager().decryptEncryptedJson(encrypted, key: metadataKey),
                   let data = jsonString.data(using: .utf8) {
                    do {
                        let json = try JSON(data: data)
                        let object = tableE2eEncryption()

                        if let key = json["key"].string,
                           let filename = json["filename"].string,
                           let mimetype = json["mimetype"].string,
                           let version = json["version"].int,
                           let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {

                            object.account = account
                            object.authenticationTag = authenticationTag
                            object.blob = "files"
                            object.fileName = filename
                            object.fileNameIdentifier = fileNameIdentifier
                            object.fileNamePath = CCUtility.returnFileNamePath(fromFileName: filename, serverUrl: serverUrl, urlBase: urlBase, userId: userId, account: account)
                            object.key = key
                            object.initializationVector = initializationVector
                            object.metadataKey = metadataKey
                            object.metadataKeyIndex = index
                            object.metadataVersion = metadataVersion
                            object.mimeType = mimetype
                            object.serverUrl = serverUrl
                            object.version = version

                            // If exists remove records
                            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNamePath == %@", object.account, object.fileNamePath))
                            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNameIdentifier == %@", object.account, object.fileNameIdentifier))

                            // Write file parameter for decrypted on DB
                            NCManageDatabase.shared.addE2eEncryption(object)

                            // Update metadata on tableMetadata
                            metadata.fileNameView = filename

                            let results = NKCommon.shared.getInternalType(fileName: filename, mimeType: metadata.contentType, directory: metadata.directory)

                            metadata.contentType = results.mimeType
                            metadata.iconName = results.iconName
                            metadata.classFile = results.classFile

                            NCManageDatabase.shared.addMetadata(metadata)
                        }
                    } catch { }
                }
            }

            //
            // ---[ filedrop ]---
            //
            for (key, subJson): (String, JSON) in filedrop {
                let fileNameIdentifier = key
                let initializationVector = subJson["initializationVector"].stringValue
                let index = subJson["metadataKey"].intValue
                let authenticationTag = subJson["authenticationTag"].stringValue

                if let encrypted = subJson["encrypted"].string,
                   let encryptedData = NSData(base64Encoded: encrypted, options: NSData.Base64DecodingOptions(rawValue: 0)),
                   let encryptedBase64 = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(encryptedData as Data?, privateKey: privateKey),
                   let encryptedBase64Data = Data(base64Encoded: encryptedBase64, options: NSData.Base64DecodingOptions(rawValue: 0)),
                   let jsonString = String(data: encryptedBase64Data, encoding: .utf8),
                   let data = jsonString.data(using: .utf8) {
                    do {
                        let json = try JSON(data: data)
                        let object = tableE2eEncryption()

                        if let key = json["key"].string,
                           let filename = json["filename"].string,
                           let mimetype = json["mimetype"].string,
                           let version = json["version"].int,
                           let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {

                            object.account = account
                            object.authenticationTag = authenticationTag
                            object.blob = "filedrop"
                            object.fileName = filename
                            object.fileNameIdentifier = fileNameIdentifier
                            object.fileNamePath = CCUtility.returnFileNamePath(fromFileName: filename, serverUrl: serverUrl, urlBase: urlBase, userId: userId, account: account)
                            object.key = key
                            object.initializationVector = initializationVector
                            object.metadataKey = encrypted
                            object.metadataKeyIndex = index
                            object.metadataVersion = metadataVersion
                            object.mimeType = mimetype
                            object.serverUrl = serverUrl
                            object.version = version

                            // If exists remove records
                            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNamePath == %@", object.account, object.fileNamePath))
                            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNameIdentifier == %@", object.account, object.fileNameIdentifier))

                            // Write file parameter for decrypted on DB
                            NCManageDatabase.shared.addE2eEncryption(object)

                            // Update metadata on tableMetadata
                            metadata.fileNameView = filename

                            let results = NKCommon.shared.getInternalType(fileName: filename, mimeType: metadata.contentType, directory: metadata.directory)

                            metadata.contentType = results.mimeType
                            metadata.iconName = results.iconName
                            metadata.classFile = results.classFile

                            NCManageDatabase.shared.addMetadata(metadata)
                        }
                    } catch { }
                }
            }

        } catch let error {
            print("Serious internal error in decoding metadata (" + error.localizedDescription + ")")
            return false
        }

        return true
    }
}
