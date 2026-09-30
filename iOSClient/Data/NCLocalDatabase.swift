// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB

/// Owns the shared SQLite database used for local state that must survive Realm refreshes.
/// The database is opened lazily in the App Group and can later be shared with app extensions.
final class NCLocalDatabase: @unchecked Sendable {
    static let shared = NCLocalDatabase()

    private let lock = NSLock()
    private var storedDatabasePool: DatabasePool?

    private init() { }

    /// Opens an isolated database at a caller-provided location.
    init(databaseURL: URL) throws {
        self.storedDatabasePool = try Self.makeDatabasePool(at: databaseURL)
    }

    /// Creates the database and applies pending migrations when it is first needed.
    func open() throws {
        _ = try databasePool()
    }

    /// Returns the shared pool after ensuring that the database is ready for use.
    func databasePool() throws -> DatabasePool {
        lock.lock()
        defer { lock.unlock() }

        if let storedDatabasePool {
            return storedDatabasePool
        }

        let databasePool = try Self.makeDatabasePool()
        self.storedDatabasePool = databasePool
        return databasePool
    }

    /// Clears the local state stored in GRDB while preserving its schema and migrations.
    func clearDBCache() async throws {
        let databasePool = try databasePool()
        try await databasePool.write { database in
            _ = try NCPhotoLibraryAsset.deleteAll(database)
        }
    }

#if DEBUG
    /// Creates a consistent database snapshot that can be inspected with a desktop SQLite browser.
    func exportDebugDatabase() throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let exportURL = documentsURL.appendingPathComponent("nextcloud-debug.sqlite")

        if fileManager.fileExists(atPath: exportURL.path) {
            try fileManager.removeItem(at: exportURL)
        }

        let exportDatabase = try DatabaseQueue(path: exportURL.path)
        try databasePool().backup(to: exportDatabase)
        return exportURL
    }
#endif

    private static func makeDatabasePool() throws -> DatabasePool {
        let fileManager = FileManager.default
        guard let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup
        ) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSFilePathErrorKey: NCBrandOptions.shared.capabilitiesGroup
            ])
        }

        let databaseDirectoryURL = appGroupURL
            .appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud, isDirectory: true)
        try fileManager.createDirectory(at: databaseDirectoryURL, withIntermediateDirectories: true)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: databaseDirectoryURL.path
        )

        let databaseURL = databaseDirectoryURL.appendingPathComponent("nextcloud.sqlite")
        return try makeDatabasePool(at: databaseURL)
    }

    private static func makeDatabasePool(at databaseURL: URL) throws -> DatabasePool {
        let databasePool = try DatabasePool(path: databaseURL.path)
        try NCLocalDatabaseMigrator.migrate(databasePool)
        return databasePool
    }
}
