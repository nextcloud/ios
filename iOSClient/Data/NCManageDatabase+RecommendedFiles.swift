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
    func createRecommendedFiles(account: String, recommendations: [NKRecommendation]) {
        do {
            let realm = try Realm()

            try realm.write {
                // Removed all objct for account
                let results = realm.objects(tableRecommendedFiles.self).filter("account == %@", account)

                realm.delete(results)

                // Added the new recommendations
                for recommendation in recommendations {
                    let recommendedFile = tableRecommendedFiles(account: account, id: recommendation.id, timestamp: recommendation.timestamp, name: recommendation.name, directory: recommendation.directory, extensionType: recommendation.extensionType, mimeType: recommendation.mimeType, hasPreview: recommendation.hasPreview, reason: recommendation.reason)
                    realm.add(recommendedFile)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getRecommendedFiles(account: String) -> [tableRecommendedFiles] {
        do {
            let realm = try Realm()
            let results = realm.objects(tableRecommendedFiles.self).filter("account == %@", account).sorted(byKeyPath: "timestamp", ascending: false)

            return Array(results.map { tableRecommendedFiles.init(value: $0) })
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }

        return []
    }

    func deleteAllRecommendedFiles(account: String) {
        do {
            let realm = try Realm()

            try realm.write {
                realm.delete(realm.objects(tableRecommendedFiles.self).filter("account == %@", account))
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
    }
}
