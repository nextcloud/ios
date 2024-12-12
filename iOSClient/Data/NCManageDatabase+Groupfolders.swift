//
//  NCManageDatabase+LayoutForView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/11/22.
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

class TableGroupfolders: Object {
    @Persisted var account = ""
    @Persisted var acl: Bool = false
    @Persisted var groups: List<TableGroupfoldersGroups>
    @Persisted var id: Int = 0
    @Persisted var manage: Data?
    @Persisted var mountPoint = ""
    @Persisted var quota: Int = 0
    @Persisted var size: Int = 0
}

class TableGroupfoldersGroups: Object {
    @Persisted var account = ""
    @Persisted var group = ""
    @Persisted var permission: Int = 0

    convenience init(account: String, group: String, permission: Int) {
        self.init()

        self.account = account
        self.group = group
        self.permission = permission
    }
}

extension NCManageDatabase {
    func addGroupfolders(account: String, groupfolders: [NKGroupfolders]) {
        do {
            let realm = try Realm()
            try realm.write {

                let tableGroupfolders = realm.objects(TableGroupfolders.self).filter("account == %@", account)
                realm.delete(tableGroupfolders)

                let tableGroupfoldersGroups = realm.objects(TableGroupfoldersGroups.self).filter("account == %@", account)
                realm.delete(tableGroupfoldersGroups)

                for groupfolder in groupfolders {
                    let obj = TableGroupfolders()
                    obj.account = account
                    obj.acl = groupfolder.acl
                    for group in groupfolder.groups ?? [:] {
                        let objGroups = TableGroupfoldersGroups(account: account, group: group.key, permission: (group.value as? Int ?? 0))
                        obj.groups.append(objGroups)
                    }
                    obj.id = groupfolder.id
                    obj.manage = groupfolder.manage
                    obj.mountPoint = groupfolder.mountPoint
                    obj.quota = groupfolder.quota
                    obj.size = groupfolder.size
                    realm.add(obj)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }
}
