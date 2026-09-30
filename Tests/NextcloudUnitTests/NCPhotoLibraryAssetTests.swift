// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

@Suite("Photo library assets")
struct NCPhotoLibraryAssetTests {
    @Test("A photo is complete after its component is uploaded")
    func photoUpload() async throws {
        let database = try makeDatabase()
        try await database.registerPhotoLibraryAsset(
            account: "account",
            assetLocalIdentifier: "photo",
            hasPhoto: true,
            hasVideo: false,
            creationDate: Date()
        )

        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").isEmpty)
        #expect(try await database.markPhotoLibraryAssetPhotoUploaded(account: "account", assetLocalIdentifier: "photo"))
        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").map(\.assetLocalIdentifier) == ["photo"])
    }

    @Test("A Live Photo requires both components")
    func livePhotoUpload() async throws {
        let database = try makeDatabase()
        try await database.registerPhotoLibraryAsset(
            account: "account",
            assetLocalIdentifier: "live-photo",
            hasPhoto: true,
            hasVideo: true,
            creationDate: Date()
        )

        #expect(try await database.markPhotoLibraryAssetPhotoUploaded(account: "account", assetLocalIdentifier: "live-photo"))
        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").isEmpty)
        #expect(try await database.markPhotoLibraryAssetVideoUploaded(account: "account", assetLocalIdentifier: "live-photo"))
        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").map(\.assetLocalIdentifier) == ["live-photo"])
    }

    @Test("Repeated discovery and upload confirmation are idempotent")
    func repeatedUpdates() async throws {
        let database = try makeDatabase()
        let creationDate = Date()
        try await database.registerPhotoLibraryAsset(
            account: "account",
            assetLocalIdentifier: "asset",
            hasPhoto: true,
            hasVideo: false,
            creationDate: creationDate
        )
        #expect(try await database.markPhotoLibraryAssetPhotoUploaded(account: "account", assetLocalIdentifier: "asset"))

        try await database.registerPhotoLibraryAsset(
            account: "account",
            assetLocalIdentifier: "asset",
            hasPhoto: true,
            hasVideo: false,
            creationDate: creationDate
        )
        #expect(try await database.markPhotoLibraryAssetPhotoUploaded(account: "account", assetLocalIdentifier: "asset"))
        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").count == 1)
    }

    @Test("Assets are isolated by account and removed after Photos cleanup")
    func accountIsolationAndRemoval() async throws {
        let database = try makeDatabase()
        for account in ["first", "second"] {
            try await database.registerPhotoLibraryAsset(
                account: account,
                assetLocalIdentifier: "shared-identifier",
                hasPhoto: false,
                hasVideo: true,
                creationDate: Date()
            )
            #expect(try await database.markPhotoLibraryAssetVideoUploaded(account: account, assetLocalIdentifier: "shared-identifier"))
        }

        try await database.removePhotoLibraryAssets(account: "first", assetLocalIdentifiers: ["shared-identifier"])
        #expect(try await database.uploadedPhotoLibraryAssets(account: "first").isEmpty)
        #expect(try await database.uploadedPhotoLibraryAssets(account: "second").map(\.assetLocalIdentifier) == ["shared-identifier"])
    }

    @Test("Unknown or absent components are not marked as uploaded")
    func unknownComponents() async throws {
        let database = try makeDatabase()
        try await database.registerPhotoLibraryAsset(
            account: "account",
            assetLocalIdentifier: "photo",
            hasPhoto: true,
            hasVideo: false,
            creationDate: Date()
        )

        #expect(try await database.markPhotoLibraryAssetVideoUploaded(account: "account", assetLocalIdentifier: "photo") == false)
        #expect(try await database.markPhotoLibraryAssetPhotoUploaded(account: "account", assetLocalIdentifier: "missing") == false)
    }

    private func makeDatabase() throws -> NCLocalDatabase {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        return try NCLocalDatabase(databaseURL: databaseURL)
    }
}
