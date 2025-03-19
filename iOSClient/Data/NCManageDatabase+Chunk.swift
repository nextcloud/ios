//
//  NCManageDatabase+Chunk.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/08/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

class tableChunk: Object {
    @Persisted var account = ""
    @Persisted var chunkFolder = ""
    @Persisted(primaryKey: true) var index = ""
    @Persisted var fileName: Int = 0
    @Persisted var ocId = ""
    @Persisted var size: Int64 = 0
}

extension NCManageDatabase {
    func getChunkFolder(account: String, ocId: String) -> String {
        do {
            let realm = try Realm()
            guard let result = realm.objects(tableChunk.self).filter("account == %@ AND ocId == %@", account, ocId).first else { return NSUUID().uuidString }
            return result.chunkFolder
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access to database: \(error)")
        }
        return NSUUID().uuidString
    }

    func getChunks(account: String, ocId: String) -> [(fileName: String, size: Int64)] {
        var filesChunk: [(fileName: String, size: Int64)] = []

        do {
            let realm = try Realm()
            let results = realm.objects(tableChunk.self).filter("account == %@ AND ocId == %@", account, ocId).sorted(byKeyPath: "fileName", ascending: true)
            for result in results {
                filesChunk.append((fileName: "\(result.fileName)", size: result.size))
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access to database: \(error)")
        }
        return filesChunk
    }

    func addChunks(account: String, ocId: String, chunkFolder: String, filesChunk: [(fileName: String, size: Int64)]) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableChunk.self).filter(NSPredicate(format: "account == %@ AND ocId == %@", account, ocId))
                realm.delete(results)
                for fileChunk in filesChunk {
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
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
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
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableChunk.self).filter(NSPredicate(format: "account == %@ AND ocId == %@", account, ocId))
                for result in results {
                    let filePath = directory + "/\(result.fileName)"
                    utilityFileSystem.removeFile(atPath: filePath)
                }
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }
}
