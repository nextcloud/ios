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
    @discardableResult
    func setMetadataSessionAsync(ocId: String,
                                 newFileName: String? = nil,
                                 session: String? = nil,
                                 sessionTaskIdentifier: Int? = nil,
                                 sessionError: String? = nil,
                                 selector: String? = nil,
                                 status: Int? = nil,
                                 etag: String? = nil,
                                 errorCode: Int? = nil,
                                 progress: Double? = nil) async -> tableMetadata? {
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

            if let progress {
                metadata.progress = progress
            }
        }

        return await performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first?
                .detachedCopy()
        }
    }

    func setMetadataProgress(fileName: String,
                             serverUrl: String,
                             taskIdentifier: Int,
                             progress: Double) async {
        await performRealmWriteAsync { realm in
            guard let metadata = realm.objects(tableMetadata.self)
                .filter("fileName == %@ AND serverUrl == %@ and sessionTaskIdentifier == %d", fileName, serverUrl, taskIdentifier)
                .first else {
                return
            }

            if abs(metadata.progress - progress) > 0.001 {
                metadata.progress = progress
                print(progress)
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
            metadata.progress = 0
        }

        return await performRealmReadAsync { realm in
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
            metadata.sceneIdentifier = nil
            metadata.session = ""
            metadata.sessionTaskIdentifier = 0
            metadata.sessionError = ""
            metadata.sessionSelector = ""
            metadata.sessionDate = nil
            metadata.status = NCGlobal.shared.metadataStatusNormal
            metadata.progress = 0
            return metadata
        }

        // Write to Realm asynchronously
        await performRealmWriteAsync { realm in
            detachedMetadatas.forEach { metadata in
                realm.add(metadata, update: .all)
            }
        }
    }

    // MARK: - Realm Read

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
                .map { $0.detachedCopy() }
        }
    }

    func updateBadge() async {
        #if !EXTENSION
        let num = await performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(NSPredicate(format: "status != %i", NCGlobal.shared.metadataStatusNormal))
                .count
        } ?? 0
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(num) { error in
                if let error {
                    print("Failed to set badge count: \(error)")
                }
            }
        }
        #endif
    }
}
