//
//  NCManageDatabase+Metadata+Session.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/02/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

extension NCManageDatabase {
    func setMetadataSession(ocId: String,
                            newFileName: String? = nil,
                            session: String? = nil,
                            sessionTaskIdentifier: Int? = nil,
                            sessionError: String? = nil,
                            selector: String? = nil,
                            status: Int? = nil,
                            etag: String? = nil,
                            errorCode: Int? = nil) {

        do {
            let realm = try Realm()
            try realm.write {
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
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    @discardableResult
    func setMetadatasSessionInWaitDownload(metadatas: [tableMetadata], session: String, selector: String, sceneIdentifier: String? = nil) -> tableMetadata? {
        if metadatas.isEmpty { return nil }
        var metadataUpdated: tableMetadata?

        do {
            let realm = try Realm()
            try realm.write {
                for metadata in metadatas {
                    if let result = realm.objects(tableMetadata.self).filter("ocId == %@", metadata.ocId).first {
                        result.sceneIdentifier = sceneIdentifier
                        result.session = session
                        result.sessionTaskIdentifier = 0
                        result.sessionError = ""
                        result.sessionSelector = selector
                        result.status = NCGlobal.shared.metadataStatusWaitDownload
                        result.sessionDate = Date()
                        metadataUpdated = tableMetadata(value: result)
                    } else {
                        metadata.sceneIdentifier = sceneIdentifier
                        metadata.session = session
                        metadata.sessionTaskIdentifier = 0
                        metadata.sessionError = ""
                        metadata.sessionSelector = selector
                        metadata.status = NCGlobal.shared.metadataStatusWaitDownload
                        metadata.sessionDate = Date()
                        realm.add(metadata, update: .all)
                        metadataUpdated = tableMetadata(value: metadata)
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }

        return metadataUpdated
    }

    func clearMetadataSession(metadatas: [tableMetadata]) {
        do {
            let realm = try Realm()
            try realm.write {
                for metadata in metadatas {
                    if let result = realm.objects(tableMetadata.self).filter("ocId == %@", metadata.ocId).first {
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
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func clearMetadataSession(metadata: tableMetadata) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableMetadata.self).filter("ocId == %@", metadata.ocId).first {
                    result.sceneIdentifier = nil
                    result.session = ""
                    result.sessionTaskIdentifier = 0
                    result.sessionError = ""
                    result.sessionSelector = ""
                    result.sessionDate = nil
                    result.status = NCGlobal.shared.metadataStatusNormal
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    @discardableResult
    func setMetadataStatus(ocId: String, status: Int) -> tableMetadata? {
        var result: tableMetadata?

        do {
            let realm = try Realm()
            try realm.write {
                result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.status = status

                if status == NCGlobal.shared.metadataStatusNormal {
                    result?.sessionDate = nil
                } else {
                    result?.sessionDate = Date()
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
        if let result {
            return tableMetadata.init(value: result)
        } else {
            return nil
        }
    }

    func getMetadata(from url: URL?, sessionTaskIdentifier: Int) -> tableMetadata? {
        guard let url,
              var serverUrl = url.deletingLastPathComponent().absoluteString.removingPercentEncoding
        else { return nil }
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
