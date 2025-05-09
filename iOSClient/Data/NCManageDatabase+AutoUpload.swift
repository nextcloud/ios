// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableAutoUpload: Object {
    @Persisted(primaryKey: true) var primaryKey: String
    @Persisted var account = ""
    @Persisted var serverUrl = ""
    @Persisted var fileName = ""
    @Persisted var date: Date?

    convenience init(account: String, serverUrl: String, fileName: String, date: Date? = nil) {
        self.init()

        self.primaryKey = account + serverUrl + fileName
        self.account = account
        self.serverUrl = serverUrl
        self.fileName = fileName
        self.date = date
    }
}

extension NCManageDatabase {

    // MARK: - Realm Write

    func addAutoUpload(_ account: String, serverUrl: String, fileName: String, date: Date? = nil) {
        performRealmWrite { realm in
            let newAutoUpload = tableAutoUpload(account: account, serverUrl: serverUrl, fileName: fileName, date: date)
            realm.add(newAutoUpload, update: .all)
        }
    }

    // MARK: - Realm Read
}
