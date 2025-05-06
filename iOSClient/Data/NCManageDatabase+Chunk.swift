// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableChunk: Object {
    @Persisted var account = ""
    @Persisted var chunkFolder = ""
    @Persisted(primaryKey: true) var index = ""
    @Persisted var fileName: Int = 0
    @Persisted var ocId = ""
    @Persisted var size: Int64 = 0
}

extension NCManageDatabase {

    // MARK: - Realm write

    func addChunks(account: String, ocId: String, chunkFolder: String, filesChunk: [(fileName: String, size: Int64)]) {
        performRealmWrite { realm in
            let results = realm.objects(tableChunk.self)
                .filter("account == %@ AND ocId == %@", account, ocId)
            realm.delete(results)

            filesChunk.forEach { fileChunk in
                let object = tableChunk()
                object.account = account
                object.chunkFolder = chunkFolder
                object.fileName = Int(fileChunk.fileName) ?? 0
                object.index = ocId + fileChunk.fileName
                object.ocId = ocId
                object.size = fileChunk.size
                realm.add(object, update: .all)
            }
        }
    }

    func deleteChunk(account: String, ocId: String, fileChunk: (fileName: String, size: Int64), directory: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableChunk.self).filter(NSPredicate(format: "account == %@ AND ocId == %@ AND fileName == %d", account, ocId, Int(fileChunk.fileName) ?? 0))
                realm.delete(result)
                let filePath = directory + "/\(fileChunk.fileName)"
                utilityFileSystem.removeFile(atPath: filePath)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func deleteChunks(account: String, ocId: String, directory: String) {
        performRealmWrite { realm in
            let results = realm.objects(tableChunk.self).filter(NSPredicate(format: "account == %@ AND ocId == %@", account, ocId))

            results.forEach { result in
                let filePath = directory + "/\(result.fileName)"
                self.utilityFileSystem.removeFile(atPath: filePath)
            }

            realm.delete(results)
        }
    }

    // MARK: - Realm read

    func getChunkFolder(account: String, ocId: String) -> String {
        performRealmRead { realm in
            realm.objects(tableChunk.self)
                .filter("account == %@ AND ocId == %@", account, ocId)
                .first?.chunkFolder
        } ?? UUID().uuidString
    }

    func getChunks(account: String, ocId: String) -> [(fileName: String, size: Int64)] {
        performRealmRead { realm in
            realm.objects(tableChunk.self)
                .filter("account == %@ AND ocId == %@", account, ocId)
                .sorted(byKeyPath: "fileName", ascending: true)
                .map { (fileName: "\($0.fileName)", size: $0.size) }
        } ?? []
    }
}
