//
//  NCManageDatabase+Directory.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/11/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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

class tableDirectory: Object {
    @objc dynamic var account = ""
    @objc dynamic var colorFolder: String?
    @objc dynamic var e2eEncrypted: Bool = false
    @objc dynamic var etag = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var ocId = ""
    @objc dynamic var offline: Bool = false
    @objc dynamic var offlineDate: Date?
    @objc dynamic var permissions = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var serverUrl = ""

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension NCManageDatabase {
    func addDirectory(e2eEncrypted: Bool, favorite: Bool, ocId: String, fileId: String, etag: String? = nil, permissions: String? = nil, richWorkspace: String? = nil, serverUrl: String, account: String) {
        do {
            let realm = try Realm()
            let result = realm.objects(tableDirectory.self).filter("account == %@ AND ocId == %@", account, ocId).first
            try realm.write {
                if let result {
                    result.e2eEncrypted = e2eEncrypted
                    result.favorite = favorite
                    if let etag { result.etag = etag }
                    if let permissions { result.permissions = permissions }
                    if let richWorkspace { result.richWorkspace = richWorkspace }
                } else {
                    let directory = tableDirectory()
                    directory.e2eEncrypted = e2eEncrypted
                    directory.favorite = favorite
                    directory.ocId = ocId
                    directory.fileId = fileId
                    if let etag { directory.etag = etag }
                    if let permissions { directory.permissions = permissions }
                    if let richWorkspace { directory.richWorkspace = richWorkspace }
                    directory.serverUrl = serverUrl
                    directory.account = account
                    realm.add(directory, update: .modified)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func addDirectories(metadatas: [tableMetadata]) {
        do {
            let realm = try Realm()
            for metadata in metadatas {
                let result = realm.objects(tableDirectory.self).filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId).first
                try realm.write {
                    if let result {
                        result.e2eEncrypted = metadata.e2eEncrypted
                        result.favorite = metadata.favorite
                        result.etag = metadata.etag
                        result.permissions = metadata.permissions
                        result.richWorkspace = metadata.richWorkspace
                    } else {
                        let directory = tableDirectory()
                        directory.account = metadata.account
                        directory.e2eEncrypted = metadata.e2eEncrypted
                        directory.etag = metadata.etag
                        directory.favorite = metadata.favorite
                        directory.fileId = metadata.fileId
                        directory.ocId = metadata.ocId
                        directory.permissions = metadata.permissions
                        directory.richWorkspace = metadata.richWorkspace
                        directory.serverUrl = metadata.serveUrlFileName
                        realm.add(directory, update: .modified)
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func deleteDirectoryAndSubDirectory(serverUrl: String, account: String) {
#if !EXTENSION
        DispatchQueue.main.async {
            let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for windowScene in windowScenes {
                if let controller = windowScene.keyWindow?.rootViewController as? NCMainTabBarController {
                    controller.navigationCollectionViewCommon.remove(where: { $0.serverUrl == serverUrl})
                }
            }
        }
#endif

        do {
            let realm = try Realm()
            let results = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl BEGINSWITH %@", account, serverUrl)
            try realm.write {
                for result in results {
                    let metadatas = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@", account, result.serverUrl)
                    for metadata in metadatas {
                        let localFile = realm.objects(tableLocalFile.self).filter("ocId == %@", metadata.ocId)
                        realm.delete(localFile)
                    }
                    realm.delete(metadatas)
                }
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setDirectory(serverUrl: String, serverUrlTo: String? = nil, etag: String? = nil, ocId: String? = nil, fileId: String? = nil, encrypted: Bool, richWorkspace: String? = nil, account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                guard let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else { return }
                let directory = tableDirectory.init(value: result)
                realm.delete(result)
                directory.e2eEncrypted = encrypted
                if let etag = etag {
                    directory.etag = etag
                }
                if let ocId = ocId {
                    directory.ocId = ocId
                }
                if let fileId = fileId {
                    directory.fileId = fileId
                }
                if let serverUrlTo = serverUrlTo {
                    directory.serverUrl = serverUrlTo
                }
                if let richWorkspace = richWorkspace {
                    directory.richWorkspace = richWorkspace
                }
                realm.add(directory, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getTableDirectory(predicate: NSPredicate) -> tableDirectory? {
        do {
            let realm = try Realm()
            guard let result = realm.objects(tableDirectory.self).filter(predicate).first
            else {
                return nil
            }
            return tableDirectory.init(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getTableDirectory(account: String, serverUrl: String) -> tableDirectory? {
        do {
            let realm = try Realm()
            return realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getTableDirectory(ocId: String) -> tableDirectory? {
        do {
            let realm = try Realm()
            if let result = realm.objects(tableDirectory.self).filter("ocId == %@", ocId).first {
                return tableDirectory(value: result)
            } else {
                return nil
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getTablesDirectory(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableDirectory]? {
        do {
            let realm = try Realm()
            let results = realm.objects(tableDirectory.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
            if results.isEmpty {
                return nil
            } else {
                return Array(results.map { tableDirectory.init(value: $0) })
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func renameDirectory(ocId: String, serverUrl: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableDirectory.self).filter("ocId == %@", ocId).first
                result?.serverUrl = serverUrl
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setDirectory(serverUrl: String, offline: Bool, metadata: tableMetadata) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", metadata.account, serverUrl).first {
                    result.offline = offline
                } else {
                    let directory = tableDirectory()

                    directory.account = metadata.account
                    directory.serverUrl = serverUrl
                    directory.offline = offline
                    directory.e2eEncrypted = metadata.e2eEncrypted
                    directory.favorite = metadata.favorite
                    directory.fileId = metadata.fileId
                    directory.ocId = metadata.ocId
                    directory.permissions = metadata.permissions
                    directory.richWorkspace = metadata.richWorkspace

                    realm.add(directory, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setDirectorySynchronizationDate(serverUrl: String, account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first
                result?.offlineDate = Date()
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func updateDirectoryRichWorkspace(_ richWorkspace: String?, account: String, serverUrl: String) {
        var result: tableDirectory?

        do {
            let realm = try Realm()
            try realm.write {
                result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first
                result?.richWorkspace = richWorkspace
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func updateDirectoryColorFolder(_ colorFolder: String?, metadata: tableMetadata, serverUrl: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", metadata.account, serverUrl).first {
                    result.colorFolder = colorFolder
                } else {
                    let directory = tableDirectory()

                    directory.account = metadata.account
                    directory.serverUrl = serverUrl
                    directory.colorFolder = colorFolder
                    directory.e2eEncrypted = metadata.e2eEncrypted
                    directory.favorite = metadata.favorite
                    directory.fileId = metadata.fileId
                    directory.ocId = metadata.ocId
                    directory.permissions = metadata.permissions
                    directory.richWorkspace = metadata.richWorkspace

                    realm.add(directory, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }
}
