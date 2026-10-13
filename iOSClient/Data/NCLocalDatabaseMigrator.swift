// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import GRDB

/// Defines the ordered schema migrations for the local SQLite database.
enum NCLocalDatabaseMigrator {
    static func migrate(_ databaseWriter: any DatabaseWriter) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("initialSchema") { database in
            try database.create(table: "photoLibraryAsset") { table in
                table.column("account", .text).notNull()
                table.column("assetLocalIdentifier", .text).notNull()

                // nil: the component does not exist; false: pending; true: uploaded.
                table.column("photoUploaded", .boolean)
                table.column("videoUploaded", .boolean)
                table.column("creationDate", .datetime).notNull()

                table.primaryKey(["account", "assetLocalIdentifier"])
            }
        }

        migrator.registerMigration("backgroundAutoUploadResources") { database in
            try database.create(table: "autoUploadResource") { table in
                table.column("account", .text).notNull()
                table.column("serverUrlBase", .text).notNull()
                table.column("assetLocalIdentifier", .text).notNull()
                table.column("uploadSessionIdentifier", .text).notNull()
                table.column("classFile", .text).notNull()
                table.column("fileName", .text).notNull()
                table.column("uploaded", .boolean).notNull().defaults(to: false)
                table.column("creationDate", .datetime).notNull()
                table.column("transferIdentifier", .text)
                table.primaryKey(["account", "serverUrlBase", "assetLocalIdentifier", "uploadSessionIdentifier", "classFile"])
            }
        }

        try migrator.migrate(databaseWriter)
    }
}
