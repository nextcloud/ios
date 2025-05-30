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
        var updatedMetadata: tableMetadata?

        performRealmWrite(sync: sync) { realm in
            guard let metadata = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first else {
                return
            }

            if let name = newFileName {
                metadata.fileName = name
                metadata.fileNameView = name
            }

            if let session { metadata.session = session }
            if let sessionTaskIdentifier { metadata.sessionTaskIdentifier = sessionTaskIdentifier }
            if let sessionError {
                metadata.sessionError = sessionError
                if sessionError.isEmpty {
                    metadata.errorCode = 0
                }
            }
            if let selector { metadata.sessionSelector = selector }

            if let status {
                metadata.status = status
                switch status {
                case NCGlobal.shared.metadataStatusWaitDownload,
                     NCGlobal.shared.metadataStatusWaitUpload:
                    metadata.sessionDate = Date()
                case NCGlobal.shared.metadataStatusNormal:
                    metadata.sessionDate = nil
                default:
                    break
                }
            }

            if let etag { metadata.etag = etag }
            if let errorCode { metadata.errorCode = errorCode }

            updatedMetadata = tableMetadata(value: metadata)
        }

        return updatedMetadata
    }

    func setMetadatasSessionInWaitDownload(metadatas: [tableMetadata],
                                           session: String,
                                           selector: String,
                                           sceneIdentifier: String? = nil,
                                           sync: Bool = true) {
        guard !metadatas.isEmpty else {
            return
        }

        performRealmWrite(sync: sync) { realm in
            for metadata in metadatas {
                let object = realm.objects(tableMetadata.self)
                    .filter("ocId == %@", metadata.ocId)
                    .first ?? metadata

                object.sceneIdentifier = sceneIdentifier
                object.session = session
                object.sessionTaskIdentifier = 0
                object.sessionError = ""
                object.sessionSelector = selector
                object.status = NCGlobal.shared.metadataStatusWaitDownload
                object.sessionDate = Date()

                if object === metadata {
                    realm.add(object, update: .all)
                }
            }
        }
    }

    func setMetadataSessionInWaitDownload(metadata: tableMetadata,
                                          session: String,
                                          selector: String,
                                          sceneIdentifier: String? = nil,
                                          sync: Bool = true) -> tableMetadata? {
        var updatedMetadata: tableMetadata?

        performRealmWrite(sync: sync) { realm in
            let object = realm.objects(tableMetadata.self)
                .filter("ocId == %@", metadata.ocId)
                .first ?? metadata

            object.sceneIdentifier = sceneIdentifier
            object.session = session
            object.sessionTaskIdentifier = 0
            object.sessionError = ""
            object.sessionSelector = selector
            object.status = NCGlobal.shared.metadataStatusWaitDownload
            object.sessionDate = Date()

            if object === metadata {
                realm.add(object, update: .all)
            }

            updatedMetadata = tableMetadata(value: object)
        }

        return updatedMetadata
    }


    func clearMetadataSession(metadatas: [tableMetadata], sync: Bool = true) {
        guard !metadatas.isEmpty
        else {
            return
        }
        let ocIds = Set(metadatas.map(\.ocId))

        performRealmWrite(sync: sync) { realm in
            let results = realm.objects(tableMetadata.self)
                .filter("ocId IN %@", ocIds)

            results.forEach { result in
                result.sceneIdentifier = nil
                result.session = ""
                result.sessionTaskIdentifier = 0
                result.sessionError = ""
                result.sessionSelector = ""
                result.sessionDate = nil
                result.status = NCGlobal.shared.metadataStatusNormal
            }
        }
    }

    func clearMetadataSession(metadata: tableMetadata, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            guard let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", metadata.ocId)
                .first
            else {
                return
            }

            result.sceneIdentifier = nil
            result.session = ""
            result.sessionTaskIdentifier = 0
            result.sessionError = ""
            result.sessionSelector = ""
            result.sessionDate = nil
            result.status = NCGlobal.shared.metadataStatusNormal
        }
    }

    @discardableResult
    func setMetadataStatus(ocId: String, status: Int, sync: Bool = true) -> tableMetadata? {
        var updated: tableMetadata?

        performRealmWrite(sync: sync) { realm in
            guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
            else {
                return
            }

            result.status = status
            result.sessionDate = (status == NCGlobal.shared.metadataStatusNormal) ? nil : Date()
            updated = tableMetadata(value: result)
        }

        return updated
    }

    func setMetadataStatus(ocId: String, status: Int) async -> tableMetadata? {
        var updated: tableMetadata?

        await performRealmWrite { realm in
            guard let result = realm.object(ofType: tableMetadata.self, forPrimaryKey: ocId) else {
                return
            }

            result.status = status
            result.sessionDate = (status == NCGlobal.shared.metadataStatusNormal) ? nil : Date()
            updated = tableMetadata(value: result)
        }

        return updated
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
