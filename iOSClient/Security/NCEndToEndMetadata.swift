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
        
        struct metadataKey: Codable {
            
            let metadataKeys: [String: String]
            let version: Int
        }
        
        struct sharingKey: Codable {
            
            let recipient: [String: String]
        }
        
        struct encrypted: Codable {
            
            let key: String
            let filename: String
            let mimetype: String
            let version: Int
        }
        
        struct filesKey: Codable {
            
            let initializationVector: String
            let authenticationTag: String
            let metadataKey: Int
            let encrypted: String
        }
        
        let files: [String: filesKey]
        let metadata: metadataKey
        let sharing: sharingKey?
    }

    @objc static let sharedInstance: NCEndToEndMetadata = {
        let instance = NCEndToEndMetadata()
        return instance
    }()
    
    // let dataDecoded : NSData = NSData(base64Encoded: encrypted, options: NSData.Base64DecodingOptions(rawValue: 0))!
    @objc func decoderMetadata(_ e2eMetaDataJSON: String, privateKey: String, serverUrl: String, account: String) -> String? {
        
        let jsonDecoder = JSONDecoder.init()
        let data = e2eMetaDataJSON.data(using: .utf8)
        
        do {
            
            let decode = try jsonDecoder.decode(e2eMetadata.self, from: data!)
            
            let files = decode.files
            let metadata = decode.metadata
            //let sharing = decode.sharing ---> V 2.0
            
            var decodeMetadataKeys = [String:String]()
            
            for metadataKeys in metadata.metadataKeys {
                
                guard let metadataKeysData : NSData = NSData(base64Encoded: metadataKeys.value, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
                    return "Serious internal error in decoding metadata"
                }
                
                guard let metadataKey = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(metadataKeysData as Data!, privateKey: privateKey) else {
                    return "Serious internal error in decoding metadata"
                }
                
                // Encode to Base64
                let metadataKeyData = Data(base64Encoded: metadataKey, options: NSData.Base64DecodingOptions(rawValue: 0))!
                let metadataKeyBase64 = String(data: metadataKeyData, encoding: .utf8)
                
                decodeMetadataKeys[metadataKeys.key] = metadataKeyBase64
            }
            
            for file in files {
                
                let fileNameIdentifier = file.key
                let elementOfFile = file.value as e2eMetadata.filesKey
                
                let encrypted = elementOfFile.encrypted
                let key = decodeMetadataKeys["\(elementOfFile.metadataKey)"]
                
                guard let decyptedMetadata = NCEndToEndEncryption.sharedManager().decryptMetadata(encrypted, key: key) else {
                    return "Serious internal error in decoding metadata"
                }
                
                do {
                    
                    let decode = try jsonDecoder.decode(e2eMetadata.encrypted.self, from: decyptedMetadata.data(using: .utf8)!)
                    
                    let object = tableE2eEncryption()
                    
                    object.account = account
                    object.authenticationTag = elementOfFile.authenticationTag
                    object.fileName = decode.filename
                    object.fileNameIdentifier = fileNameIdentifier
                    object.key = decode.key
                    object.initializationVector = elementOfFile.initializationVector
                    object.mimeType = decode.mimetype
                    object.serverUrl = serverUrl
                    object.version = decode.version
                    
                    // Write file parameter for decrypted on DB
                    if NCManageDatabase.sharedInstance.addE2eEncryption(object) == false {
                        return "Serious internal write DB"
                    }
                    
                    // Write e2eMetaDataJSON on DB
                    if NCManageDatabase.sharedInstance.setDirectoryE2EMetadataJSON(serverUrl: serverUrl, metadata: e2eMetaDataJSON) == false {
                        return "Serious internal write DB"
                    }
                    
                } catch let error {
                    return "Serious internal error in decoding metadata ("+error.localizedDescription+")"
                }
            }
            
        } catch let error {
            return "Serious internal error in decoding metadata ("+error.localizedDescription+")"
        }
        
        return nil
    }
}
