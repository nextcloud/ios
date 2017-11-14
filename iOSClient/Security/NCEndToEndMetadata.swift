//
//  NCEndToEndMetadata.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/11/17.
//  Copyright © 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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
            let authenticationTag: String
            let metadataKey: Int
            let encrypted: String // encryptedFile
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
    
    @objc func encoderMetadata(_ recordsE2eEncryption: [tableE2eEncryption], publicKey: String) -> String? {
        
        let jsonEncoder = JSONEncoder.init()
        var files = [String: e2eMetadata.filesCodable]()
        var version = 1
        
        // Create "files"
        for recordE2eEncryption in recordsE2eEncryption {
            
            let encrypted = e2eMetadata.encryptedFileAttributes(key: recordE2eEncryption.key, filename: recordE2eEncryption.fileName, mimetype: recordE2eEncryption.mimeType, version: recordE2eEncryption.version)
            
            do {
                
                // Create "encrypted"
                let encryptedJsonData = try jsonEncoder.encode(encrypted)
                let encryptedJsonString = String(data: encryptedJsonData, encoding: .utf8)
                
                guard let encryptedEncryptionData = NCEndToEndEncryption.sharedManager().encryptAsymmetricString(encryptedJsonString, publicKey: publicKey) else {
                    print("Serious internal error in encoding metadata")
                    return nil
                }
                
                let encryptedEncryptionBase64 = encryptedEncryptionData.base64EncodedString()
                
                let e2eMetadataFilesKey = e2eMetadata.filesCodable(initializationVector: recordE2eEncryption.initializationVector, authenticationTag: recordE2eEncryption.authenticationTag, metadataKey: 0, encrypted: encryptedEncryptionBase64)
                
                files.updateValue(e2eMetadataFilesKey, forKey: recordE2eEncryption.fileNameIdentifier)
                
            } catch let error {
                print("Serious internal error in encoding metadata ("+error.localizedDescription+")")
                return nil
            }
            
            version = recordE2eEncryption.version
        }
        
        // Create "metadataKey" with encrypted publicKey
        let e2eMetadataKey = e2eMetadata.metadataKeyCodable(metadataKeys: ["0":"dcccecfvdfvfvsfdvefvefvefvefvefv"], version: version)
        
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
    
    @objc func decoderMetadata(_ e2eMetaDataJSON: String, privateKey: String, serverUrl: String, account: String, url: String) -> Bool {
        
        let jsonDecoder = JSONDecoder.init()
        let data = e2eMetaDataJSON.data(using: .utf8)
        
        do {
            
            let decode = try jsonDecoder.decode(e2eMetadata.self, from: data!)
            
            let files = decode.files
            let metadata = decode.metadata
            //let sharing = decode.sharing ---> V 2.0
            
            var publicKeys = [String:String]()
            
            for metadataKeys in metadata.metadataKeys {
                
                guard let publicKeyEncryptedData : NSData = NSData(base64Encoded: metadataKeys.value, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
                    return false
                }
                
                guard let publicKeyBase64 = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(publicKeyEncryptedData as Data!, privateKey: privateKey) else {
                    return false
                }
                
                // Initialize a `Data` from a Base-64 encoded String
                let publicKeyBase64Data = Data(base64Encoded: publicKeyBase64, options: NSData.Base64DecodingOptions(rawValue: 0))!
                let publicKey = String(data: publicKeyBase64Data, encoding: .utf8)
                
                publicKeys[metadataKeys.key] = publicKey
            }
            
            for file in files {
                
                let fileNameIdentifier = file.key
                let filesCodable = file.value as e2eMetadata.filesCodable
                
                let encrypted = filesCodable.encrypted
                let key = publicKeys["\(filesCodable.metadataKey)"]
                
                guard let encryptedFileAttributesJson = NCEndToEndEncryption.sharedManager().decryptMetadata(encrypted, key: key) else {
                    return false
                }
                
                do {
                    
                    let encryptedFileAttributes = try jsonDecoder.decode(e2eMetadata.encryptedFileAttributes.self, from: encryptedFileAttributesJson.data(using: .utf8)!)
                    
                    let object = tableE2eEncryption()
                    
                    object.account = account
                    object.authenticationTag = filesCodable.authenticationTag
                    object.fileName = encryptedFileAttributes.filename
                    object.fileNameIdentifier = fileNameIdentifier
                    object.fileNamePath = CCUtility.returnFileNamePath(fromFileName: encryptedFileAttributes.filename, serverUrl: serverUrl, activeUrl: url)
                    object.key = encryptedFileAttributes.key
                    object.initializationVector = filesCodable.initializationVector
                    object.mimeType = encryptedFileAttributes.mimetype
                    object.serverUrl = serverUrl
                    object.version = encryptedFileAttributes.version
                    
                    // Write file parameter for decrypted on DB
                    if NCManageDatabase.sharedInstance.addE2eEncryption(object) == false {
                        return false
                    }
                    
                    // Write e2eMetaDataJSON on DB
                    if NCManageDatabase.sharedInstance.setDirectoryE2EMetadataJSON(serverUrl: serverUrl, metadata: e2eMetaDataJSON) == false {
                        return false
                    }
                    
                } catch let error {
                    print("Serious internal error in decoding metadata ("+error.localizedDescription+")")
                    return false
                }
            }
            
        } catch let error {
            print("Serious internal error in decoding metadata ("+error.localizedDescription+")")
            return false
        }
        
        return true
    }
}
