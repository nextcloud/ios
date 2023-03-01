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

    override static func primaryKey() -> String {
        return "primaryKey"
    }
}

extension NCManageDatabase {

    func addShare(account: String, home: String, shares: [NKShare]) {

        let realm = try! Realm()

        do {
            try realm.write {

                for share in shares {

                    let serverUrlPath = home + share.path
                    guard let serverUrl = NCUtilityFileSystem.shared.deleteLastPath(serverUrlPath: serverUrlPath, home: home) else {
                        continue
                    }

                    let object = tableShare()

                    object.account = account
                    if let fileName = share.path.components(separatedBy: "/").last {
                        object.fileName = fileName
                    }
                    object.serverUrl = serverUrl

                    object.canEdit = share.canEdit
                    object.canDelete = share.canDelete
                    object.date = share.date
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
                    object.userClearAt = share.userClearAt
                    object.userIcon = share.userIcon
                    object.userMessage = share.userMessage
                    object.userStatus = share.userStatus

                    realm.add(object, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getTableShares(account: String) -> [tableShare] {

        let realm = try! Realm()

        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@", account).sorted(by: sortProperties)

        return Array(results.map { tableShare.init(value: $0) })
    }

    func getTableShares(metadata: tableMetadata) -> (firstShareLink: tableShare?, share: [tableShare]?) {

        let realm = try! Realm()

        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let firstShareLink = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@ AND shareType == 3", metadata.account, metadata.serverUrl, metadata.fileName).first

        if let firstShareLink = firstShareLink {
            let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@ AND idShare != %d", metadata.account, metadata.serverUrl, metadata.fileName, firstShareLink.idShare).sorted(by: sortProperties)
            return(firstShareLink: tableShare.init(value: firstShareLink), share: Array(results.map { tableShare.init(value: $0) }))
        } else {
            let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileName).sorted(by: sortProperties)
            return(firstShareLink: firstShareLink, share: Array(results.map { tableShare.init(value: $0) }))
        }
    }

    func getTableShare(account: String, idShare: Int) -> tableShare? {

        let realm = try! Realm()

        guard let result = realm.objects(tableShare.self).filter("account = %@ AND idShare = %d", account, idShare).first else {
            return nil
        }

        return tableShare.init(value: result)
    }

    func getTableShares(account: String, serverUrl: String) -> [tableShare] {

        let realm = try! Realm()

        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).sorted(by: sortProperties)

        return Array(results.map { tableShare.init(value: $0) })
    }

    func getTableShares(account: String, serverUrl: String, fileName: String) -> [tableShare] {

        let realm = try! Realm()

        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).sorted(by: sortProperties)

        return Array(results.map { tableShare.init(value: $0) })
    }

    func deleteTableShare(account: String, idShare: Int) {

        let realm = try! Realm()

        realm.beginWrite()

        let result = realm.objects(tableShare.self).filter("account == %@ AND idShare == %d", account, idShare)
        realm.delete(result)

        do {
            try realm.commitWrite()
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func deleteTableShare(account: String) {

        let realm = try! Realm()

        realm.beginWrite()

        let result = realm.objects(tableShare.self).filter("account == %@", account)
        realm.delete(result)

        do {
            try realm.commitWrite()
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
}
