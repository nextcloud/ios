// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableRecommendedFiles: Object {
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? tableRecommendedFiles,
           self.timestamp == object.timestamp,
           self.name == object.name,
           self.directory == object.directory,
           self.extensionType == object.extensionType,
           self.mimeType == object.mimeType,
           self.hasPreview == object.hasPreview,
           self.reason == object.reason {
            return true
        } else {
            return false
        }
    }

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
    func addRecommendedFiles(account: String, recommendation: [NKRecommendation]) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableRecommendedFiles.self).filter("account == %@", account)
                realm.delete(results)
                for recommendation in recommendation {
                    let recommendedFile = tableRecommendedFiles(account: account, id: recommendation.id, timestamp: recommendation.timestamp, name: recommendation.name, directory: recommendation.directory, extensionType: recommendation.extensionType, mimeType: recommendation.mimeType, hasPreview: recommendation.hasPreview, reason: recommendation.reason)
                    realm.add(recommendedFile)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getResultsRecommendedFiles(account: String) -> Results<tableRecommendedFiles>? {
        do {
            let realm = try Realm()
            let results = realm.objects(tableRecommendedFiles.self).filter("account == %@", account)
            return results
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }

        return nil
    }
}
