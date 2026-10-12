// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB
import NextcloudKit
import Testing
@testable import Nextcloud

@Suite("Background Upload resource state")
@MainActor
struct NCAutoUploadAssetTests {
    private let account = "account"
    private let destination = "https://example.com/Photos"
    private let assetIdentifier = "56382E82-3757-4EE9-9216-9342EFE976E0/L0/001"
    private let imageClass = NKTypeClassFile.image.rawValue
    private let videoClass = NKTypeClassFile.video.rawValue

    private func makeDatabase() throws -> NCLocalDatabase {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("sqlite")
        return try NCLocalDatabase(databaseURL: url)
    }

    private func resource(video: Bool = false, session: String = "session", uploaded: Bool = false) -> NCAutoUploadResource {
        NCAutoUploadResource(account: account, serverUrlBase: destination, assetLocalIdentifier: assetIdentifier, uploadSessionIdentifier: session,
                             classFile: video ? videoClass : imageClass, fileName: video ? "0355.mov" : "0355.heic",
                             uploaded: uploaded, creationDate: Date(timeIntervalSince1970: 100))
    }

    private func history(_ database: NCLocalDatabase, session: String? = nil) async throws -> [NCAutoUploadResource] {
        try await database.autoUploadResources(account: account, serverUrlBase: destination, assetLocalIdentifier: assetIdentifier, sessionIdentifier: session)
    }

    private func metadata(video: Bool = false, identifier: String = "photo-transfer") -> tableMetadata {
        let metadata = tableMetadata()
        metadata.account = account
        metadata.assetLocalIdentifier = assetIdentifier
        metadata.autoUploadServerUrlBase = destination
        metadata.sessionSelector = NCGlobal.shared.selectorUploadAutoUpload
        metadata.ocId = identifier
        metadata.ocIdTransfer = identifier
        metadata.classFile = video ? videoClass : imageClass
        metadata.fileNameView = video ? "0355.mov" : "0355.heic"
        metadata.fileName = metadata.fileNameView
        metadata.livePhotoFile = video ? "0355.heic" : "0355.mov"
        metadata.creationDate = Date(timeIntervalSince1970: 100) as NSDate
        return metadata
    }

    @Test("A Live Photo has two independently completed rows", arguments: [false, true])
    func partialUpload(videoFirst: Bool) async throws {
        let database = try makeDatabase()
        _ = try await database.recordAutoUploadResources([resource(), resource(video: true)])
        let first = metadata(video: videoFirst, identifier: "first")
        let second = metadata(video: !videoFirst, identifier: "second")
        try await database.recordAutoUploadTransfer(first, sessionIdentifier: "session", uploaded: true)
        var rows = try await history(database)
        #expect(rows.count == 2)
        #expect(rows.filter(\.uploaded).map(\.classFile) == [first.classFile])
        #expect(rows.first(where: { $0.classFile == second.classFile })?.uploaded == false)
        try await database.recordAutoUploadTransfer(second, sessionIdentifier: "session", uploaded: true)
        rows = try await history(database)
        #expect(Set(rows.filter(\.uploaded).map(\.classFile)) == [imageClass, videoClass])
    }

    @Test("A standalone photo has one row; a missing video row is not a completed Live Photo")
    func expectedComponents() async throws {
        let database = try makeDatabase()
        let photo = metadata()
        try await database.recordAutoUploadTransfer(photo, sessionIdentifier: "session", uploaded: true)
        let rows = try await history(database)
        #expect(rows.count == 1)
        #expect(rows.first?.classFile == imageClass)
        #expect(rows.first?.fileName == photo.fileNameView)
        #expect(rows.first?.uploaded == true)
        #expect(rows.contains { $0.classFile == videoClass && $0.uploaded } == false)
        try await database.recordAutoUploadTransfer(metadata(video: true), sessionIdentifier: "session")
        let resumed = try await history(database)
        #expect(resumed.count == 2)
        #expect(resumed.first { $0.classFile == imageClass }?.uploaded == true)
        #expect(resumed.first { $0.classFile == videoClass }?.uploaded == false)
    }

    @Test("Repeated discovery retains names and completed progress for each component")
    func repeatedDiscovery() async throws {
        let database = try makeDatabase()
        _ = try await database.recordAutoUploadResources([resource(uploaded: true), resource(video: true)])
        var photo = resource()
        var video = resource(video: true)
        photo.fileName = "0356.heic"
        video.fileName = "0356.mov"
        let rows = try await database.recordAutoUploadResources([photo, video])
        #expect(rows.first(where: { $0.classFile == imageClass })?.fileName == "0355.heic")
        #expect(rows.first(where: { $0.classFile == imageClass })?.uploaded == true)
        #expect(rows.first(where: { $0.classFile == videoClass })?.fileName == "0355.mov")
        #expect(rows.first(where: { $0.classFile == videoClass })?.uploaded == false)
        #expect(try await history(database).count == 2)
    }

    @Test("Force Reupload isolates the current session; normal discovery sees previous successes")
    func sessionIsolation() async throws {
        let database = try makeDatabase()
        _ = try await database.recordAutoUploadResources([
            resource(session: "old", uploaded: true), resource(video: true, session: "old", uploaded: true),
            resource(session: "current"), resource(video: true, session: "current")
        ])
        let normal = try await history(database)
        #expect(normal.count == 4)
        #expect(Set(normal.filter(\.uploaded).map(\.classFile)) == [imageClass, videoClass])
        let forced = try await history(database, session: "current")
        #expect(forced.count == 2)
        #expect(forced.allSatisfy { !$0.uploaded })
    }

    @Test("History and removal are scoped to account, destination and asset")
    func destinationIsolation() async throws {
        let database = try makeDatabase()
        _ = try await database.recordAutoUploadResources([resource(), resource(video: true)])
        for scope in [("other", destination, assetIdentifier), (account, "other", assetIdentifier), (account, destination, "other")] {
            #expect(try await database.autoUploadResources(account: scope.0, serverUrlBase: scope.1, assetLocalIdentifier: scope.2).isEmpty)
        }
        try await database.removeAutoUploadResources(account: "other", serverUrlBase: destination)
        #expect(try await history(database).count == 2)
        try await database.removeAutoUploadResources(account: account, serverUrlBase: destination)
        #expect(try await history(database).isEmpty)
    }

    @Test("Account removal clears every destination without clearing another account")
    func accountRemoval() async throws {
        let database = try makeDatabase()
        let otherDestination = NCAutoUploadResource(account: account, serverUrlBase: "other", assetLocalIdentifier: assetIdentifier,
                                               uploadSessionIdentifier: "session", classFile: imageClass, fileName: "0355.heic",
                                               uploaded: false, creationDate: Date(timeIntervalSince1970: 100))
        let otherAccount = NCAutoUploadResource(account: "other", serverUrlBase: destination, assetLocalIdentifier: assetIdentifier,
                                               uploadSessionIdentifier: "session", classFile: imageClass, fileName: "0355.heic",
                                               uploaded: false, creationDate: otherDestination.creationDate)
        _ = try await database.recordAutoUploadResources([resource(), otherDestination, otherAccount])
        try await database.recordPhotoLibraryAssetUpload(account: account, assetLocalIdentifier: assetIdentifier,
                                                        classFile: imageClass, isLivePhoto: false, creationDate: otherDestination.creationDate)
        try await database.recordPhotoLibraryAssetUpload(account: "other", assetLocalIdentifier: assetIdentifier,
                                                        classFile: imageClass, isLivePhoto: false, creationDate: otherDestination.creationDate)
        try await database.clearDatabase(account: account)
        #expect(try await database.uploadedPhotoLibraryAssets(account: account).isEmpty)
        #expect(try await database.uploadedPhotoLibraryAssets(account: "other").count == 1)
        #expect(try await history(database).isEmpty)
        #expect(try await database.autoUploadResources(account: account, serverUrlBase: "other", assetLocalIdentifier: assetIdentifier).isEmpty)
        #expect(try await database.autoUploadResources(account: "other", serverUrlBase: destination, assetLocalIdentifier: assetIdentifier).count == 1)
    }

    @Test("The transfer identifier confirms completion after server ID replacement and file renaming")
    func transferConfirmation() async throws {
        let database = try makeDatabase()
        let photo = metadata()
        #expect(try await database.recordAutoUploadTransfer(photo, sessionIdentifier: "session"))
        photo.ocId = "server-file-id"
        photo.fileName = "renamed.heic"
        photo.fileNameView = "renamed.heic"
        #expect(try await database.recordAutoUploadTransfer(photo, uploaded: true))
        #expect(try await database.autoUploadTransferIsUploaded(photo))
        let rows = try await history(database)
        #expect(rows.count == 1)
        #expect(rows.first?.transferIdentifier == "photo-transfer")
        #expect(rows.first?.fileName == "renamed.heic")
        #expect(rows.first?.uploaded == true)
    }

    @Test("A late confirmation cannot complete a new forced session with identical file names")
    func lateConfirmation() async throws {
        let database = try makeDatabase()
        let old = metadata(identifier: "old-transfer")
        let current = metadata(identifier: "new-transfer")
        try await database.recordAutoUploadTransfer(old, sessionIdentifier: "old")
        try await database.recordAutoUploadTransfer(current, sessionIdentifier: "current")
        try await database.recordAutoUploadTransfer(old, sessionIdentifier: "current", uploaded: true)
        #expect(try await database.autoUploadTransferIsUploaded(old))
        #expect(try await database.autoUploadTransferIsUploaded(current) == false)
        #expect(try await history(database, session: "current").first?.uploaded == false)
    }

    @Test("Ordinary host uploads cannot create or complete extension history")
    func unregisteredHostUpload() async throws {
        let database = try makeDatabase()
        let ordinary = metadata(identifier: "ordinary-transfer")
        #expect(try await database.recordAutoUploadTransfer(ordinary, uploaded: true) == false)
        #expect(try await database.autoUploadResource(for: ordinary) == nil)
        let seed = metadata()
        try await database.recordAutoUploadTransfer(seed, sessionIdentifier: "session")
        #expect(try await database.recordAutoUploadTransfer(ordinary, uploaded: true) == false)
        #expect(try await database.autoUploadTransferIsUploaded(seed) == false)
    }

    @Test("PhotoKit and chunk components retain independent transfers in the same session")
    func independentChunkComponents() async throws {
        let database = try makeDatabase()
        _ = try await database.recordAutoUploadResources([resource(), resource(video: true)])
        let photo = metadata(identifier: "photokit-photo")
        photo.size = 5_000_000
        photo.backgroundUploadJobIdentifier = "pending"
        let video = metadata(video: true, identifier: "chunk-video")
        video.size = 120_000_000
        video.chunk = 100_000_000
        try await database.recordAutoUploadTransfer(photo, sessionIdentifier: "session")
        try await database.recordAutoUploadTransfer(video, sessionIdentifier: "session")
        let photoResource = try await database.autoUploadResource(for: photo)
        let videoResource = try await database.autoUploadResource(for: video)
        #expect(photoResource?.transferIdentifier == "photokit-photo")
        #expect(videoResource?.transferIdentifier == "chunk-video")
        #expect(photoResource?.uploadSessionIdentifier == videoResource?.uploadSessionIdentifier)
        try await database.recordAutoUploadTransfer(photo, uploaded: true)
        #expect(try await database.autoUploadTransferIsUploaded(photo))
        #expect(try await database.autoUploadTransferIsUploaded(video) == false)
        try await database.recordAutoUploadTransfer(video, uploaded: true)
        #expect(try await history(database).allSatisfy(\.uploaded))
        #expect(try await history(database).count == 2)
    }

    @Test("Completed components survive hundreds of incremental naming proposals")
    func completedPairRediscovery() async throws {
        let database = try makeDatabase()
        _ = try await database.recordAutoUploadResources([resource(uploaded: true), resource(video: true, uploaded: true)])
        for number in 355...617 {
            var photo = resource()
            var video = resource(video: true)
            photo.fileName = "\(number).heic"
            video.fileName = "\(number).mov"
            let rows = try await database.recordAutoUploadResources([photo, video])
            #expect(rows.allSatisfy(\.uploaded))
            #expect(rows.map(\.fileName) == ["0355.heic", "0355.mov"])
        }
        #expect(try await history(database).count == 2)
    }

    @Test("Unavailable history throws instead of appearing empty or accepting a confirmation")
    func unavailableDatabase() async throws {
        let database = try makeDatabase()
        let transfer = metadata()
        try await database.recordAutoUploadTransfer(transfer, sessionIdentifier: "session")
        try database.databasePool().close()
        await #expect(throws: (any Error).self) {
            try await history(database)
        }
        await #expect(throws: (any Error).self) {
            try await database.recordAutoUploadTransfer(transfer, uploaded: true)
        }
    }

    @Test("A success for another file name cannot mark the reserved component complete")
    func mismatchedReservation() async throws {
        let database = try makeDatabase()
        _ = try await database.recordAutoUploadResources([resource()])
        var completed = resource(uploaded: true)
        completed.fileName = "other.heic"
        let stored = try await database.recordAutoUploadResources([completed])
        #expect(stored.first?.fileName == "0355.heic")
        #expect(stored.first?.uploaded == false)
    }

    @Test("The success cache does not suppress a new attempt to the same server path")
    func cachedSuccessIdentity() async {
        let cache = NCMetadataUploadTranfersSuccess()
        let completed = metadata(identifier: "old-attempt")
        completed.account = "test-cache-" + UUID().uuidString
        completed.livePhotoFile = ""
        let path = destination + "/0355.heic"
        completed.serverUrlFileName = path
        await cache.append(metadata: completed, ocId: "server-file", date: nil, etag: nil)
        #expect(completed.ocId == "old-attempt")
        let cachedMetadatas = await cache.getAll()
        cachedMetadatas.first?.ocIdTransfer = "changed-outside-cache"
        #expect(await cache.exists(serverUrlFileName: path))
        #expect(await cache.exists(serverUrlFileName: path, transferIdentifier: "old-attempt"))
        #expect(await cache.exists(serverUrlFileName: path, transferIdentifier: "new-attempt") == false)

        let reuploaded = metadata(identifier: "new-attempt")
        reuploaded.account = completed.account
        reuploaded.livePhotoFile = ""
        reuploaded.serverUrlFileName = path
        await cache.append(metadata: reuploaded, ocId: "server-file", date: nil, etag: nil)
        #expect(await cache.count() == 2)
        #expect(await cache.exists(serverUrlFileName: path, transferIdentifier: "old-attempt"))
        #expect(await cache.exists(serverUrlFileName: path, transferIdentifier: "new-attempt"))
        await cache.append(metadata: reuploaded, ocId: "server-file", date: nil, etag: nil)
        #expect(await cache.count() == 2)
    }

    @Test("The new component table preserves existing photo-library state")
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
        let photo = NCPhotoLibraryAsset(account: account, assetLocalIdentifier: "photo", photoUploaded: true,
                                        videoUploaded: nil, creationDate: Date(timeIntervalSince1970: 100))
        try oldDatabase.write { try photo.insert($0) }
        let database = try NCLocalDatabase(databaseURL: url)
        #expect(try await database.uploadedPhotoLibraryAssets(account: account) == [photo])
        _ = try await database.recordAutoUploadResources([resource(), resource(video: true)])
        try await database.clearDBCache()
        #expect(try await history(database).isEmpty)
        #expect(try await database.uploadedPhotoLibraryAssets(account: account).isEmpty)
    }
}
