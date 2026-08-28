// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {

    func setupAccounts() async -> [tableAccount] {
        let accounts = await database.getAllTableAccountAsync()

        for account in accounts {
            NextcloudKit.shared.appendSession(
                account: account.account,
                urlBase: account.urlBase,
                user: account.user,
                userId: account.userId,
                password: NCPreferences().getPassword(account: account.account),
                userAgent: userAgent,
                httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                groupIdentifier:NCBrandOptions.shared.capabilitiesGroup
            )
        }

        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            return []
        }

        guard !NCPreferences().formatCompatibility else {
            return []
        }

        return accounts.filter(\.autoUploadStart)
    }

    func createPendingMetadatas(accounts: [tableAccount]) async -> Bool {
        // Lo implementiamo nel prossimo passaggio.
        return false
    }

    private func autoUploadCollections(for account: tableAccount) -> [PHAssetCollection] {
        let albumIds = NCPreferences().getAutoUploadAlbumIds(
            account: account.account
        )

        if !albumIds.isEmpty {
            let result = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: Array(albumIds), options: nil)
            var collections: [PHAssetCollection] = []

            result.enumerateObjects { collection, _, _ in
                collections.append(collection)
            }

            if !collections.isEmpty {
                return collections
            }
        }

        let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)

        guard let cameraRoll = result.firstObject else {
            return []
        }

        return [cameraRoll]
    }

    private func createPendingMetadata(asset: PHAsset, resource: PHAssetResource, account: tableAccount
    ) async -> tableMetadata? {
        guard let fileName = resource.filename,
              !fileName.isEmpty else {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: """
                Resource without filename: \
                \(asset.localIdentifier)
                """
            )
            return nil
        }

        // Non usiamo NCSession.shared: nell’estensione è vuoto.
        let session = NCSession.Session(
            account: account.account,
            urlBase: account.urlBase,
            user: account.user,
            userId: account.userId
        )

        let autoUploadServerUrlBase =
            await database.getAccountAutoUploadServerUrlBaseAsync(
                    account: account.account,
                    urlBase: account.urlBase,
                    userId: account.userId
                )

        let serverUrl: String

        if account.autoUploadCreateSubfolder {
            serverUrl = utilityFileSystem.createGranularityPath(
                asset: asset,
                serverUrlBase: autoUploadServerUrlBase
            )
        } else {
            serverUrl = autoUploadServerUrlBase
        }

        let metadata =
            await NCManageDatabaseCreateMetadata()
                .createMetadataAsync(
                    fileName: fileName,
                    ocId: UUID().uuidString,
                    serverUrl: serverUrl,
                    session: session,
                    sceneIdentifier: nil
                )

        metadata.assetLocalIdentifier = asset.localIdentifier
        metadata.autoUploadServerUrlBase = autoUploadServerUrlBase
        metadata.nativeFormat = true
        metadata.contentType = resource.contentType.preferredMIMEType ?? "application/octet-stream"
        metadata.typeIdentifier = resource.contentType.identifier

        if let creationDate = asset.creationDate {
            metadata.creationDate = creationDate as NSDate
        }

        if let modificationDate = asset.modificationDate {
            metadata.date = modificationDate as NSDate
        }

        metadata.session = ""
        metadata.sessionSelector = global.selectorUploadAutoUpload
        metadata.sessionDate = Date()
        metadata.status = global.metadataStatusWaitUpload
        metadata.backgroundUploadJobIdentifier = "pending"

        await database.addMetadataAsync(metadata)

        nkLog(
            tag: global.logTagBackgroundUpload,
            message: """
            Created pending metadata for \(fileName), \
            account: \(account.account), \
            asset: \(asset.localIdentifier)
            """
        )

        return metadata
    }
}
