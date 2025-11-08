// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import RealmSwift

final class NCManageDatabaseFPE {
    static let shared = NCManageDatabaseFPE()

    internal let core: NCManageDatabaseCore

    init() {
        self.core = NCManageDatabaseCore()
        guard let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else {
            return
        }
        let databaseFileUrl = dirGroup.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName)
        let objectTypes = [
            NCKeyValue.self, tableMetadata.self, tableLocalFile.self,
            tableDirectory.self, tableTag.self, tableAccount.self
        ]

        do {
            // Migration configuration
            let migrationCfg = Realm.Configuration(fileURL: databaseFileUrl,
                                                   schemaVersion: databaseSchemaVersion,
                                                   migrationBlock: { migration, oldSchemaVersion in
                self.core.migrationSchema(migration, oldSchemaVersion)
            })
            try autoreleasepool {
                _ = try Realm(configuration: migrationCfg)
            }

            // Runtime and default configuration
            let runtimeCfg = Realm.Configuration(fileURL: databaseFileUrl, schemaVersion: databaseSchemaVersion, objectTypes: objectTypes)
            Realm.Configuration.defaultConfiguration = runtimeCfg

            let realm = try Realm(configuration: runtimeCfg)
            if let url = realm.configuration.fileURL {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)", consoleOnly: true)
            }
        } catch let error {
            nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm error: \(error)")
            isSuspendingDatabaseOperation = true
        }
    }
}
