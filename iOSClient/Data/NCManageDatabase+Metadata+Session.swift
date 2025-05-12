// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

extension NCManageDatabase {

    // MARK: - Realm Write

    func setMetadataSession(ocId: String,
                            newFileName: String? = nil,
                            session: String? = nil,
                            sessionTaskIdentifier: Int? = nil,
                            sessionError: String? = nil,
                            selector: String? = nil,
                            status: Int? = nil,
                            etag: String? = nil,
                            errorCode: Int? = nil,
                            sync: Bool = true) {

        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                if let newFileName = newFileName {
                    result.fileName = newFileName
                    result.fileNameView = newFileName
                }
                if let session {
                    result.session = session
                }
                if let sessionTaskIdentifier {
                    result.sessionTaskIdentifier = sessionTaskIdentifier
                }
                if let sessionError {
                    result.sessionError = sessionError
                    if sessionError.isEmpty {
                        result.errorCode = 0
                    }
                }
                if let selector {
                    result.sessionSelector = selector
                }
                if let status {
                    result.status = status
                    if status == NCGlobal.shared.metadataStatusWaitDownload || status == NCGlobal.shared.metadataStatusWaitUpload {
                        result.sessionDate = Date()
                    } else if status == NCGlobal.shared.metadataStatusNormal {
                        result.sessionDate = nil
                    }
                }
                if let etag {
                    result.etag = etag
                }
                if let errorCode {
                    result.errorCode = errorCode
                }
            }
        }
    }

    @discardableResult
    func setMetadatasSessionInWaitDownload(metadatas: [tableMetadata],
                                           session: String,
                                           selector: String,
                                           sceneIdentifier: String? = nil,
                                           sync: Bool = true) -> tableMetadata? {
        guard !metadatas.isEmpty
        else {
            return nil
        }
        var lastUpdated: tableMetadata?

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

                lastUpdated = tableMetadata(value: object)
            }
        }

        return lastUpdated
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
