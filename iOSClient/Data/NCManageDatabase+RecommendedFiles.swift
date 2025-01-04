// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
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
    func addRecommendedFiles(account: String, recommendations: [NKRecommendation]) {
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

    func getResultsRecommendedFiles(account: String) -> [tableRecommendedFiles] {
        do {
            let realm = try Realm()
            let results = realm.objects(tableRecommendedFiles.self).filter("account == %@", account)

            return Array(results)
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }

        return []
    }

    func getNKRecommendation(account: String) -> [NKRecommendation] {
        var recommendations: [NKRecommendation] = []

        do {
            let realm = try Realm()
            let results = realm.objects(tableRecommendedFiles.self).filter("account == %@", account)

            for result in results {
                let recommendation = NKRecommendation(id: result.id, timestamp: result.timestamp, name: result.name, directory: result.directory, extensionType: result.extensionType, mimeType: result.mimeType, hasPreview: result.hasPreview, reason: result.reason)
                recommendations.append(recommendation)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }

        return recommendations
    }

    func deleteRecommendedFiles(account: String, recommendations: [NKRecommendation]) {
        do {
            let realm = try Realm()

            try realm.write {
                for recommendation in recommendations {
                    let primaryKey = account + recommendation.id
                    let results = realm.objects(tableRecommendedFiles.self).filter("primaryKey == %@", primaryKey)

                    realm.delete(results)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func compareRecommendations(account: String, newObjects: [NKRecommendation]) -> (changed: [NKRecommendation], added: [NKRecommendation], deleted: [NKRecommendation]) {
        var changed = [NKRecommendation]()
        var added = [NKRecommendation]()
        var deleted = [NKRecommendation]()

        let existingObjects = getNKRecommendation(account: account)

        let existingDictionary = Dictionary(uniqueKeysWithValues: existingObjects.map { (account + $0.id, $0) })
        let newDictionary = Dictionary(uniqueKeysWithValues: newObjects.map { (account + $0.id, $0) })

        // Verify objects changed or deleted
        for (primaryKey, existingObject) in existingDictionary {
            if let newObject = newDictionary[primaryKey] {
                // If exists, verify if is changed
                if !existingObject.isEqual(newObject) {
                    changed.append(newObject)
                }
            } else {
                // if do not exists, it's deleted
                deleted.append(existingObject)
            }
        }

        // verify new objects
        for (primaryKey, newObject) in newDictionary {
            if existingDictionary[primaryKey] == nil {
                added.append(newObject)
            }
        }

        return (changed, added, deleted)
    }
}
