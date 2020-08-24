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

import Foundation
import NCCommunication

class NCEndToEndMetadata : NSObject  {

    struct e2eMetadata: Codable {
        
        struct metadataKeyCodable: Codable {
            
            let metadataKeys: [String: String]
            let version: Int
        }
        
        struct sharingCodable: Codable {
            
            let recipient: [String: String]
        }
        
        struct encryptedFileAttributes: Codable {
            
            let key: String
            let filename: String
            let mimetype: String
            let version: Int
        }
        
        struct filesCodable: Codable {
            
            let initializationVector: String
            let authenticationTag: String?
            let metadataKey: Int                // Number of metadataKey
            let encrypted: String               // encryptedFileAttributes
        }
        
        let files: [String: filesCodable]
        let metadata: metadataKeyCodable
        let sharing: sharingCodable?
    }

    @objc static let sharedInstance: NCEndToEndMetadata = {
        let instance = NCEndToEndMetadata()
        return instance
    }()
    
    // --------------------------------------------------------------------------------------------
    // MARK: Encode / Decode JSON Metadata
    // --------------------------------------------------------------------------------------------
    
    @objc func encoderMetadata(_ recordsE2eEncryption: [tableE2eEncryption], privateKey: String, serverUrl: String) -> String? {
        
        let jsonEncoder = JSONEncoder.init()
        var files: [String: e2eMetadata.filesCodable] = [:]
        var version = 1
        var metadataKeysDictionary: [String: String] = [:]
        
        for recordE2eEncryption in recordsE2eEncryption {
            
            // *** metadataKey ***
            
            // Double Encode64 for Android compatibility
            let metadatakey = (recordE2eEncryption.metadataKey.data(using: .utf8)?.base64EncodedString())!
            
            guard let metadataKeyEncryptedData = NCEndToEndEncryption.sharedManager().encryptAsymmetricString(metadatakey, publicKey: nil, privateKey: privateKey) else {
                return nil
            }
            
            let metadataKeyEncryptedBase64 = metadataKeyEncryptedData.base64EncodedString()
            
            metadataKeysDictionary["\(recordE2eEncryption.metadataKeyIndex)"] = metadataKeyEncryptedBase64
            
            // *** File ***
            
            let encrypted = e2eMetadata.encryptedFileAttributes(key: recordE2eEncryption.key, filename: recordE2eEncryption.fileName, mimetype: recordE2eEncryption.mimeType, version: recordE2eEncryption.version)
            
            do {
                
                // Create "encrypted"
                let encryptedJsonData = try jsonEncoder.encode(encrypted)
                let encryptedJsonString = String(data: encryptedJsonData, encoding: .utf8)
                
                guard let encryptedEncryptedJson = NCEndToEndEncryption.sharedManager().encryptEncryptedJson(encryptedJsonString, key: recordE2eEncryption.metadataKey) else {
                    print("Serious internal error in encoding metadata")
                    return nil
                }
                
                let e2eMetadataFilesKey = e2eMetadata.filesCodable(initializationVector: recordE2eEncryption.initializationVector, authenticationTag: recordE2eEncryption.authenticationTag, metadataKey: 0, encrypted: encryptedEncryptedJson)
                
                files.updateValue(e2eMetadataFilesKey, forKey: recordE2eEncryption.fileNameIdentifier)
                
            } catch let error {
                print("Serious internal error in encoding metadata ("+error.localizedDescription+")")
                return nil
            }
            
            version = recordE2eEncryption.version
        }

        // Create Json metadataKeys
        //e2eMetadataKey = e2eMetadata.metadataKeyCodable(metadataKeys: ["0":metadataKeyEncryptedBase64], version: version)
        let e2eMetadataKey = e2eMetadata.metadataKeyCodable(metadataKeys: metadataKeysDictionary, version: version)
        
        // Create final Json e2emetadata
        let e2emetadata = e2eMetadata(files: files, metadata: e2eMetadataKey, sharing: nil)
        
        do {
            
            let jsonData = try jsonEncoder.encode(e2emetadata)
            let jsonString = String(data: jsonData, encoding: .utf8)
            print("JSON String : " + jsonString!)
                        
            return jsonString
            
        } catch let error {
            print("Serious internal error in encoding metadata ("+error.localizedDescription+")")
            return nil
        }
    }
    
    @discardableResult
    @objc func decoderMetadata(_ e2eMetaDataJSON: String, privateKey: String, serverUrl: String, account: String, urlBase: String) -> Bool {
        
        let jsonDecoder = JSONDecoder.init()
        let data = e2eMetaDataJSON.data(using: .utf8)
        //let dataQuickLook = (data as! NSData)
                
        do {
            
            // *** metadataKey ***
            
            let decode = try jsonDecoder.decode(e2eMetadata.self, from: data!)
            
            let files = decode.files
            let metadata = decode.metadata
            //let sharing = decode.sharing ---> V 2.0
            var metadataKeysDictionary: [String: String] = [:]
            
            for metadataKeyDictionaryEncrypted in metadata.metadataKeys {
                
                guard let metadataKeyEncryptedData : NSData = NSData(base64Encoded: metadataKeyDictionaryEncrypted.value, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
                    return false
                }
                
                guard let metadataKeyBase64 = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(metadataKeyEncryptedData as Data?, privateKey: privateKey) else {
                    return false
                }
                
                // Initialize a `Data` from a Base-64 encoded String
                let metadataKeyBase64Data = Data(base64Encoded: metadataKeyBase64, options: NSData.Base64DecodingOptions(rawValue: 0))!
                let metadataKey = String(data: metadataKeyBase64Data, encoding: .utf8)
                
                metadataKeysDictionary[metadataKeyDictionaryEncrypted.key] = metadataKey
            }
            
            // *** File ***
            
            for file in files {
                
                let fileNameIdentifier = file.key
                let filesCodable = file.value as e2eMetadata.filesCodable
                
                let encrypted = filesCodable.encrypted
                let metadataKey = metadataKeysDictionary["\(filesCodable.metadataKey)"]
                
                guard let encryptedFileAttributesJson = NCEndToEndEncryption.sharedManager().decryptEncryptedJson(encrypted, key: metadataKey) else {
                    return false
                }
                
                do {
                    let encryptedFileAttributes = try jsonDecoder.decode(e2eMetadata.encryptedFileAttributes.self, from: encryptedFileAttributesJson.data(using: .utf8)!)
                    if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@", account, fileNameIdentifier)) {
                        let metadata = tableMetadata.init(value: metadata)
                    
                        let object = tableE2eEncryption()
                    
                        object.account = account
                        object.authenticationTag = filesCodable.authenticationTag ?? ""
                        object.fileName = encryptedFileAttributes.filename
                        object.fileNameIdentifier = fileNameIdentifier
                        object.fileNamePath = CCUtility.returnFileNamePath(fromFileName: encryptedFileAttributes.filename, serverUrl: serverUrl, urlBase: urlBase, account: account)
                        object.key = encryptedFileAttributes.key
                        object.initializationVector = filesCodable.initializationVector
                        object.metadataKey = metadataKey!
                        object.metadataKeyIndex = filesCodable.metadataKey
                        object.mimeType = encryptedFileAttributes.mimetype
                        object.serverUrl = serverUrl
                        object.version = encryptedFileAttributes.version
                    
                        // If exists remove records
                        NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNamePath == %@", object.account, object.fileNamePath))
                        NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNameIdentifier == %@", object.account, object.fileNameIdentifier))
                        
                        // Write file parameter for decrypted on DB
                        NCManageDatabase.sharedInstance.addE2eEncryption(object)
                        
                        // Update metadata on tableMetadata
                        metadata.fileNameView = encryptedFileAttributes.filename
                        
                        let results = NCCommunicationCommon.shared.getInternalContenType(fileName: encryptedFileAttributes.filename, contentType: metadata.contentType, directory: metadata.directory)
                        
                        metadata.contentType = results.contentType
                        metadata.iconName = results.iconName
                        metadata.typeFile = results.typeFile
                                                
                        NCManageDatabase.sharedInstance.addMetadata(metadata)
                    }
                    
                } catch let error {
                    print("Serious internal error in decoding metadata ("+error.localizedDescription+")")
                }
            }
            
        } catch let error {
            print("Serious internal error in decoding metadata ("+error.localizedDescription+")")
            return false
        }
        
        return true
    }
}
