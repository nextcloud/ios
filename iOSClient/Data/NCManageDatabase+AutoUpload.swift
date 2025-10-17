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

    func addAutoUploadTransferAsync(account: String,
                                    serverUrlBase: String,
                                    fileName: String,
                                    assetLocalIdentifier: String,
                                    date: Date) async {
        await performRealmWriteAsync { realm in
            let result = tableAutoUploadTransfer(account: account,
                                                 serverUrlBase: serverUrlBase,
                                                 fileName: fileName,
                                                 assetLocalIdentifier: assetLocalIdentifier,
                                                 date: date)
            realm.add(result, update: .all)
        }
    }

    func addAutoUploadTransferAsync(_ items: [tableAutoUploadTransfer], notSkip: Bool = false) async {
        guard !items.isEmpty else {
            return
        }

        await performRealmWriteAsync(notSkip: notSkip) { realm in
            realm.add(items, update: .all)
        }
    }

    func deleteAutoUploadTransferAsync(account: String,
                                       autoUploadServerUrlBase: String) async {
        await performRealmWriteAsync { realm in
            let result = realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
            realm.delete(result)
        }
    }

    // MARK: - Realm Read

    /// Asynchronously fetches a set of filenames that should be skipped for auto-upload,
    /// based on metadata and ongoing transfers for a given account and server URL base.
    ///
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - autoUploadServerUrlBase: The server base URL used for auto-upload.
    /// - Returns: A set of file names that are either in metadata with a relevant status or currently being transferred.
    func fetchSkipFileNamesAsync(account: String,
                                 autoUploadServerUrlBase: String) async -> Set<String> {
        let result: Set<String>? = await performRealmReadAsync { realm in
            let metadatas = realm.objects(tableMetadata.self)
                .filter("account == %@ AND autoUploadServerUrlBase == %@ AND status IN %@", account, autoUploadServerUrlBase, NCGlobal.shared.metadataStatusUploadingAllMode)
                .map(\.fileNameView)

            let transfers = realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
                .map(\.fileName)

            return Set(metadatas).union(transfers)
        }

        return result ?? []
    }

    /// Asynchronously fetches the most recent auto-uploaded date for the given account and server base URL.
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - autoUploadServerUrlBase: The server base URL for auto-upload.
    /// - Returns: The most recent upload `Date`, or `nil` if no entry exists.
    func fetchLastAutoUploadedDateAsync(account: String,
                                        autoUploadServerUrlBase: String) async -> Date? {
        await performRealmReadAsync { realm in
            realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
                .sorted(byKeyPath: "date", ascending: false)
                .first?.date
        }
    }

    func existsAutoUpload(account: String,
                          autoUploadServerUrlBase: String) -> Bool {
        return performRealmRead { realm in
            realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
                .first != nil
        } ?? false
    }

    func existsAutoUploadAsync(account: String,
                               autoUploadServerUrlBase: String) async -> Bool {
        return await performRealmReadAsync { realm in
            realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
                .first != nil
        } ?? false
    }
}
