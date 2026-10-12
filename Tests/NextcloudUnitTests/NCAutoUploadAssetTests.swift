// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB
import Testing
@testable import Nextcloud

@Suite("Background Upload asset state")
struct NCAutoUploadAssetTests {
    private func makeDatabase() throws -> NCLocalDatabase {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("sqlite")
        return try NCLocalDatabase(databaseURL: url)
    }

    private func asset(session: String = "session") -> NCAutoUploadAsset {
        NCAutoUploadAsset(account: "account", serverUrlBase: "https://example.com/Photos", assetLocalIdentifier: "live-photo",
                          uploadSessionIdentifier: session, photoUploaded: false, videoUploaded: false,
                          photoFileName: "0355.heic", videoFileName: "0355.mov", creationDate: Date(timeIntervalSince1970: 100))
    }

    @Test("A Live Photo requires both components regardless of completion order", arguments: [false, true])
    func partialUpload(videoFirst: Bool) async throws {
        let database = try makeDatabase()
        var progress = asset()
        if videoFirst { progress.videoUploaded = true } else { progress.photoUploaded = true }
        #expect(try await database.recordAutoUploadAsset(progress).isUploaded == false)
        if videoFirst { progress.photoUploaded = true } else { progress.videoUploaded = true }
        #expect(try await database.recordAutoUploadAsset(progress).isUploaded)
    }

    @Test("Repeated discovery preserves successes and the assigned pair names")
    func repeatedDiscovery() async throws {
        let database = try makeDatabase()
        var progress = asset()
        progress.photoUploaded = true
        try await database.recordAutoUploadAsset(progress)
        var rediscovered = asset()
        rediscovered.photoFileName = "0356.heic"
        rediscovered.videoFileName = "0356.mov"
        let stored = try await database.recordAutoUploadAsset(rediscovered)
        #expect(stored.photoUploaded == true)
        #expect(stored.videoUploaded == false)
        #expect(stored.photoFileName == "0355.heic")
        #expect(stored.videoFileName == "0355.mov")
        #expect(try await database.autoUploadAssets(account: progress.account, serverUrlBase: progress.serverUrlBase, assetLocalIdentifier: progress.assetLocalIdentifier).count == 1)
    }

    @Test("Normal history includes previous sessions; Force Reupload can isolate the current session")
    func sessionIsolation() async throws {
        let database = try makeDatabase()
        var old = asset(session: "old")
        old.photoUploaded = true
        old.videoUploaded = true
        try await database.recordAutoUploadAsset(old)
        let current = asset(session: "current")
        try await database.recordAutoUploadAsset(current)
        let history = try await database.autoUploadAssets(account: current.account, serverUrlBase: current.serverUrlBase, assetLocalIdentifier: current.assetLocalIdentifier)
        #expect(history.count == 2)
        #expect(history.contains(where: \.isUploaded))
        let forced = try await database.autoUploadAssets(account: current.account, serverUrlBase: current.serverUrlBase,
                                                        assetLocalIdentifier: current.assetLocalIdentifier, sessionIdentifier: current.uploadSessionIdentifier)
        #expect(forced == [current])
    }

    @Test("An asset without components is incomplete; a standalone photo needs only its image")
    func expectedComponents() async throws {
        let database = try makeDatabase()
        var progress = asset()
        progress.photoUploaded = nil
        progress.videoUploaded = nil
        #expect(try await database.recordAutoUploadAsset(progress).isUploaded == false)
        progress.photoUploaded = true
        #expect(try await database.recordAutoUploadAsset(progress).isUploaded)
        progress.videoUploaded = false
        #expect(try await database.recordAutoUploadAsset(progress).isUploaded == false)
    }

    @Test("History and removal are scoped to account and destination")
    func destinationIsolation() async throws {
        let database = try makeDatabase()
        let progress = asset()
        try await database.recordAutoUploadAsset(progress)
        #expect(try await database.autoUploadAssets(account: "other", serverUrlBase: progress.serverUrlBase, assetLocalIdentifier: progress.assetLocalIdentifier).isEmpty)
        #expect(try await database.autoUploadAssets(account: progress.account, serverUrlBase: "other", assetLocalIdentifier: progress.assetLocalIdentifier).isEmpty)
        try await database.removeAutoUploadAssets(account: "other", serverUrlBase: progress.serverUrlBase)
        #expect(try await database.autoUploadAssets(account: progress.account, serverUrlBase: progress.serverUrlBase, assetLocalIdentifier: progress.assetLocalIdentifier).count == 1)
        try await database.removeAutoUploadAssets(account: progress.account, serverUrlBase: progress.serverUrlBase)
        #expect(try await database.autoUploadAssets(account: progress.account, serverUrlBase: progress.serverUrlBase, assetLocalIdentifier: progress.assetLocalIdentifier).isEmpty)
    }

    @Test("Adding the table preserves the existing photo-library database")
    func existingSchema() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("sqlite")
        let oldDatabase = try DatabaseQueue(path: url.path)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("initialSchema") { database in
            try database.create(table: "photoLibraryAsset") { table in
                table.column("account", .text).notNull()
                table.column("assetLocalIdentifier", .text).notNull()
                table.column("photoUploaded", .boolean)
                table.column("videoUploaded", .boolean)
                table.column("creationDate", .datetime).notNull()
                table.primaryKey(["account", "assetLocalIdentifier"])
            }
        }
        try migrator.migrate(oldDatabase)
        let photo = NCPhotoLibraryAsset(account: "account", assetLocalIdentifier: "photo", photoUploaded: true, videoUploaded: nil, creationDate: Date(timeIntervalSince1970: 100))
        try oldDatabase.write { try photo.insert($0) }
        let database = try NCLocalDatabase(databaseURL: url)
        #expect(try await database.uploadedPhotoLibraryAssets(account: "account") == [photo])
        try await database.recordAutoUploadAsset(asset())
        try await database.clearDBCache()
        #expect(try await database.autoUploadAssets(account: "account", serverUrlBase: asset().serverUrlBase, assetLocalIdentifier: "live-photo").isEmpty)
    }
}
