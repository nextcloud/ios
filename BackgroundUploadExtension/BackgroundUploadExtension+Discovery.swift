// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    /// Finds eligible assets and creates up to `limit` pending metadata records for their resources.
    /// Existing transfers are skipped and the account discovery cursor advances only after queuing work.
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

        let livePhotoEnabled = NCPreferences().livePhoto
        let fetchOptions = PHFetchOptions()
        var mediaPredicates: [NSPredicate] = []

        if account.autoUploadImage {
            mediaPredicates.append(NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue))
        }

        if account.autoUploadVideo {
            mediaPredicates.append(NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue))
        }

        var predicates: [NSPredicate] = [NSCompoundPredicate(orPredicateWithSubpredicates: mediaPredicates)]

        let discoveryStartDate: Date?

        if let sinceDate = account.autoUploadSinceDate {
            discoveryStartDate = sinceDate
        } else {
            discoveryStartDate = await database.fetchLastAutoUploadedDateAsync(
                account: account.account,
                autoUploadServerUrlBase: autoUploadServerUrlBase
            )
        }

        if let discoveryStartDate {
            predicates.append(NSPredicate(format: "creationDate >= %@", discoveryStartDate as NSDate))
        }

        fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let fetchResults = autoUploadCollections(for: account).map {
            PHAsset.fetchAssets(in: $0, options: fetchOptions)
        }
        var fetchIndexes = Array(repeating: 0, count: fetchResults.count)
        var yieldedAssetIdentifiers = Set<String>()
        var skipAssetLocalIdentifiers = await database.fetchSkipAssetLocalIdentifiersAsync(
            account: account.account,
            autoUploadServerUrlBase: autoUploadServerUrlBase,
            createdOnOrAfter: discoveryStartDate
        )
        var trackedMetadataFileNames = await database.fetchActiveAutoUploadFileNamesAsync(
            account: account.account,
            autoUploadServerUrlBase: autoUploadServerUrlBase
        )

        var remaining = limit
        var madeProgress = false
        var lastQueuedDate: Date?

        // PhotoKit already sorts every result; merge them lazily and stop as soon as the job slots are full.
        while remaining > 0,
              let asset = nextAsset(from: fetchResults, indexes: &fetchIndexes, yieldedIdentifiers: &yieldedAssetIdentifiers) {

            let isLivePhoto = asset.mediaSubtypes.contains(.photoLive) && livePhotoEnabled

            guard isLivePhoto || !skipAssetLocalIdentifiers.contains(asset.localIdentifier) else {
                continue
            }

            guard let primaryResource = primaryUploadResource(for: asset),
                  let originalFileName = primaryResource.filename,
                  !originalFileName.isEmpty else {
                logError("Upload resource not found for asset \(asset.localIdentifier)")
                continue
            }

            let creationDate = asset.creationDate ?? Date()
            let primaryFileName = utilityFileSystem.createFileName(originalFileName, fileDate: creationDate, fileType: asset.mediaType)
            let primaryClassFile = asset.mediaType == .video ? NKTypeClassFile.video.rawValue : NKTypeClassFile.image.rawValue

            var uploadResources: [(resource: PHAssetResource, fileName: String, classFile: String, livePhotoFile: String)]

            if isLivePhoto {
                guard let pairedVideoResource = pairedVideoResource(for: asset) else {
                    logError("Paired video resource not found for Live Photo asset \(asset.localIdentifier)")
                    continue
                }

                let videoFileName = (primaryFileName as NSString).deletingPathExtension + ".mov"

                uploadResources = [
                    (primaryResource, primaryFileName, NKTypeClassFile.image.rawValue, videoFileName),
                    (pairedVideoResource, videoFileName, NKTypeClassFile.video.rawValue, primaryFileName)
                ]
            } else {
                uploadResources = [
                    (primaryResource, primaryFileName, primaryClassFile, "")
                ]
            }

            let fileNames = uploadResources.map(\.fileName)
            let transferredFileNames = await database.fetchTransferredAutoUploadFileNamesAsync(account: account.account, autoUploadServerUrlBase: autoUploadServerUrlBase, fileNames: fileNames)
            let resourcesToUpload = uploadResources.filter {
                !trackedMetadataFileNames.contains($0.fileName) && !transferredFileNames.contains($0.fileName)
            }

            guard resourcesToUpload.count <= remaining else {
                break
            }

            for uploadResource in resourcesToUpload {
                guard await createPendingMetadata(
                    asset: asset,
                    resource: uploadResource.resource,
                    fileName: uploadResource.fileName,
                    classFile: uploadResource.classFile,
                    livePhotoFile: uploadResource.livePhotoFile,
                    account: account
                ) != nil else {
                    continue
                }

                trackedMetadataFileNames.insert(uploadResource.fileName)
                skipAssetLocalIdentifiers.insert(asset.localIdentifier)
                lastQueuedDate = creationDate
                remaining -= 1
                madeProgress = true
            }
        }

        if let lastQueuedDate {
            await database.updateAccountPropertyAsync(\.autoUploadSinceDate, value: lastQueuedDate, account: account.account)
        }

        return madeProgress
    }

    /// Returns the next oldest unique asset across already sorted PhotoKit fetch results.
    /// Only one candidate per selected collection is retained, keeping discovery memory bounded.
    private func nextAsset(from fetchResults: [PHFetchResult<PHAsset>], indexes: inout [Int], yieldedIdentifiers: inout Set<String>) -> PHAsset? {
        var selectedResultIndex: Int?
        var selectedAsset: PHAsset?

        for resultIndex in fetchResults.indices {
            let result = fetchResults[resultIndex]

            while indexes[resultIndex] < result.count {
                let candidate = result.object(at: indexes[resultIndex])

                if yieldedIdentifiers.contains(candidate.localIdentifier) {
                    indexes[resultIndex] += 1
                    continue
                }

                if let selectedAsset,
                   (candidate.creationDate ?? .distantPast) >= (selectedAsset.creationDate ?? .distantPast) {
                    break
                }

                selectedResultIndex = resultIndex
                selectedAsset = candidate
                break
            }
        }

        guard let selectedResultIndex, let selectedAsset else {
            return nil
        }

        indexes[selectedResultIndex] += 1
        yieldedIdentifiers.insert(selectedAsset.localIdentifier)
        return selectedAsset
    }

    /// Creates and stores the transfer metadata that connects a Photos resource to its server path.
    /// The record remains marked as pending until a PhotoKit upload job receives its identifier.
    private func createPendingMetadata(asset: PHAsset, resource: PHAssetResource, fileName: String, classFile: String, livePhotoFile: String, account: tableAccount) async -> tableMetadata? {
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
        metadata.classFile = classFile
        metadata.livePhotoFile = livePhotoFile
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

        logDebug("Created pending metadata for \(fileName), account: \(account.account), asset: \(asset.localIdentifier)")

        return metadata
    }

    /// Selects the full-size primary resource for an image or video asset when available.
    /// Falls back to the standard photo or video resource and rejects unsupported media types.
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

    /// Selects the motion component of a Live Photo, preferring its full-size representation.
    /// Returns `nil` when the asset does not expose a paired video resource.
    private func pairedVideoResource(for asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)

        return resources.first {
            $0.type == .fullSizePairedVideo
        } ?? resources.first {
            $0.type == .pairedVideo
        }
    }

    /// Resolves the explicitly selected albums or, when none are configured, the Camera Roll.
    /// An unavailable explicit selection returns no collections to avoid uploading unintended assets.
    private func autoUploadCollections(for account: tableAccount) -> [PHAssetCollection] {
        let albumIds = NCPreferences().getAutoUploadAlbumIds(account: account.account)

        if !albumIds.isEmpty {
            let result = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: Array(albumIds), options: nil)
            var collections: [PHAssetCollection] = []

            result.enumerateObjects { collection, _, _ in
                collections.append(collection)
            }

            if collections.isEmpty {
                logInfo("Background upload skipped because the selected albums are no longer available")
            }

            return collections
        }

        let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)

        guard let cameraRoll = result.firstObject else {
            return []
        }

        return [cameraRoll]
    }
}
