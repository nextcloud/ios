// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB

/// Persistent local state for one PhotoKit asset and the resources it is expected to upload.
struct NCPhotoLibraryAsset: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "photoLibraryAsset"

    let account: String
    let assetLocalIdentifier: String
    var photoUploaded: Bool?
    var videoUploaded: Bool?
    let creationDate: Date

    /// The asset can be removed from Photos after every component that exists has been uploaded.
    var isUploaded: Bool {
        let hasComponent = photoUploaded != nil || videoUploaded != nil
        return hasComponent && photoUploaded != false && videoUploaded != false
    }
}

/// Stores PhotoKit asset progress independently from metadata refreshed by the server.
extension NCLocalDatabase {
    /// Registers the resources expected for an asset without resetting components already uploaded.
    func registerPhotoLibraryAsset(
        account: String,
        assetLocalIdentifier: String,
        hasPhoto: Bool,
        hasVideo: Bool,
        creationDate: Date
    ) async throws {
        guard hasPhoto || hasVideo else { return }

        let databasePool = try databasePool()
        try await databasePool.write { database in
            if var asset = try NCPhotoLibraryAsset.fetchOne(
                database,
                key: ["account": account, "assetLocalIdentifier": assetLocalIdentifier]
            ) {
                if hasPhoto, asset.photoUploaded == nil {
                    asset.photoUploaded = false
                }
                if hasVideo, asset.videoUploaded == nil {
                    asset.videoUploaded = false
                }
                try asset.update(database)
            } else {
                let asset = NCPhotoLibraryAsset(
                    account: account,
                    assetLocalIdentifier: assetLocalIdentifier,
                    photoUploaded: hasPhoto ? false : nil,
                    videoUploaded: hasVideo ? false : nil,
                    creationDate: creationDate
                )
                try asset.insert(database)
            }
        }
    }

    /// Marks the photo component as uploaded. Returns false when the asset or component is unknown.
    @discardableResult
    func markPhotoLibraryAssetPhotoUploaded(account: String, assetLocalIdentifier: String) async throws -> Bool {
        let databasePool = try databasePool()
        return try await databasePool.write { database in
            guard var asset = try NCPhotoLibraryAsset.fetchOne(
                database,
                key: ["account": account, "assetLocalIdentifier": assetLocalIdentifier]
            ), asset.photoUploaded != nil else {
                return false
            }

            if asset.photoUploaded == false {
                asset.photoUploaded = true
                try asset.update(database)
            }
            return true
        }
    }

    /// Marks the video component as uploaded. Returns false when the asset or component is unknown.
    @discardableResult
    func markPhotoLibraryAssetVideoUploaded(account: String, assetLocalIdentifier: String) async throws -> Bool {
        let databasePool = try databasePool()
        return try await databasePool.write { database in
            guard var asset = try NCPhotoLibraryAsset.fetchOne(
                database,
                key: ["account": account, "assetLocalIdentifier": assetLocalIdentifier]
            ), asset.videoUploaded != nil else {
                return false
            }

            if asset.videoUploaded == false {
                asset.videoUploaded = true
                try asset.update(database)
            }
            return true
        }
    }

    /// Returns assets for which every expected resource has completed its upload.
    func uploadedPhotoLibraryAssets(account: String) async throws -> [NCPhotoLibraryAsset] {
        let databasePool = try databasePool()
        return try await databasePool.read { database in
            try NCPhotoLibraryAsset
                .filter(Column("account") == account)
                .filter(sql: """
                    (photoUploaded IS NULL OR photoUploaded = 1)
                    AND (videoUploaded IS NULL OR videoUploaded = 1)
                    AND (photoUploaded IS NOT NULL OR videoUploaded IS NOT NULL)
                    """)
                .order(Column("creationDate"))
                .fetchAll(database)
        }
    }

    /// Removes state after Photos has confirmed deletion of the corresponding assets.
    func removePhotoLibraryAssets(account: String, assetLocalIdentifiers: [String]) async throws {
        guard !assetLocalIdentifiers.isEmpty else { return }

        let databasePool = try databasePool()
        try await databasePool.write { database in
            for assetLocalIdentifier in Set(assetLocalIdentifiers) {
                _ = try NCPhotoLibraryAsset.deleteOne(
                    database,
                    key: ["account": account, "assetLocalIdentifier": assetLocalIdentifier]
                )
            }
        }
    }
}
