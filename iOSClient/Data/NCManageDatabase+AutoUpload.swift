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
        await core.performRealmWriteAsync { realm in
            let result = tableAutoUploadTransfer(account: account,
                                                 serverUrlBase: serverUrlBase,
                                                 fileName: fileName,
                                                 assetLocalIdentifier: assetLocalIdentifier,
                                                 date: date)
            realm.add(result, update: .all)
        }
    }

    func addAutoUploadTransferAsync(_ items: [tableAutoUploadTransfer]) async {
        guard !items.isEmpty else {
            return
        }

        await core.performRealmWriteAsync { realm in
            realm.add(items, update: .all)
        }
    }

    func deleteAutoUploadTransferAsync(account: String,
                                       autoUploadServerUrlBase: String) async {
        await core.performRealmWriteAsync { realm in
            let result = realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
            realm.delete(result)
        }
    }

    // MARK: - Realm Read

    /// Separates queued files from confirmed uploads for incremental discovery.
    ///
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - autoUploadServerUrlBase: The server base URL used for auto-upload.
    /// - Returns: File names queued or already uploaded to this destination.
    func fetchAutoUploadFileNamesAsync(account: String, autoUploadServerUrlBase: String) async -> (queued: Set<String>, uploaded: Set<String>) {
        let result = await core.performRealmReadAsync { realm in
            let metadatas = realm.objects(tableMetadata.self)
                .filter("account == %@ AND autoUploadServerUrlBase == %@ AND status IN %@", account, autoUploadServerUrlBase, NCGlobal.shared.metadataStatusUploadingAllMode)
                .map(\.fileNameView)

            let transfers = realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
                .map(\.fileName)

            return (queued: Set(metadatas), uploaded: Set(transfers))
        }

        return result ?? (queued: [], uploaded: [])
    }

    /// Keeps the bulk asset lookup while distinguishing tracked resources from confirmed uploads.
    func fetchAutoUploadAssetIdentifiersAsync(account: String, autoUploadServerUrlBase: String, createdOnOrAfter startDate: Date? = nil) async -> (tracked: Set<String>, uploaded: Set<String>) {
        let result = await core.performRealmReadAsync { realm in
            var metadatas = realm.objects(tableMetadata.self)
                .filter("account == %@ AND autoUploadServerUrlBase == %@ AND assetLocalIdentifier != ''",
                        account, autoUploadServerUrlBase)
            var transfers = realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@ AND assetLocalIdentifier != ''",
                        account, autoUploadServerUrlBase)

            if let startDate {
                metadatas = metadatas.filter("creationDate >= %@", startDate as NSDate)
                transfers = transfers.filter("date >= %@", startDate as NSDate)
            }

            let metadataIdentifiers = metadatas.map(\.assetLocalIdentifier)
            let transferIdentifiers = transfers.map(\.assetLocalIdentifier)

            return (tracked: Set(metadataIdentifiers), uploaded: Set(transferIdentifiers))
        }

        return result ?? (tracked: [], uploaded: [])
    }

    /// Returns active auto-upload file names that must not be queued a second time.
    /// This bounded set is fetched once per discovery pass instead of once for every candidate.
    func fetchActiveAutoUploadFileNamesAsync(account: String, autoUploadServerUrlBase: String) async -> Set<String> {
        let result: Set<String>? = await core.performRealmReadAsync { realm in
            let metadatas = realm.objects(tableMetadata.self)
                .filter("account == %@ AND autoUploadServerUrlBase == %@ AND status IN %@", account, autoUploadServerUrlBase, NCGlobal.shared.metadataStatusUploadingAllMode)
            var fileNames = Set(metadatas.map(\.fileNameView))

            // A deferred Live Photo uses one seed metadata; reserve its paired filename until
            // NCCameraRoll extracts both resources in the host app.
            for metadata in metadatas where metadata.chunk > 0 &&
                !metadata.isExtractFile &&
                metadata.backgroundUploadJobIdentifier.isEmpty &&
                !metadata.livePhotoFile.isEmpty {
                fileNames.insert(metadata.livePhotoFile)
            }

            return fileNames
        }

        return result ?? []
    }

    /// Returns candidate file names found in completed auto-upload history.
    /// Primary-key lookups keep the check proportional to the current asset's one or two resources.
    func fetchTransferredAutoUploadFileNamesAsync(account: String, autoUploadServerUrlBase: String, fileNames: [String]) async -> Set<String> {
        guard !fileNames.isEmpty else {
            return []
        }

        let result: Set<String>? = await core.performRealmReadAsync { realm in
            let transferredFileNames = fileNames.compactMap { fileName in
                let primaryKey = account + autoUploadServerUrlBase + fileName
                return realm.object(ofType: tableAutoUploadTransfer.self, forPrimaryKey: primaryKey)?.fileName
            }

            return Set(transferredFileNames)
        }

        return result ?? []
    }

    func countAutoUploadMetadatasAsync(account: String,
                                       autoUploadServerUrlBase: String) async -> (pending: Int, failed: Int) {
        let global = NCGlobal.shared
        let pendingStatuses = global.metadatasStatusInWaitingDownloadUpload + global.metadatasStatusDownloadingUploading
        let failedStatuses = [global.metadataStatusUploadError]

        let result = await core.performRealmReadAsync { realm -> (pending: Int, failed: Int) in
            let scope = realm.objects(tableMetadata.self)
                .filter("account == %@ AND autoUploadServerUrlBase == %@ AND directory == false AND sessionSelector == %@",
                        account,
                        autoUploadServerUrlBase,
                        global.selectorUploadAutoUpload)

            let pendingCount = scope.filter("status IN %@", pendingStatuses).count
            let failedCount = scope.filter("status IN %@", failedStatuses).count

            return (pending: pendingCount, failed: failedCount)
        }

        return result ?? (pending: 0, failed: 0)
    }

    func existsAutoUpload(account: String,
                          autoUploadServerUrlBase: String) -> Bool {
        return core.performRealmRead { realm in
            realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
                .first != nil
        } ?? false
    }

    func existsAutoUploadAsync(account: String,
                               autoUploadServerUrlBase: String) async -> Bool {
        return await core.performRealmReadAsync { realm in
            realm.objects(tableAutoUploadTransfer.self)
                .filter("account == %@ AND serverUrlBase == %@", account, autoUploadServerUrlBase)
                .first != nil
        } ?? false
    }
}
