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
        let users: [Users]
        let filedrop: [String: Filedrop]?
        let version: String
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Encode JSON Metadata Bridge
    // --------------------------------------------------------------------------------------------

    func encoderMetadata(account: String, serverUrl: String, userId: String) -> (metadata: String?, signature: String?) {

        let e2EEApiVersion = NCGlobal.shared.capabilityE2EEApiVersion

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (nil, nil)
        }

        switch e2EEApiVersion {
        case "1.2":
            return encoderMetadataV12(account: account, serverUrl: serverUrl, ocIdServerUrl: directory.ocId)
        case "2.0":
            return encoderMetadataV20(account: account, serverUrl: serverUrl, ocIdServerUrl: directory.ocId, userId: userId)
        default:
            return (nil, nil)
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata Bridge
    // --------------------------------------------------------------------------------------------

    func decoderMetadata(_ json: String, signature: String?, serverUrl: String, account: String, urlBase: String, userId: String, ownerId: String?) -> NKError {

        guard let data = json.data(using: .utf8), let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (NKError(errorCode: NCGlobal.shared.errorE2EE, errorDescription: "Error decoding JSON"))
        }

        data.printJson()

        let decoder = JSONDecoder()

        if (try? decoder.decode(E2eeV1.self, from: data)) != nil {
            return decoderMetadataV1(json, serverUrl: serverUrl, account: account, ocIdServerUrl: directory.ocId, urlBase: urlBase, userId: userId)
        } else if (try? decoder.decode(E2eeV12.self, from: data)) != nil {
            return decoderMetadataV12(json, serverUrl: serverUrl, account: account, ocIdServerUrl: directory.ocId, urlBase: urlBase, userId: userId, ownerId: ownerId)
        } else if (try? decoder.decode(E2eeV20.self, from: data)) != nil {
            return decoderMetadataV20(json, signature: signature, serverUrl: serverUrl, account: account, ocIdServerUrl: directory.ocId, urlBase: urlBase, userId: userId, ownerId: ownerId)
        } else {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "Server E2EE version " + NCGlobal.shared.capabilityE2EEApiVersion + ", not compatible")
        }
    }
}
