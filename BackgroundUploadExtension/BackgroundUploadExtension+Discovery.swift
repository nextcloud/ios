// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    func createPendingMetadatas(account: tableAccount, limit: Int) async -> Bool {
        guard limit > 0,
              account.autoUploadImage || account.autoUploadVideo else {
            return false
        }

        let autoUploadServerUrlBase = await database.getAccountAutoUploadServerUrlBaseAsync(
            account: account.account,
            urlBase: account.urlBase,
            userId: account.userId
        )

        var skipFileNames = await database.fetchSkipFileNamesAsync(account: account.account, autoUploadServerUrlBase: autoUploadServerUrlBase)

        var skipAssetLocalIdentifiers = await database.fetchSkipAssetLocalIdentifiersAsync(
            account: account.account,
            autoUploadServerUrlBase: autoUploadServerUrlBase
        )

        let fetchOptions = PHFetchOptions()
        var mediaPredicates: [NSPredicate] = []

        if account.autoUploadImage {
            mediaPredicates.append(NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue))
        }

        if account.autoUploadVideo {
            mediaPredicates.append(NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue))
        }

        var predicates: [NSPredicate] = [NSCompoundPredicate(orPredicateWithSubpredicates: mediaPredicates)]

        if let sinceDate = account.autoUploadSinceDate {
            predicates.append(NSPredicate(format: "creationDate >= %@", sinceDate as NSDate))
        } else if let lastDate = await database.fetchLastAutoUploadedDateAsync(
            account: account.account,
            autoUploadServerUrlBase: autoUploadServerUrlBase
        ) {
            predicates.append(NSPredicate(format: "creationDate >= %@", lastDate as NSDate))
        }

        fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        var assetsByIdentifier: [String: PHAsset] = [:]

        for collection in autoUploadCollections(for: account) {
            let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)

            assets.enumerateObjects { asset, _, _ in
                assetsByIdentifier[asset.localIdentifier] = asset
            }
        }

        let assets = assetsByIdentifier.values.sorted {
            ($0.creationDate ?? .distantPast) <
            ($1.creationDate ?? .distantPast)
        }

        var remaining = limit
        var madeProgress = false
        var lastQueuedDate: Date?

        for asset in assets {
            guard remaining > 0 else {
                break
            }

            guard !skipAssetLocalIdentifiers.contains(asset.localIdentifier) else {
                continue
            }

            guard let resource = primaryUploadResource(for: asset),
                  let originalFileName = resource.filename,
                  !originalFileName.isEmpty else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Upload resource not found for asset \(asset.localIdentifier)")
                continue
            }

            let creationDate = asset.creationDate ?? Date()
            let fileName = utilityFileSystem.createFileName(originalFileName, fileDate: creationDate, fileType: asset.mediaType)

            guard !skipFileNames.contains(fileName) else {
                continue
            }

            guard await createPendingMetadata(asset: asset, resource: resource, fileName: fileName, account: account) != nil else {
                continue
            }

            skipFileNames.insert(fileName)
            skipAssetLocalIdentifiers.insert(asset.localIdentifier)
            lastQueuedDate = creationDate
            remaining -= 1
            madeProgress = true
        }

        if let lastQueuedDate {
            await database.updateAccountPropertyAsync(\.autoUploadSinceDate, value: lastQueuedDate, account: account.account)
        }

        return madeProgress
    }

    private func createPendingMetadata(asset: PHAsset, resource: PHAssetResource, fileName: String, account: tableAccount) async -> tableMetadata? {
        let session = NCSession.Session(
            account: account.account,
            urlBase: account.urlBase,
            user: account.user,
            userId: account.userId
        )

        let autoUploadServerUrlBase = await database.getAccountAutoUploadServerUrlBaseAsync(
            account: account.account,
            urlBase: account.urlBase,
            userId: account.userId
        )

        let serverUrl: String
        let wifiOnly = asset.mediaType == .image ? account.autoUploadWWAnPhoto : account.autoUploadWWAnVideo

        if account.autoUploadCreateSubfolder {
            serverUrl = utilityFileSystem.createGranularityPath(asset: asset, serverUrlBase: autoUploadServerUrlBase, granularity: account.autoUploadSubfolderGranularity)
        } else {
            serverUrl = autoUploadServerUrlBase
        }

        let metadata = await NCManageDatabaseCreateMetadata().createMetadataAsync(
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
        metadata.size = Int64(resource.dataSize ?? 0)
        metadata.width = asset.pixelWidth
        metadata.height = asset.pixelHeight

        if let creationDate = asset.creationDate {
            metadata.creationDate = creationDate as NSDate
        }

        if let modificationDate = asset.modificationDate {
            metadata.date = modificationDate as NSDate
        }

        metadata.session = wifiOnly ? nkComm.identifierSessionUploadBackgroundWWan : nkComm.identifierSessionUploadBackground
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

    private func primaryUploadResource(for asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)

        switch asset.mediaType {
        case .image:
            return resources.first {
                $0.type == .fullSizePhoto
            } ?? resources.first {
                $0.type == .photo
            }

        case .video:
            return resources.first {
                $0.type == .fullSizeVideo
            } ?? resources.first {
                $0.type == .video
            }

        default:
            return nil
        }
    }

    private func autoUploadCollections(for account: tableAccount) -> [PHAssetCollection] {
        let albumIds = NCPreferences().getAutoUploadAlbumIds(account: account.account)

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
}
