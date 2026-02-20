// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import RealmSwift

final class NCManageDatabase {
    static let shared = NCManageDatabase()

    internal let core: NCManageDatabaseCore
    internal let databaseURL: URL?

    private init() {
        self.core = NCManageDatabaseCore()

        if let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) {
            self.databaseURL = dirGroup
                .appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud)
                .appendingPathComponent(databaseName)
        } else {
            self.databaseURL = nil
        }
    }

    func openRealm() {
        do {
            let configuration = Realm.Configuration(
                fileURL: databaseURL,
                schemaVersion: databaseSchemaVersion,
                objectTypes: [
                    NCKeyValue.self, tableMetadata.self, tableLocalFile.self,
                    tableDirectory.self, tableTag.self, tableAccount.self
                ]
            )
            Realm.Configuration.defaultConfiguration = configuration

            let realm = try Realm(configuration: configuration)
            if let url = realm.configuration.fileURL {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)", consoleOnly: true)
            }
        } catch let error {
            nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm error: \(error)")
            isSuspendingDatabaseOperation = true
        }
    }
}
