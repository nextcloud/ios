// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableAutoUploadTransfer: Object {
    @Persisted(primaryKey: true) var primaryKey: String
    @Persisted var account: String
    @Persisted var serverUrl: String
    @Persisted var fileName: String
    @Persisted var assetLocalIdentifier: String
    @Persisted var date: Date

    convenience init(account: String, serverUrl: String, fileName: String, assetLocalIdentifier: String, date: Date) {
        self.init()

        self.primaryKey = account + serverUrl + fileName
        self.account = account
        self.serverUrl = serverUrl
        self.fileName = fileName
        self.assetLocalIdentifier = assetLocalIdentifier
        self.date = date
    }
}

extension NCManageDatabase {

    // MARK: - Realm Write

    func addAutoUploadTransfer(account: String, serverUrl: String, fileName: String, assetLocalIdentifier: String, date: Date, sync: Bool = false) {
        performRealmWrite(sync: sync) { realm in
            let newAutoUpload = tableAutoUploadTransfer(account: account, serverUrl: serverUrl, fileName: fileName, assetLocalIdentifier: assetLocalIdentifier, date: date)
            realm.add(newAutoUpload, update: .all)
        }
    }

    // MARK: - Realm Read

    func shouldSkipAutoUploadTransfer(account: String, serverUrl: String, fileName: String) -> Bool {
        var shouldSkip = false
        performRealmRead { realm in
            if realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND fileNameView == %@", account, serverUrl, fileName)
                .first != nil {
                shouldSkip = true
            } else if realm.objects(tableAutoUploadTransfer.self)
                        .filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName)
                        .first != nil {
                shouldSkip = true
            }
        }
        return shouldSkip
    }
}
