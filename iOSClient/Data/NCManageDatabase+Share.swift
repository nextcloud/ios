//
//  NCManageDatabase+Share.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/01/23.
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

typealias tableShare = tableShareV2
class tableShareV2: Object {
    @objc dynamic var account = ""
    @objc dynamic var canEdit: Bool = false
    @objc dynamic var canDelete: Bool = false
    @objc dynamic var date: NSDate?
    @objc dynamic var displaynameFileOwner = ""
    @objc dynamic var displaynameOwner = ""
    @objc dynamic var expirationDate: NSDate?
    @objc dynamic var fileName = ""
    @objc dynamic var fileParent: Int = 0
    @objc dynamic var fileSource: Int = 0
    @objc dynamic var fileTarget = ""
    @objc dynamic var hideDownload: Bool = false
    @objc dynamic var idShare: Int = 0
    @objc dynamic var itemSource: Int = 0
    @objc dynamic var itemType = ""
    @objc dynamic var label = ""
    @objc dynamic var mailSend: Bool = false
    @objc dynamic var mimeType = ""
    @objc dynamic var note = ""
    @objc dynamic var parent: String = ""
    @objc dynamic var password: String = ""
    @objc dynamic var path = ""
    @objc dynamic var permissions: Int = 0
    @objc dynamic var primaryKey = ""
    @objc dynamic var sendPasswordByTalk: Bool = false
    @objc dynamic var serverUrl = ""

    ///
    /// See [OCS Share API documentation](https://docs.nextcloud.com/server/latest/developer_manual/client_apis/OCS/ocs-share-api.html) for semantic definitions of the different possible values.
    ///
    @objc dynamic var shareType: Int = 0
    @objc dynamic var shareWith = ""
    @objc dynamic var shareWithDisplayname = ""
    @objc dynamic var storage: Int = 0
    @objc dynamic var storageId = ""
    @objc dynamic var token = ""
    @objc dynamic var uidFileOwner = ""
    @objc dynamic var uidOwner = ""
    @objc dynamic var url = ""
    @objc dynamic var userClearAt: NSDate?
    @objc dynamic var userIcon = ""
    @objc dynamic var userMessage = ""
    @objc dynamic var userStatus = ""
    @objc dynamic var attributes: String?

    override static func primaryKey() -> String {
        return "primaryKey"
    }
}

extension NCManageDatabase {
    func addShare(account: String, home: String, shares: [NKShare]) {
        do {
            let realm = try Realm()
            try realm.write {
                for share in shares {
                    let serverUrlPath = home + share.path
                    guard let serverUrl = utilityFileSystem.deleteLastPath(serverUrlPath: serverUrlPath, home: home) else { continue }
                    let object = tableShare()
                    object.account = account
                    if let fileName = share.path.components(separatedBy: "/").last {
                        object.fileName = fileName
                    }
                    object.serverUrl = serverUrl
                    object.canEdit = share.canEdit
                    object.canDelete = share.canDelete
                    object.date = share.date as? NSDate
                    object.displaynameFileOwner = share.displaynameFileOwner
                    object.displaynameOwner = share.displaynameOwner
                    object.expirationDate = share.expirationDate
                    object.fileParent = share.fileParent
                    object.fileSource = share.fileSource
                    object.fileTarget = share.fileTarget
                    object.hideDownload = share.hideDownload
                    object.idShare = share.idShare
                    object.itemSource = share.itemSource
                    object.itemType = share.itemType
                    object.label = share.label
                    object.mailSend = share.mailSend
                    object.mimeType = share.mimeType
                    object.note = share.note
                    object.parent = share.parent
                    object.password = share.password
                    object.path = share.path
                    object.permissions = share.permissions
                    object.primaryKey = account + " " + String(share.idShare)
                    object.sendPasswordByTalk = share.sendPasswordByTalk
                    object.shareType = share.shareType
                    object.shareWith = share.shareWith
                    object.shareWithDisplayname = share.shareWithDisplayname
                    object.storage = share.storage
                    object.storageId = share.storageId
                    object.token = share.token
                    object.uidOwner = share.uidOwner
                    object.uidFileOwner = share.uidFileOwner
                    object.url = share.url
                    object.userClearAt = share.userClearAt as? NSDate
                    object.userIcon = share.userIcon
                    object.userMessage = share.userMessage
                    object.userStatus = share.userStatus
                    object.attributes = share.attributes
                    realm.add(object, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    ///
    /// Fetch all available shares of an item identified by the given metadata.
    ///
    /// - Returns: A tuple consisting of the first public share link and any _additional_ shares that might be there.
    ///            It is possible that there is no public share link but still shares of other types.
    ///            In the latter case, all shares are returned as the second tuple value.
    ///
    func getTableShares(account: String) -> [tableShare] {
        do {
            let realm = try Realm()
            let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
            let results = realm.objects(tableShare.self).filter("account == %@", account).sorted(by: sortProperties)
            return Array(results.map { tableShare.init(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }

    func getTableShares(metadata: tableMetadata) -> (firstShareLink: tableShare?, share: [tableShare]?) {
        do {
            let realm = try Realm()
            let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
            let firstShareLink = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@ AND shareType == 3", metadata.account, metadata.serverUrl, metadata.fileName).first
            if let firstShareLink = firstShareLink {
                let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@ AND idShare != %d", metadata.account, metadata.serverUrl, metadata.fileName, firstShareLink.idShare).sorted(by: sortProperties)
                return(firstShareLink: tableShare.init(value: firstShareLink), share: Array(results.map { tableShare.init(value: $0) }))
            } else {
                let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileName).sorted(by: sortProperties)
                return(firstShareLink: firstShareLink, share: Array(results.map { tableShare.init(value: $0) }))
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return (nil, nil)
    }

    func getTableShare(account: String, idShare: Int) -> tableShare? {
        do {
            let realm = try Realm()
            guard let result = realm.objects(tableShare.self).filter("account = %@ AND idShare = %d", account, idShare).first else { return nil }
            return tableShare.init(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getTableShares(account: String, serverUrl: String) -> [tableShare] {
        do {
            let realm = try Realm()
            let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
            let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).sorted(by: sortProperties)
            return Array(results.map { tableShare.init(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }

    ///
    /// Fetch all shares of a file regardless of type.
    ///
    func getTableShares(account: String, serverUrl: String, fileName: String) -> [tableShare] {
        do {
            let realm = try Realm()
            let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
            let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).sorted(by: sortProperties)
            return Array(results.map { tableShare.init(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }

        return []
    }

    func deleteTableShare(account: String, idShare: Int) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableShare.self).filter("account == %@ AND idShare == %d", account, idShare)
                realm.delete(result)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func deleteTableShare(account: String, path: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableShare.self).filter("account == %@ AND path == %@", account, path)
                realm.delete(result)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func deleteTableShare(account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableShare.self).filter("account == %@", account)
                realm.delete(result)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    // There is currently only one share attribute “download” from the scope “permissions”. This attribute is only valid for user and group shares, not for public link shares.
    func setAttibuteDownload(state: Bool) -> String? {
        if state {
            return nil
        } else {
            return "[{\"scope\":\"permissions\",\"key\":\"download\",\"enabled\":false}]"
        }
    }

    func isAttributeDownloadEnabled(attributes: String?) -> Bool {
        if let attributes = attributes, let data = attributes.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [Dictionary<String, Any>] {
                    for sub in json {
                        let key = sub["key"] as? String
                        let enabled = sub["enabled"] as? Bool
                        let scope = sub["scope"] as? String
                        if key == "download", scope == "permissions", let enabled = enabled {
                            return enabled
                        }
                    }
                }
            } catch let error as NSError { print(error) }
        }
        return true
    }
}
