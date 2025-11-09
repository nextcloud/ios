// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import RealmSwift

extension NCManageDatabase {
    func addLocalFilesAsync(metadatas: [tableMetadata], offline: Bool? = nil) async {
        guard !metadatas.isEmpty else {
            return
        }

        // Extract ocIds for efficient lookup
        let ocIds = metadatas.compactMap { $0.ocId }
        guard !ocIds.isEmpty else {
            return
        }

        // Preload existing entries to avoid creating duplicates
        let existingMap: [String: tableLocalFile] = await core.performRealmReadAsync { realm in
                let existing = realm.objects(tableLocalFile.self)
                    .filter(NSPredicate(format: "ocId IN %@", ocIds))
                return Dictionary(uniqueKeysWithValues:
                    existing.map { ($0.ocId, tableLocalFile(value: $0)) } // detached copy via value init
                )
            } ?? [:]

        await core.performRealmWriteAsync { realm in
            for metadata in metadatas {
                // Reuse existing object or create a new one
                let local = existingMap[metadata.ocId] ?? tableLocalFile()

                local.account = metadata.account
                local.etag = metadata.etag
                local.exifDate = NSDate()
                local.exifLatitude = "-1"
                local.exifLongitude = "-1"
                local.ocId = metadata.ocId
                local.fileName = metadata.fileName

                if let offline {
                    local.offline = offline
                }

                realm.add(local, update: .all)
            }
        }
    }

    func deleteLocalFileAsync(id: String?) async {
        guard let id else { return }

        await core.performRealmWriteAsync { realm in
            let results = realm.objects(tableLocalFile.self)
                .filter("ocId == %@", id)
            realm.delete(results)
        }
    }

    func getTableLocalFileAsync(predicate: NSPredicate) async -> tableLocalFile? {
        await core.performRealmReadAsync { realm in
            realm.objects(tableLocalFile.self)
                .filter(predicate)
                .first
                .map { tableLocalFile(value: $0) }
        }
    }
}
