// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB

/// Background Upload progress for an asset, destination and start/stop session.
struct NCAutoUploadAsset: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "autoUploadAsset"

    let account: String
    let serverUrlBase: String
    let assetLocalIdentifier: String
    let uploadSessionIdentifier: String
    // nil: component not expected; false: pending; true: uploaded.
    var photoUploaded: Bool?
    var videoUploaded: Bool?
    var photoFileName: String?
    var videoFileName: String?
    let creationDate: Date

    var isUploaded: Bool {
        let hasComponent = photoUploaded != nil || videoUploaded != nil
        return hasComponent && photoUploaded != false && videoUploaded != false
    }
}

/// Background Upload history shared by the extension and host-app chunk completion.
extension NCLocalDatabase {
    /// Saves expected components or confirmed uploads, preserving progress and the first assigned names.
    /// The returned record supplies the stable pair names for subsequent discovery passes.
    @discardableResult
    func recordAutoUploadAsset(_ asset: NCAutoUploadAsset) async throws -> NCAutoUploadAsset {
        let databasePool = try databasePool()
        return try await databasePool.write { database in
            if var stored = try NCAutoUploadAsset.fetchOne(database, key: [
                "account": asset.account,
                "serverUrlBase": asset.serverUrlBase,
                "assetLocalIdentifier": asset.assetLocalIdentifier,
                "uploadSessionIdentifier": asset.uploadSessionIdentifier
            ]) {
                if asset.photoUploaded != nil {
                    stored.photoUploaded = stored.photoUploaded == true || asset.photoUploaded == true
                }
                if asset.videoUploaded != nil {
                    stored.videoUploaded = stored.videoUploaded == true || asset.videoUploaded == true
                }
                stored.photoFileName = stored.photoFileName ?? asset.photoFileName
                stored.videoFileName = stored.videoFileName ?? asset.videoFileName
                try stored.update(database)
                return stored
            }
            try asset.insert(database)
            return asset
        }
    }

    /// Normal discovery reads all sessions; Force Reupload supplies the current session identifier.
    /// Callers check each required component across these records, rather than assuming a photo-only
    /// record also proves that the video of a Live Photo was uploaded.
    func autoUploadAssets(account: String, serverUrlBase: String, assetLocalIdentifier: String, sessionIdentifier: String? = nil) async throws -> [NCAutoUploadAsset] {
        let databasePool = try databasePool()
        return try await databasePool.read { database in
            var request = NCAutoUploadAsset
                .filter(Column("account") == account)
                .filter(Column("serverUrlBase") == serverUrlBase)
                .filter(Column("assetLocalIdentifier") == assetLocalIdentifier)
            if let sessionIdentifier {
                request = request.filter(Column("uploadSessionIdentifier") == sessionIdentifier)
            }
            return try request.fetchAll(database)
        }
    }

    func removeAutoUploadAssets(account: String, serverUrlBase: String) async throws {
        let databasePool = try databasePool()
        try await databasePool.write { database in
            _ = try NCAutoUploadAsset
                .filter(Column("account") == account)
                .filter(Column("serverUrlBase") == serverUrlBase)
                .deleteAll(database)
        }
    }
}
