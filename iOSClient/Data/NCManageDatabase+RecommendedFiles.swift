// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import RealmSwift
import NextcloudKit

class tableRecommendedFiles: Object {
    @Persisted var account = ""
    @Persisted var id = ""
    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted var timestamp: Date?
    @Persisted var name: String = ""
    @Persisted var directory: String = ""
    @Persisted var extensionType: String = ""
    @Persisted var mimeType: String = ""
    @Persisted var hasPreview: Bool = false
    @Persisted var reason: String = ""

    convenience init(account: String, id: String, timestamp: Date?, name: String, directory: String, extensionType: String, mimeType: String, hasPreview: Bool, reason: String) {
        self.init()

        self.account = account
        self.id = id
        self.primaryKey = account + id
        self.timestamp = timestamp
        self.name = name
        self.directory = directory
        self.extensionType = extensionType
        self.mimeType = mimeType
        self.hasPreview = hasPreview
        self.reason = reason
     }
}

extension NCManageDatabase {

    // MARK: - Realm write

    /// Asynchronously deletes existing recommended files for the given account and writes new ones into the Realm database.
    /// - Parameters:
    ///   - account: The account identifier to filter existing objects.
    ///   - recommendations: The array of new recommended files to insert.
    /// - Returns: Void. Executed inside a Realm write transaction on a background serial queue.
    func createRecommendedFilesAsync(account: String, recommendations: [NKRecommendation]) async {
        await performRealmWriteAsync { realm in
            // Remove all existing recommended files for the given account
            let results = realm.objects(tableRecommendedFiles.self)
                .filter("account == %@", account)
            realm.delete(results)

            // Insert new recommended files
            for recommendation in recommendations {
                let recommendedFile = tableRecommendedFiles(account: account,
                                                            id: recommendation.id,
                                                            timestamp: recommendation.timestamp,
                                                            name: recommendation.name,
                                                            directory: recommendation.directory,
                                                            extensionType: recommendation.extensionType,
                                                            mimeType: recommendation.mimeType,
                                                            hasPreview: recommendation.hasPreview,
                                                            reason: recommendation.reason
                )
                realm.add(recommendedFile)
            }
        }
    }

    /// Asynchronously deletes all `tableRecommendedFiles` entries for a given account from the Realm database.
    /// - Parameters:
    ///   - account: The account identifier whose recommended files should be deleted.
    ///   - async: Whether the Realm write should be executed asynchronously (default is true).
    func deleteAllRecommendedFilesAsync(account: String) async {
        await performRealmWriteAsync { realm in
            let results = realm.objects(tableRecommendedFiles.self)
                .filter("account == %@", account)
            realm.delete(results)
        }
    }

    // MARK: - Realm read

    func getRecommendedFiles(account: String) -> [tableRecommendedFiles] {
        performRealmRead { realm in
            let results = realm.objects(tableRecommendedFiles.self)
                .filter("account == %@", account)
                .sorted(byKeyPath: "timestamp", ascending: false)

            return results.compactMap { result in
                let metadata = realm.objects(tableMetadata.self)
                    .filter("fileId == %@", result.id)
                    .first

                guard let metadata, metadata.status != NCGlobal.shared.metadataStatusWaitDelete else {
                    return nil
                }

                return tableRecommendedFiles(value: result)
            }
        } ?? []
    }
}
