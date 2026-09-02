// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableAvatar: Object {
    @objc dynamic var date = NSDate()
    @objc dynamic var etag = ""
    @objc dynamic var fileName = ""

    override static func primaryKey() -> String {
        return "fileName"
    }
}

extension NCManageDatabase {
    func addAvatarAsync(fileName: String, etag: String) async {
        await core.performRealmWriteAsync { realm in
            let addObject = tableAvatar()
            addObject.date = NSDate()
            addObject.etag = etag
            addObject.fileName = fileName
            realm.add(addObject, update: .all)
        }
    }

    // MARK: - Realm read

    func getTableAvatarAsync(fileName: String) async -> tableAvatar? {
        return await core.performRealmReadAsync { realm in
            realm.objects(tableAvatar.self)
                .filter("fileName == %@", fileName)
                .first
                .map { tableAvatar(value: $0) }
        }
    }
}
