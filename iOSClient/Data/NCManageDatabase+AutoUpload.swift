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
    @Persisted var autoUploadServerUrl: String
    @Persisted var fileName: String
    @Persisted var assetLocalIdentifier: String
    @Persisted var date: Date

    convenience init(account: String, autoUploadServerUrl: String, fileName: String, assetLocalIdentifier: String, date: Date) {
        self.init()

        self.primaryKey = account + autoUploadServerUrl + fileName
        self.account = account
        self.autoUploadServerUrl = autoUploadServerUrl
        self.fileName = fileName
        self.assetLocalIdentifier = assetLocalIdentifier
        self.date = date
    }
}

extension NCManageDatabase {

    // MARK: - Realm Write

    func addAutoUploadTransfer(account: String, autoUploadServerUrl: String, fileName: String, assetLocalIdentifier: String, date: Date, sync: Bool = false) {
        performRealmWrite(sync: sync) { realm in
            let newAutoUpload = tableAutoUploadTransfer(account: account, autoUploadServerUrl: autoUploadServerUrl, fileName: fileName, assetLocalIdentifier: assetLocalIdentifier, date: date)
            realm.add(newAutoUpload, update: .all)
        }
    }

    // MARK: - Realm Read

    func fetchSkipFileNames(account: String, autoUploadServerUrl: String) -> Set<String> {
        var skipFileNames = Set<String>()

        performRealmRead { realm in
            let metadatas = realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@", account, autoUploadServerUrl)
                .map(\.fileNameView)

            let transfers = realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND autoUploadServerUrl == %@", account, autoUploadServerUrl)
                .map(\.fileName)

            skipFileNames.formUnion(metadatas)
            skipFileNames.formUnion(transfers)
        }

        return skipFileNames
    }

    func fetchLastAutoUploadedDate(account: String, autoUploadServerUrl: String) -> Date? {
        performRealmRead { realm in
            realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND autoUploadServerUrl == %@", account, autoUploadServerUrl)
                .sorted(byKeyPath: "date", ascending: false)
                .first?.date
        }
    }
}
