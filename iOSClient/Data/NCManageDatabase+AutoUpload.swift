// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableAutoUpload: Object {
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

    func addAutoUpload(account: String, serverUrl: String, fileName: String, assetLocalIdentifier: String, date: Date) {
        performRealmWrite { realm in
            let newAutoUpload = tableAutoUpload(account: account, serverUrl: serverUrl, fileName: fileName, assetLocalIdentifier: assetLocalIdentifier, date: date)
            realm.add(newAutoUpload, update: .all)
        }
    }

    // MARK: - Realm Read

    func shouldSkipAutoUpload(account: String, serverUrl: String, fileName: String) -> Bool {
        var shouldSkip = false
        performRealmRead { realm in
            let metadataExists = realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND fileNameView == %@)", account, serverUrl, fileName)
                .first != nil

            let autoUploadExists = realm.objects(tableAutoUpload.self)
                .filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName)
                .first != nil

            shouldSkip = metadataExists || autoUploadExists
        }
        return shouldSkip
    }
}
