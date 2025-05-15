// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableTip: Object {
    @Persisted(primaryKey: true) var tipName = ""
}

extension NCManageDatabase {

    // MARK: - Realm write

    func addTip(_ tipName: String) {
        performRealmWrite { realm in
            let addObject = tableTip()
            addObject.tipName = tipName
            realm.add(addObject, update: .all)
        }
    }

    // MARK: - Realm read

    func tipExists(_ tipName: String) -> Bool {
        performRealmRead { realm in
            realm.objects(tableTip.self)
                .where { $0.tipName == tipName }
                .first != nil
        } ?? false
    }
}
