// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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

    // MARK: - Realm write

    func addGroupfolders(account: String, groupfolders: [NKGroupfolders]) {
        performRealmWrite { realm in
            let tableGroupfolders = realm.objects(TableGroupfolders.self).filter("account == %@", account)
            realm.delete(tableGroupfolders)

            let tableGroupfoldersGroups = realm.objects(TableGroupfoldersGroups.self).filter("account == %@", account)
            realm.delete(tableGroupfoldersGroups)

            for groupfolder in groupfolders {
                let obj = TableGroupfolders()
                obj.account = account
                obj.acl = groupfolder.acl

                groupfolder.groups?.forEach { group in
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
    }
}
