// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

extension NCManageDatabase {

    // MARK: - Realm Write

    /// Updates session-related fields for a given `tableMetadata` object, in an async-safe Realm write.
    ///
    /// - Parameters:
    ///   - ocId: Unique identifier of the metadata entry.
    ///   - newFileName: Optional new filename.
    ///   - session: Optional session identifier.
    ///   - sessionTaskIdentifier: Optional task ID.
    ///   - sessionError: Optional error string (clears error code if empty).
    ///   - selector: Optional session selector.
    ///   - status: Optional metadata status (may reset sessionDate).
    ///   - etag: Optional ETag string.
    ///   - errorCode: Optional error code to persist.
    /// - Returns: A detached copy of the updated `tableMetadata` object, or `nil` if not found.
    func setMetadataSessionAsync(account: String? = nil,
                                 ocId: String? = nil,
                                 serverUrlFileName: String? = nil,
                                 newFileName: String? = nil,
                                 session: String? = nil,
                                 sessionTaskIdentifier: Int? = nil,
                                 sessionError: String? = nil,
                                 selector: String? = nil,
                                 status: Int? = nil,
                                 etag: String? = nil,
                                 errorCode: Int? = nil) async {
        var query: NSPredicate = NSPredicate()
        if let ocId {
            query = NSPredicate(format: "ocId == %@", ocId)
        } else if let account, let serverUrlFileName {
            query = NSPredicate(format: "account == %@ AND serverUrlFileName == %@", account, serverUrlFileName)
        } else {
            return
        }

        await core.performRealmWriteAsync { realm in
            guard let metadata = realm.objects(tableMetadata.self)
                .filter(query)
                .first else {
                    return
            }

            metadata.sessionDate = Date()

            if let name = newFileName {
                metadata.fileName = name
                metadata.fileNameView = name
            }

            if let session {
                metadata.session = session
            }

            if let sessionTaskIdentifier {
                metadata.sessionTaskIdentifier = sessionTaskIdentifier
            }

            if let sessionError {
                metadata.sessionError = sessionError
                if sessionError.isEmpty {
                    metadata.errorCode = 0
                }
            }

            if let selector {
                metadata.sessionSelector = selector
            }

            if let status {
                metadata.status = status
                switch status {
                case NCGlobal.shared.metadataStatusWaitDownload,
                     NCGlobal.shared.metadataStatusWaitUpload:
                    metadata.sessionDate = Date()
                case NCGlobal.shared.metadataStatusNormal:
                    metadata.sessionDate = nil
                default: break
                }
            }

            if let etag {
                metadata.etag = etag
            }

            if let errorCode {
                metadata.errorCode = errorCode
            }
        }
    }

    /// Asynchronously sets a metadata record into "wait download" state.
    /// - Parameters:
    ///   - ocId: The object ID of the metadata.
    ///   - session: The session name to associate.
    ///   - selector: The selector name to track the download.
    ///   - sceneIdentifier: Optional scene ID.
    /// - Returns: An unmanaged copy of the updated metadata, or nil if not found.
    @discardableResult
    func setMetadataSessionInWaitDownloadAsync(ocId: String,
                                               session: String,
                                               selector: String,
                                               sceneIdentifier: String? = nil) async -> tableMetadata? {
        await core.performRealmWriteAsync { realm in
            guard let metadata = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first else {
                return
            }

            metadata.sessionDate = Date()
            metadata.sceneIdentifier = sceneIdentifier
            metadata.session = session
            metadata.sessionTaskIdentifier = 0
            metadata.sessionError = ""
            metadata.sessionSelector = selector
            metadata.status = NCGlobal.shared.metadataStatusWaitDownload
        }

        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first?
                .detachedCopy()
        }
    }

    /// Asynchronously clears session-related metadata for a list of `tableMetadata` entries.
    /// - Parameter metadatas: An array of `tableMetadata` objects to be cleared and updated.
    func clearMetadatasSessionAsync(metadatas: [tableMetadata]) async {
        guard !metadatas.isEmpty else {
            return
        }

        // Detach objects before modifying
        var detachedMetadatas = metadatas.map { $0.detachedCopy() }

        // Apply modifications
        detachedMetadatas = detachedMetadatas.map { metadata in
            metadata.sessionDate = nil
            metadata.sceneIdentifier = nil
            metadata.session = ""
            metadata.sessionTaskIdentifier = 0
            metadata.sessionError = ""
            metadata.sessionSelector = ""
            metadata.status = NCGlobal.shared.metadataStatusNormal
            return metadata
        }

        // Write to Realm asynchronously
        await core.performRealmWriteAsync { realm in
            detachedMetadatas.forEach { metadata in
                realm.add(metadata, update: .all)
            }
        }
    }

    func clearMetadatasSessionAsync(ocId: String) async {
        await core.performRealmWriteAsync { realm in
            guard let object = realm.object(ofType: tableMetadata.self, forPrimaryKey: ocId) else { return }

            object.session = ""
            object.sessionError = ""
            object.sessionTaskIdentifier = 0
            object.status = NCGlobal.shared.metadataStatusNormal
        }
    }
}
