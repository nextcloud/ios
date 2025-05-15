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
    @Persisted var serverUrlBase: String
    @Persisted var fileName: String
    @Persisted var assetLocalIdentifier: String
    @Persisted var date: Date

    convenience init(account: String, serverUrlBase: String, fileName: String, assetLocalIdentifier: String, date: Date) {
        self.init()

        self.primaryKey = account + serverUrlBase + fileName
        self.account = account
        self.serverUrlBase = serverUrlBase
        self.fileName = fileName
        self.assetLocalIdentifier = assetLocalIdentifier
        self.date = date
    }
}

extension NCManageDatabase {

    // MARK: - Realm Write

    func addAutoUploadTransfer(account: String, serverUrlBase: String, fileName: String, assetLocalIdentifier: String, date: Date, sync: Bool = false) {
        performRealmWrite(sync: sync) { realm in
            let newAutoUpload = tableAutoUploadTransfer(account: account, serverUrlBase: serverUrlBase, fileName: fileName, assetLocalIdentifier: assetLocalIdentifier, date: date)
            realm.add(newAutoUpload, update: .all)
        }
    }

    func deleteAutoUploadTransfer(account: String, autoUploadServerUrlBase: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let result = realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
            realm.delete(result)
        }
    }

    // MARK: - Realm Read

    func fetchSkipFileNames(account: String, autoUploadServerUrlBase: String) -> Set<String> {
        var skipFileNames = Set<String>()

        performRealmRead { realm in
            let metadatas = realm.objects(tableMetadata.self)
                .filter("account == %@ AND autoUploadServerUrlBase == %@ AND status IN %@", account, autoUploadServerUrlBase, NCGlobal.shared.metadataStatusUploadingAllMode)
                .map(\.fileNameView)

            let transfers = realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
                .map(\.fileName)

            skipFileNames.formUnion(metadatas)
            skipFileNames.formUnion(transfers)
        }

        return skipFileNames
    }

    func fetchLastAutoUploadedDate(account: String, autoUploadServerUrlBase: String) -> Date? {
        performRealmRead { realm in
            realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
                .sorted(byKeyPath: "date", ascending: false)
                .first?.date
        }
    }

    func existsAutoUpload(account: String, autoUploadServerUrlBase: String) -> Bool {
        return performRealmRead { realm in
            realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
                .first != nil
        } ?? false
    }
}
