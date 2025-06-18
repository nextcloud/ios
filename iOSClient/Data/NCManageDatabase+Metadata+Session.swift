// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

extension NCManageDatabase {

    // MARK: - Realm Write

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
    @discardableResult
    func setMetadataSession(ocId: String,
                            newFileName: String? = nil,
                            session: String? = nil,
                            sessionTaskIdentifier: Int? = nil,
                            sessionError: String? = nil,
                            selector: String? = nil,
                            status: Int? = nil,
                            etag: String? = nil,
                            errorCode: Int? = nil,
                            sync: Bool = true) -> tableMetadata? {
        var detached: tableMetadata?

        performRealmWrite(sync: sync) { realm in
            guard let metadata = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else {
                return
            }

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

            realm.add(metadata, update: .all)
            detached = tableMetadata(value: metadata)
        }

        return detached
    }

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
    @discardableResult
    func setMetadataSessionAsync(
        ocId: String,
        newFileName: String? = nil,
        session: String? = nil,
        sessionTaskIdentifier: Int? = nil,
        sessionError: String? = nil,
        selector: String? = nil,
        status: Int? = nil,
        etag: String? = nil,
        errorCode: Int? = nil
    ) async -> tableMetadata? {
        var detached: tableMetadata?

        await performRealmWriteAsync { realm in
            guard let metadata = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first else {
                    return
            }

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

            realm.add(metadata, update: .all)
            detached = tableMetadata(value: metadata) // Detach from thread-confined Realm object
        }

        return detached
    }

    /// - Parameters:
    ///   - metadatas: Array of metadata objects to update.
    ///   - session: The session name to associate.
    ///   - selector: The selector name to track the download.
    ///   - sceneIdentifier: Optional scene ID.
    func setMetadatasSessionInWaitDownload(metadatas: [tableMetadata],
                                           session: String,
                                           selector: String,
                                           sceneIdentifier: String? = nil) {
        guard !metadatas.isEmpty else {
            return
        }
        let detached = metadatas.map { tableMetadata(value: $0) }

        performRealmWrite(sync: true) { realm in
            for metadata in detached {
                metadata.sceneIdentifier = sceneIdentifier
                metadata.session = session
                metadata.sessionTaskIdentifier = 0
                metadata.sessionError = ""
                metadata.sessionSelector = selector
                metadata.status = NCGlobal.shared.metadataStatusWaitDownload
                metadata.sessionDate = Date()

                realm.add(metadata, update: .all)
            }
        }
    }

    /// Asynchronously sets multiple metadata entries into "wait download" state.
    /// - Parameters:
    ///   - metadatas: Array of metadata objects to update.
    ///   - session: The session name to associate.
    ///   - selector: The selector name to track the download.
    ///   - sceneIdentifier: Optional scene ID.
    func setMetadatasSessionInWaitDownloadAsync(metadatas: [tableMetadata],
                                                session: String,
                                                selector: String,
                                                sceneIdentifier: String? = nil) async {
        guard !metadatas.isEmpty else {
            return
        }

        let detached = metadatas.map { tableMetadata(value: $0) }

        return await performRealmWriteAsync { realm in
            for metadata in detached {
                metadata.sceneIdentifier = sceneIdentifier
                metadata.session = session
                metadata.sessionTaskIdentifier = 0
                metadata.sessionError = ""
                metadata.sessionSelector = selector
                metadata.status = NCGlobal.shared.metadataStatusWaitDownload
                metadata.sessionDate = Date()

                realm.add(metadata, update: .all)
            }
        }
    }

    /// - Parameters:
    ///   - ocId: The object ID of the metadata.
    ///   - session: The session name to associate.
    ///   - selector: The selector name to track the download.
    ///   - sceneIdentifier: Optional scene ID.
    /// - Returns: An unmanaged copy of the updated metadata, or nil if not found.
    @discardableResult
    func setMetadataSessionInWaitDownload(ocId: String,
                                          session: String,
                                          selector: String,
                                          sceneIdentifier: String? = nil) -> tableMetadata? {
        var detached: tableMetadata?

        performRealmWrite(sync: true) { realm in
            guard let metadata = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else {
                return
            }

            metadata.sceneIdentifier = sceneIdentifier
            metadata.session = session
            metadata.sessionTaskIdentifier = 0
            metadata.sessionError = ""
            metadata.sessionSelector = selector
            metadata.status = NCGlobal.shared.metadataStatusWaitDownload
            metadata.sessionDate = Date()

            realm.add(metadata, update: .all)
            detached = tableMetadata(value: metadata)
        }

        return detached
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

        var detached: tableMetadata?

        await performRealmWriteAsync { realm in
            guard let metadata = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first else {
                return
            }

            metadata.sceneIdentifier = sceneIdentifier
            metadata.session = session
            metadata.sessionTaskIdentifier = 0
            metadata.sessionError = ""
            metadata.sessionSelector = selector
            metadata.status = NCGlobal.shared.metadataStatusWaitDownload
            metadata.sessionDate = Date()

            realm.add(metadata, update: .all)
            detached = tableMetadata(value: metadata) // Detach from thread-confined Realm object
        }

        return detached
    }

    func clearMetadatasSession(metadatas: [tableMetadata]) {
        guard !metadatas.isEmpty
        else {
            return
        }
        let detachedMetadatas = metadatas.map { tableMetadata(value: $0) }

        performRealmWrite(sync: true) { realm in
            detachedMetadatas.forEach { metadata in
                metadata.sceneIdentifier = nil
                metadata.session = ""
                metadata.sessionTaskIdentifier = 0
                metadata.sessionError = ""
                metadata.sessionSelector = ""
                metadata.sessionDate = nil
                metadata.status = NCGlobal.shared.metadataStatusNormal

                realm.add(metadata, update: .all)
            }
        }
    }

    /// Asynchronously clears session-related metadata for a list of `tableMetadata` entries.
    /// - Parameter metadatas: An array of `tableMetadata` objects to be cleared and updated.
    func clearMetadatasSessionAsync(metadatas: [tableMetadata]) async {
        guard !metadatas.isEmpty else {
            return
        }

        // Detach objects before modifying
        var detachedMetadatas = metadatas.map { tableMetadata(value: $0) }

        // Apply modifications
        detachedMetadatas = detachedMetadatas.map { metadata in
            metadata.sceneIdentifier = nil
            metadata.session = ""
            metadata.sessionTaskIdentifier = 0
            metadata.sessionError = ""
            metadata.sessionSelector = ""
            metadata.sessionDate = nil
            metadata.status = NCGlobal.shared.metadataStatusNormal
            return metadata
        }

        // Write to Realm asynchronously
        await performRealmWriteAsync { realm in
            detachedMetadatas.forEach { metadata in
                realm.add(metadata, update: .all)
            }
        }
    }

    func clearMetadataSession(metadata: tableMetadata) {
        let detached = tableMetadata(value: metadata)

        detached.sceneIdentifier = nil
        detached.session = ""
        detached.sessionTaskIdentifier = 0
        detached.sessionError = ""
        detached.sessionSelector = ""
        detached.sessionDate = nil
        detached.status = NCGlobal.shared.metadataStatusNormal

        performRealmWrite(sync: true) { realm in
            realm.add(detached, update: .all)
        }
    }

    /// Asynchronously clears session-related metadata and resets the status to normal.
    /// - Parameter metadata: The `tableMetadata` object to clear and update.
    func clearMetadataSessionAsync(metadata: tableMetadata) async {
        // Clone and modify the object outside of Realm thread
        let detached = tableMetadata(value: metadata)

        detached.sceneIdentifier = nil
        detached.session = ""
        detached.sessionTaskIdentifier = 0
        detached.sessionError = ""
        detached.sessionSelector = ""
        detached.sessionDate = nil
        detached.status = NCGlobal.shared.metadataStatusNormal

        // Write the modified version to Realm
        await performRealmWriteAsync { realm in
            realm.add(detached, update: .all)
        }
    }

    @discardableResult
    func setMetadataStatus(ocId: String,
                           status: Int) -> tableMetadata? {
        var detached: tableMetadata?

        performRealmWrite(sync: true) { realm in
            guard let metadata = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else {
                return
            }
            metadata.status = status

            realm.add(metadata, update: .all)
            detached = tableMetadata(value: metadata)
        }

        return detached
    }

    /// Updates the metadata status for the given `ocId` in the Realm database.
    /// - Parameters:
    ///   - ocId: The unique identifier of the metadata.
    ///   - status: The new status value to set.
    func setMetadataStatusAsync(ocId: String, status: Int) async {
        await performRealmWriteAsync { realm in
            guard let metadata = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else {
                return
            }
            metadata.status = status
            realm.add(metadata, update: .all)
        }
    }

    /// Updates the `status` field for multiple `tableMetadata` objects with matching `ocId`s.
    func setMetadataStatusAsync(ocIds: [String], status: Int) async {
        await performRealmWriteAsync { realm in
            let metadatas = realm.objects(tableMetadata.self)
                .filter("ocId IN %@", ocIds)

            for metadata in metadatas {
                metadata.status = status
                realm.add(metadata, update: .all)
            }
        }
    }

    // MARK: - Realm Read

    func getMetadata(from url: URL?, sessionTaskIdentifier: Int) -> tableMetadata? {
        guard let url,
              var serverUrl = url.deletingLastPathComponent().absoluteString.removingPercentEncoding
        else {
            return nil
        }
        let fileName = url.lastPathComponent

        if serverUrl.hasSuffix("/") {
            serverUrl = String(serverUrl.dropLast())
        }
        return getMetadata(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@ AND sessionTaskIdentifier == %d",
                                                  serverUrl,
                                                  fileName,
                                                  sessionTaskIdentifier))
    }

    func getMetadataAsync(from url: URL?, sessionTaskIdentifier: Int) async -> tableMetadata? {
        guard let url,
              var serverUrl = url.deletingLastPathComponent().absoluteString.removingPercentEncoding
        else {
            return nil
        }
        let fileName = url.lastPathComponent

        if serverUrl.hasSuffix("/") {
            serverUrl = String(serverUrl.dropLast())
        }
        let predicate = NSPredicate(format: "serverUrl == %@ AND fileName == %@ AND sessionTaskIdentifier == %d",
                                    serverUrl,
                                    fileName,
                                    sessionTaskIdentifier)

        return await performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .first
                .map { tableMetadata(value: $0) }
        }
    }

#if !EXTENSION
    func updateBadge() async {
        let num = await performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(NSPredicate(format: "status != %i", NCGlobal.shared.metadataStatusNormal))
                .count
        } ?? 0
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = num
        }
    }
#endif

}
