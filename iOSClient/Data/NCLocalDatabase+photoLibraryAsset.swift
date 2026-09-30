// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB
import NextcloudKit

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
    /// Registers the expected components and marks the resource confirmed by the server.
    /// Live Photos remain pending until both their photo and video components are uploaded.
    func recordPhotoLibraryAssetUpload(account: String, assetLocalIdentifier: String, classFile: String, isLivePhoto: Bool, creationDate: Date) async throws {
        guard !assetLocalIdentifier.isEmpty else { return }

        let isVideoComponent: Bool
        switch classFile {
        case NKTypeClassFile.image.rawValue:
            isVideoComponent = false
        case NKTypeClassFile.video.rawValue:
            isVideoComponent = true
        default:
            return
        }

        let hasPhoto = isLivePhoto || !isVideoComponent
        let hasVideo = isLivePhoto || isVideoComponent
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

                if isVideoComponent {
                    asset.videoUploaded = true
                } else {
                    asset.photoUploaded = true
                }
                try asset.update(database)
            } else {
                let asset = NCPhotoLibraryAsset(
                    account: account,
                    assetLocalIdentifier: assetLocalIdentifier,
                    photoUploaded: hasPhoto ? !isVideoComponent : nil,
                    videoUploaded: hasVideo ? isVideoComponent : nil,
                    creationDate: creationDate
                )
                try asset.insert(database)
            }
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
