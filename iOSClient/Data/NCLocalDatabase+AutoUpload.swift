// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB
import NextcloudKit

/// One Background Upload component of a PhotoKit asset, scoped to a destination and session.
struct NCAutoUploadResource: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "autoUploadResource"

    let account: String
    let serverUrlBase: String
    let assetLocalIdentifier: String
    let uploadSessionIdentifier: String
    let classFile: String
    var fileName: String
    var uploaded: Bool
    let creationDate: Date
    var transferIdentifier: String?

    /// Chooses one naming context; successes for differently named pairs cannot complete each other.
    static func discoveryResources(from history: [Self], sessionIdentifier: String, activeTransferIdentifiers: Set<String>) -> [Self] {
        let previousSession = history.first { $0.transferIdentifier.map(activeTransferIdentifiers.contains) == true }?.uploadSessionIdentifier
            ?? history.first { $0.uploadSessionIdentifier == sessionIdentifier }?.uploadSessionIdentifier
            ?? history.first { $0.uploaded }?.uploadSessionIdentifier ?? history.first?.uploadSessionIdentifier
        return history.filter { $0.uploadSessionIdentifier == previousSession }.map { resource in
            var resource = resource
            resource.uploaded = history.contains { $0.classFile == resource.classFile && $0.fileName == resource.fileName && $0.uploaded }
            return resource
        }
    }
}

/// Background Upload history shared by the extension and host-app chunk completion.
extension NCLocalDatabase {
    /// Reserves all required components atomically, retaining their first names and confirmed progress.
    func recordAutoUploadResources(_ resources: [NCAutoUploadResource]) async throws -> [NCAutoUploadResource] {
        let databasePool = try databasePool()
        return try await databasePool.write { database in
            try resources.map { try Self.saveAutoUploadResource($0, in: database) }
        }
    }

    private static func saveAutoUploadResource(_ resource: NCAutoUploadResource, in database: Database) throws -> NCAutoUploadResource {
        if var stored = try NCAutoUploadResource.fetchOne(database, key: [
            "account": resource.account,
            "serverUrlBase": resource.serverUrlBase,
            "assetLocalIdentifier": resource.assetLocalIdentifier,
            "uploadSessionIdentifier": resource.uploadSessionIdentifier,
            "classFile": resource.classFile
        ]) {
            stored.uploaded = stored.uploaded || (stored.fileName == resource.fileName && resource.uploaded)
            stored.transferIdentifier = resource.transferIdentifier ?? stored.transferIdentifier
            try stored.update(database)
            return stored
        }
        try resource.insert(database)
        return resource
    }

    /// Normal discovery reads all sessions; Force Reupload supplies the current session identifier.
    /// Discovery checks every component expected by PhotoKit, including a missing resource row.
    func autoUploadResources(account: String, serverUrlBase: String, assetLocalIdentifier: String, sessionIdentifier: String? = nil) async throws -> [NCAutoUploadResource] {
        let databasePool = try databasePool()
        return try await databasePool.read { database in
            var request = NCAutoUploadResource
                .filter(Column("account") == account)
                .filter(Column("serverUrlBase") == serverUrlBase)
                .filter(Column("assetLocalIdentifier") == assetLocalIdentifier)
            if let sessionIdentifier {
                request = request.filter(Column("uploadSessionIdentifier") == sessionIdentifier)
            }
            return try request.fetchAll(database)
        }
    }

    /// Registers extension metadata or confirms an owned component.
    /// Without a session or a registered transfer, ordinary host-app uploads do not create background history.
    @discardableResult
    func recordAutoUploadTransfer(_ metadata: tableMetadata, sessionIdentifier: String? = nil, uploaded: Bool = false) async throws -> Bool {
        guard metadata.sessionSelector == NCGlobal.shared.selectorUploadAutoUpload,
              let serverUrlBase = metadata.autoUploadServerUrlBase,
              !metadata.assetLocalIdentifier.isEmpty,
              [NKTypeClassFile.image.rawValue, NKTypeClassFile.video.rawValue].contains(metadata.classFile) else { return false }
        let incoming = NCAutoUploadResource(
            account: metadata.account,
            serverUrlBase: serverUrlBase,
            assetLocalIdentifier: metadata.assetLocalIdentifier,
            uploadSessionIdentifier: sessionIdentifier ?? "",
            classFile: metadata.classFile,
            fileName: metadata.fileNameView,
            uploaded: uploaded,
            creationDate: metadata.creationDate as Date,
            transferIdentifier: metadata.ocIdTransfer.isEmpty ? metadata.ocId : metadata.ocIdTransfer
        )
        let databasePool = try databasePool()
        return try await databasePool.write { database in
            let scope = NCAutoUploadResource
                .filter(Column("account") == incoming.account)
                .filter(Column("serverUrlBase") == incoming.serverUrlBase)
                .filter(Column("assetLocalIdentifier") == incoming.assetLocalIdentifier)
            let owner = try scope.filter(Column("classFile") == incoming.classFile && Column("transferIdentifier") == incoming.transferIdentifier).fetchOne(database)
            if var owner, uploaded {
                owner.fileName = incoming.fileName
                owner.uploaded = true
                try owner.update(database)
                return true
            }
            guard let uploadSessionIdentifier = owner?.uploadSessionIdentifier ?? sessionIdentifier else { return false }
            let resource = NCAutoUploadResource(
                account: incoming.account,
                serverUrlBase: incoming.serverUrlBase,
                assetLocalIdentifier: incoming.assetLocalIdentifier,
                uploadSessionIdentifier: uploadSessionIdentifier,
                classFile: incoming.classFile,
                fileName: incoming.fileName,
                uploaded: incoming.uploaded,
                creationDate: incoming.creationDate,
                transferIdentifier: incoming.transferIdentifier
            )
            _ = try Self.saveAutoUploadResource(resource, in: database)
            return true
        }
    }

    /// Checks completion of an extension-owned component before the host app uploads it.
    func autoUploadTransferIsUploaded(_ metadata: tableMetadata) async throws -> Bool {
        try await autoUploadResource(for: metadata)?.uploaded == true
    }

    /// Resolves one extension-owned resource without treating ordinary host-app uploads as registered.
    func autoUploadResource(for metadata: tableMetadata) async throws -> NCAutoUploadResource? {
        guard metadata.sessionSelector == NCGlobal.shared.selectorUploadAutoUpload,
              let serverUrlBase = metadata.autoUploadServerUrlBase else { return nil }
        let account = metadata.account
        let assetIdentifier = metadata.assetLocalIdentifier
        let transferIdentifier = metadata.ocIdTransfer.isEmpty ? metadata.ocId : metadata.ocIdTransfer
        let classFile = metadata.classFile
        let databasePool = try databasePool()
        return try await databasePool.read { database in
            let owner = try NCAutoUploadResource
                .filter(Column("account") == account && Column("serverUrlBase") == serverUrlBase && Column("assetLocalIdentifier") == assetIdentifier)
                .filter(Column("classFile") == classFile && Column("transferIdentifier") == transferIdentifier)
                .fetchOne(database)
            return owner
        }
    }

    func removeAutoUploadResources(account: String, serverUrlBase: String? = nil) async throws {
        let databasePool = try databasePool()
        try await databasePool.write { database in
            var request = NCAutoUploadResource.filter(Column("account") == account)
            if let serverUrlBase {
                request = request.filter(Column("serverUrlBase") == serverUrlBase)
            }
            _ = try request.deleteAll(database)
        }
    }
}
