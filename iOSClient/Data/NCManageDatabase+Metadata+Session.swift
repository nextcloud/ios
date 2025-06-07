// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

extension NCManageDatabase {

    // MARK: - Realm Write

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

    func setMetadatasSessionInWaitDownload(metadatas: [tableMetadata],
                                           session: String,
                                           selector: String,
                                           sceneIdentifier: String? = nil) {
        guard !metadatas.isEmpty else { return }
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

    func clearMetadataSession(metadatas: [tableMetadata]) {
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
        await performRealmWrite { realm in
            guard let metadata = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else {
                return
            }
            metadata.status = status
            realm.add(metadata, update: .all)
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
}
