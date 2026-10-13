// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    /// Finds eligible assets and creates up to `limit` pending metadata records for their resources.
    /// Confirmed transfers advance the incremental date; unfinished resources keep it from moving past them.
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

        let discoveryStartDate = account.autoUploadSinceDate

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
        guard let activeMetadatas = await database.getMetadatasAsync(predicate: NSPredicate(
            format: "account == %@ AND autoUploadServerUrlBase == %@ AND status IN %@",
            account.account, autoUploadServerUrlBase, global.metadataStatusUploadingAllMode
        ), limit: nil) else { return false }
        let activeAssets = Dictionary(grouping: activeMetadatas, by: \.assetLocalIdentifier)
        var trackedMetadataFileNames = Set(activeMetadatas.map(\.fileNameView))

        var remaining = limit
        var madeProgress = false
        var lastUploadedDate: Date?
        var canAdvanceSinceDate = true

        // PhotoKit already sorts every result; merge them lazily and stop as soon as the job slots are full.
        discoveryLoop: while remaining > 0,
              let asset = nextAsset(from: fetchResults, indexes: &fetchIndexes, yieldedIdentifiers: &yieldedAssetIdentifiers) {
            guard let current = database.getTableAccount(account: account.account),
                  current.autoUploadStart,
                  current.autoUploadSessionIdentifier == account.autoUploadSessionIdentifier else { break }

            let isLivePhotoAsset = asset.mediaSubtypes.contains(.photoLive)
            let isLivePhoto = isLivePhotoAsset && livePhotoEnabled

            let history: [NCAutoUploadResource]
            do {
                history = try await NCLocalDatabase.shared.autoUploadResources(
                    account: account.account,
                    serverUrlBase: autoUploadServerUrlBase,
                    assetLocalIdentifier: asset.localIdentifier,
                    sessionIdentifier: account.autoUploadForceReupload ? account.autoUploadSessionIdentifier : nil
                )
            } catch {
                logError("Unable to read background upload history: \(error)")
                break
            }
            let queued = activeAssets[asset.localIdentifier] ?? []
            let queuedClasses = Set(queued.map(\.classFile))
            let primaryClassFile = asset.mediaType == .video ? NKTypeClassFile.video.rawValue : NKTypeClassFile.image.rawValue
            let requiredClasses = isLivePhoto ? [primaryClassFile, NKTypeClassFile.video.rawValue] : [primaryClassFile]
            let uploadedClasses = Set(history.filter(\.uploaded).map(\.classFile))
            if requiredClasses.allSatisfy({ uploadedClasses.contains($0) }) {
                if canAdvanceSinceDate { lastUploadedDate = asset.creationDate ?? lastUploadedDate }
                continue
            }

            // Check capacity before generating a name that may advance the incremental counter.
            guard requiredClasses.filter({ !uploadedClasses.contains($0) && !queuedClasses.contains($0) }).count <= remaining else { break }

            guard let primaryResource = primaryUploadResource(for: asset),
                  let originalFileName = primaryResource.filename,
                  !originalFileName.isEmpty else {
                logError("Upload resource not found for asset \(asset.localIdentifier)")
                canAdvanceSinceDate = false
                continue
            }

            let creationDate = asset.creationDate ?? Date()
            let queuedPrimary = queued.first { $0.classFile == primaryClassFile }
            let primaryFileName = queuedPrimary?.fileNameView
                ?? queued.first { $0.isLivePhotoVideo }?.livePhotoFile
                ?? history.first { $0.classFile == primaryClassFile }?.fileName
                ?? utilityFileSystem.createFileName(originalFileName, fileDate: creationDate, fileType: asset.mediaType)
            let videoFileName = queued.first { $0.classFile == NKTypeClassFile.video.rawValue }?.fileNameView
                ?? queuedPrimary.flatMap { $0.isLivePhotoImage ? $0.livePhotoFile : nil }
                ?? history.first { $0.classFile == NKTypeClassFile.video.rawValue }?.fileName
                ?? (primaryFileName as NSString).deletingPathExtension + ".mov"
            var uploadResources: [(resource: PHAssetResource, fileName: String, classFile: String, livePhotoFile: String)]

            if isLivePhoto {
                guard let pairedVideoResource = pairedVideoResource(for: asset) else {
                    logError("Paired video resource not found for Live Photo asset \(asset.localIdentifier)")
                    canAdvanceSinceDate = false
                    continue
                }

                uploadResources = [
                    (primaryResource, primaryFileName, NKTypeClassFile.image.rawValue, videoFileName),
                    (pairedVideoResource, videoFileName, NKTypeClassFile.video.rawValue, primaryFileName)
                ]
            } else {
                uploadResources = [
                    (primaryResource, primaryFileName, primaryClassFile, "")
                ]
            }

            // Completed components are independent from the server metadata refreshed by sync.
            canAdvanceSinceDate = false
            let resourcesToUpload = uploadResources.filter {
                !uploadedClasses.contains($0.classFile) && !queuedClasses.contains($0.classFile) && !trackedMetadataFileNames.contains($0.fileName)
            }

            // Each resource selects its own pipeline: PhotoKit up to 100 MB, host-app chunks above it.
            for uploadResource in resourcesToUpload {
                let chunkSize = Int64(uploadResource.resource.dataSize ?? 0) > Int64(global.chunkSize) ? global.chunkSize : nil

                let inserted = await createPendingMetadata(
                    asset: asset,
                    resource: uploadResource.resource,
                    fileName: uploadResource.fileName,
                    classFile: uploadResource.classFile,
                    livePhotoFile: uploadResource.livePhotoFile,
                    legacyChunkSize: chunkSize,
                    account: account
                )

                guard inserted else { break discoveryLoop }
                trackedMetadataFileNames.insert(uploadResource.fileName)
                remaining -= 1
                madeProgress = true
            }
        }

        if let lastUploadedDate {
            await database.updateAutoUploadSinceDateIfEnabledAsync(lastUploadedDate, account: account.account, sessionIdentifier: account.autoUploadSessionIdentifier)
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

    /// Creates the transfer metadata that connects a Photos resource to its server path.
    /// Large resources remain ordinary metadata for the host app; all others wait for a PhotoKit job.
    private func createPendingMetadata(asset: PHAsset, resource: PHAssetResource, fileName: String, classFile: String, livePhotoFile: String, legacyChunkSize: Int?, account: tableAccount) async -> Bool {
        let session = NCSession.Session(account: account.account, urlBase: account.urlBase, user: account.user, userId: account.userId)
        let autoUploadServerUrlBase = await database.getAccountAutoUploadServerUrlBaseAsync(account: account.account, urlBase: account.urlBase, userId: account.userId)

        let serverUrl: String
        let wifiOnly = asset.mediaType == .image ? account.autoUploadWWAnPhoto : account.autoUploadWWAnVideo

        if account.autoUploadCreateSubfolder {
            serverUrl = utilityFileSystem.createGranularityPath(asset: asset, serverUrlBase: autoUploadServerUrlBase, granularity: account.autoUploadSubfolderGranularity)
        } else {
            serverUrl = autoUploadServerUrlBase
        }

        let metadata = await NCManageDatabaseCreateMetadata().createMetadataAsync(fileName: fileName, ocId: UUID().uuidString, serverUrl: serverUrl, session: session, sceneIdentifier: nil)

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
        metadata.chunk = legacyChunkSize ?? 0
        metadata.backgroundUploadJobIdentifier = legacyChunkSize == nil ? "pending" : ""

        do {
            guard try await NCLocalDatabase.shared.recordAutoUploadTransfer(metadata, sessionIdentifier: account.autoUploadSessionIdentifier) else { return false }
        } catch {
            logError("Unable to register background upload transfer: \(error)")
            return false
        }

        await database.addAutoUploadMetadatasAsync([metadata], account: account.account, sessionIdentifier: account.autoUploadSessionIdentifier)
        guard await database.getMetadataAsync(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) != nil else { return false }

        if legacyChunkSize == nil {
            logInfo("Created pending metadata for \(fileName), account: \(account.account), asset: \(asset.localIdentifier)")
        } else {
            logInfo("Deferred large resource to the host app chunked upload pipeline: \(fileName), size: \(metadata.size)")
        }
        return true
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
