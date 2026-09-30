// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Testing
@testable import Nextcloud

@Suite("Photo library assets")
struct NCPhotoLibraryAssetTests {
    @Test("A photo is complete after its component is uploaded")
    func photoUpload() async throws {
        let database = try makeDatabase()
        try await database.recordPhotoLibraryAssetUpload(
            account: "account",
            assetLocalIdentifier: "photo",
            classFile: NKTypeClassFile.image.rawValue,
            isLivePhoto: false,
            creationDate: Date()
        )

        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").map(\.assetLocalIdentifier) == ["photo"])
    }

    @Test("A Live Photo requires both components")
    func livePhotoUpload() async throws {
        let database = try makeDatabase()
        try await database.recordPhotoLibraryAssetUpload(
            account: "account",
            assetLocalIdentifier: "live-photo",
            classFile: NKTypeClassFile.image.rawValue,
            isLivePhoto: true,
            creationDate: Date()
        )

        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").isEmpty)
        try await database.recordPhotoLibraryAssetUpload(
            account: "account",
            assetLocalIdentifier: "live-photo",
            classFile: NKTypeClassFile.video.rawValue,
            isLivePhoto: true,
            creationDate: Date()
        )
        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").map(\.assetLocalIdentifier) == ["live-photo"])
    }

    @Test("Repeated discovery and upload confirmation are idempotent")
    func repeatedUpdates() async throws {
        let database = try makeDatabase()
        let creationDate = Date()
        try await database.recordPhotoLibraryAssetUpload(
            account: "account",
            assetLocalIdentifier: "asset",
            classFile: NKTypeClassFile.image.rawValue,
            isLivePhoto: false,
            creationDate: creationDate
        )

        try await database.recordPhotoLibraryAssetUpload(
            account: "account",
            assetLocalIdentifier: "asset",
            classFile: NKTypeClassFile.image.rawValue,
            isLivePhoto: false,
            creationDate: creationDate
        )
        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").count == 1)
    }

    @Test("Assets are isolated by account and removed after Photos cleanup")
    func accountIsolationAndRemoval() async throws {
        let database = try makeDatabase()
        for account in ["first", "second"] {
            try await database.recordPhotoLibraryAssetUpload(
                account: account,
                assetLocalIdentifier: "shared-identifier",
                classFile: NKTypeClassFile.video.rawValue,
                isLivePhoto: false,
                creationDate: Date()
            )
        }

        try await database.removePhotoLibraryAssets(account: "first", assetLocalIdentifiers: ["shared-identifier"])
        #expect(try await database.uploadedPhotoLibraryAssets(account: "first").isEmpty)
        #expect(try await database.uploadedPhotoLibraryAssets(account: "second").map(\.assetLocalIdentifier) == ["shared-identifier"])
    }

    @Test("Clearing the local database removes uploaded asset state")
    func clearDatabase() async throws {
        let database = try makeDatabase()
        try await database.recordPhotoLibraryAssetUpload(
            account: "account",
            assetLocalIdentifier: "photo",
            classFile: NKTypeClassFile.image.rawValue,
            isLivePhoto: false,
            creationDate: Date()
        )

        try await database.clearDBCache()

        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").isEmpty)
    }

    @Test("A Live Photo can complete when its video is uploaded first")
    func livePhotoVideoFirst() async throws {
        let database = try makeDatabase()
        try await database.recordPhotoLibraryAssetUpload(
            account: "account",
            assetLocalIdentifier: "live-photo",
            classFile: NKTypeClassFile.video.rawValue,
            isLivePhoto: true,
            creationDate: Date()
        )

        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").isEmpty)
        try await database.recordPhotoLibraryAssetUpload(
            account: "account",
            assetLocalIdentifier: "live-photo",
            classFile: NKTypeClassFile.image.rawValue,
            isLivePhoto: true,
            creationDate: Date()
        )
        #expect(try await database.uploadedPhotoLibraryAssets(account: "account").map(\.assetLocalIdentifier) == ["live-photo"])
    }

    private func makeDatabase() throws -> NCLocalDatabase {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        return try NCLocalDatabase(databaseURL: databaseURL)
    }
}
