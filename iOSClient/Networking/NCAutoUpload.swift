// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import CoreLocation
import NextcloudKit
import Photos
import OrderedCollections

class NCAutoUpload: NSObject {
    static let shared = NCAutoUpload()

    private let database = NCManageDatabase.shared
    private let global = NCGlobal.shared
    private let networking = NCNetworking.shared
    private var endForAssetToUpload: Bool = false

    func initAutoUpload(controller: NCMainTabBarController? = nil) async -> Int {
        guard self.networking.isOnline else {
            return 0
        }
        var counter = 0

        let tblAccounts = await NCManageDatabase.shared.getTableAccountsAsync(predicate: NSPredicate(format: "autoUploadStart == true AND autoUploadOnlyNew == true"))
        for tblAccount in tblAccounts {
            let albumIds = NCPreferences().getAutoUploadAlbumIds(account: tblAccount.account)
            let assetCollections = PHAssetCollection.allAlbums.filter({albumIds.contains($0.localIdentifier)})
            let result = await getCameraRollAssets(controller: nil, assetCollections: assetCollections, tblAccount: tableAccount(value: tblAccount))
            if let assets = result.assets, !assets.isEmpty, let fileNames = result.fileNames {
                let item = await uploadAssets(controller: nil, tblAccount: tblAccount, assets: assets, fileNames: fileNames)
                counter += item
            }
        }

        return counter
    }

    func startManualAutoUploadForAlbums(controller: NCMainTabBarController?,
                                        model: NCAutoUploadModel,
                                        assetCollections: [PHAssetCollection],
                                        account: String) async {
        defer {
            NCContentPresenter().dismiss(after: 1)
        }

        guard let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", account)) else {
            return
        }

        if !tblAccount.autoUploadOnlyNew {
            // Automatic move to auto upload new
            await self.database.updateAccountPropertyAsync(\.autoUploadOnlyNew, value: true, account: tblAccount.account)

            await MainActor.run {
                let image = UIImage(systemName: "photo.on.rectangle.angled")?.image(color: .white, size: 20)
                NCContentPresenter().noteTop(text: NSLocalizedString("_creating_db_photo_progress_", comment: ""), image: image, color: .lightGray, delay: .infinity, priority: .max)

                model.onViewAppear()
            }
        }

        let result = await getCameraRollAssets(controller: controller, assetCollections: assetCollections, tblAccount: tblAccount)

        guard let assets = result.assets,
              !assets.isEmpty,
              let fileNames = result.fileNames else {
            return
        }

        let num = await uploadAssets(controller: controller, tblAccount: tblAccount, assets: assets, fileNames: fileNames)
        nkLog(debug: "Automatic upload \(num) upload")
    }

    private func uploadAssets(controller: NCMainTabBarController?,
                              tblAccount: tableAccount,
                              assets: [PHAsset],
                              fileNames: [String]) async -> Int {
        let session = NCSession.shared.getSession(account: tblAccount.account)
        let autoUploadServerUrlBase = await self.database.getAccountAutoUploadServerUrlBaseAsync(account: tblAccount.account, urlBase: tblAccount.urlBase, userId: tblAccount.userId)
        var metadatas: [tableMetadata] = []
        let formatCompatibility = NCPreferences().formatCompatibility
        let keychainLivePhoto = NCPreferences().livePhoto
        let fileSystem = NCUtilityFileSystem()
        let skipFileNames = await self.database.fetchSkipFileNamesAsync(account: tblAccount.account,
                                                                        autoUploadServerUrlBase: autoUploadServerUrlBase)

        nkLog(debug: "Automatic upload, new \(assets.count) assets found")

        for (index, asset) in assets.enumerated() {
            let fileName = fileNames[index]

            // Convert HEIC if compatibility mode is on
            let fileNameCompatible = formatCompatibility && (fileName as NSString).pathExtension.lowercased() == "heic" ? (fileName as NSString).deletingPathExtension + ".jpg" : fileName

            if skipFileNames.contains(fileNameCompatible) || skipFileNames.contains(fileName) {
                continue
            }

            let mediaType = asset.mediaType
            let isLivePhoto = asset.mediaSubtypes.contains(.photoLive) && keychainLivePhoto
            let serverUrl = tblAccount.autoUploadCreateSubfolder ? fileSystem.createGranularityPath(asset: asset, serverUrlBase: autoUploadServerUrlBase) : autoUploadServerUrlBase
            let onWWAN = (mediaType == .image && tblAccount.autoUploadWWAnPhoto) || (mediaType == .video && tblAccount.autoUploadWWAnVideo)
            let uploadSession = onWWAN ? self.networking.sessionUploadBackgroundWWan : self.networking.sessionUploadBackground

            let metadata = await self.database.createMetadataAsync(fileName: fileName,
                                                                   ocId: UUID().uuidString,
                                                                   serverUrl: serverUrl,
                                                                   session: session,
                                                                   sceneIdentifier: controller?.sceneIdentifier)

            if isLivePhoto {
                metadata.livePhotoFile = (metadata.fileName as NSString).deletingPathExtension + ".mov"
            }

            metadata.assetLocalIdentifier = asset.localIdentifier
            metadata.autoUploadServerUrlBase = autoUploadServerUrlBase
            metadata.session = uploadSession
            metadata.sessionSelector = NCGlobal.shared.selectorUploadAutoUpload
            metadata.status = NCGlobal.shared.metadataStatusWaitUpload
            metadata.sessionDate = Date()

            metadata.classFile = {
                switch mediaType {
                case .video: return NKTypeClassFile.video.rawValue
                case .image: return NKTypeClassFile.image.rawValue
                default: return ""
                }
            }()

            metadata.iconName = {
                switch mediaType {
                case .video: return NKTypeIconFile.video.rawValue
                case .image: return NKTypeIconFile.image.rawValue
                default: return ""
                }
            }()

            metadata.typeIdentifier = {
                switch mediaType {
                case .video: return "com.apple.quicktime-movie"
                case .image: return "public.image"
                default: return ""
                }
            }()

            metadatas.append(metadata)
        }

        // Set last date in autoUploadOnlyNewSinceDate
        if let metadata = metadatas.last {
            let date = metadata.creationDate as Date
            await self.database.updateAccountPropertyAsync(\.autoUploadOnlyNewSinceDate, value: date, account: session.account)
        }

        if !metadatas.isEmpty {
            let metadatasFolder = await self.database.createMetadatasFolderAsync(assets: assets, useSubFolder: tblAccount.autoUploadCreateSubfolder, session: session)
            await self.database.addMetadatasAsync(metadatasFolder + metadatas)
        }

        return metadatas.count
    }

    // MARK: -

    func getCameraRollAssets(controller: NCMainTabBarController?,
                             assetCollections: [PHAssetCollection] = [],
                             tblAccount: tableAccount) async -> (assets: [PHAsset]?, fileNames: [String]?) {
        let hasPermission = await withCheckedContinuation { continuation in
            NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { granted in
                continuation.resume(returning: granted)
            }
        }
        guard hasPermission else {
            return (nil, nil)
        }
        let autoUploadServerUrlBase = await self.database.getAccountAutoUploadServerUrlBaseAsync(account: tblAccount.account, urlBase: tblAccount.urlBase, userId: tblAccount.userId)
        var mediaPredicates: [NSPredicate] = []
        var datePredicates: [NSPredicate] = []
        let fetchOptions = PHFetchOptions()

        if tblAccount.autoUploadImage {
            mediaPredicates.append(NSPredicate(format: "mediaType == %i", PHAssetMediaType.image.rawValue))
        }

        if tblAccount.autoUploadVideo {
            mediaPredicates.append(NSPredicate(format: "mediaType == %i", PHAssetMediaType.video.rawValue))
        }

        if tblAccount.autoUploadOnlyNew {
            datePredicates.append(NSPredicate(format: "creationDate > %@", tblAccount.autoUploadOnlyNewSinceDate as NSDate))
        } else if let lastDate = await self.database.fetchLastAutoUploadedDateAsync(account: tblAccount.account, autoUploadServerUrlBase: autoUploadServerUrlBase) {
            datePredicates.append(NSPredicate(format: "creationDate > %@", lastDate as NSDate))
        }

        fetchOptions.predicate = {
            switch (mediaPredicates.isEmpty, datePredicates.isEmpty) {
            case (false, false):
                return NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSCompoundPredicate(orPredicateWithSubpredicates: mediaPredicates),
                    NSCompoundPredicate(andPredicateWithSubpredicates: datePredicates)
                ])
            case (false, true):
                return NSCompoundPredicate(orPredicateWithSubpredicates: mediaPredicates)
            case (true, false):
                return NSCompoundPredicate(andPredicateWithSubpredicates: datePredicates)
            default:
                return nil
            }
        }()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let collections: [PHAssetCollection] = {
            if assetCollections.isEmpty {
                let fetched = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
                return fetched.firstObject.map { [$0] } ?? []
            } else {
                return assetCollections
            }
        }()

        guard !collections.isEmpty else {
             return (nil, nil)
        }

        let allAssets = collections.flatMap { collection in
            let result = PHAsset.fetchAssets(in: collection, options: fetchOptions)
            return result.objects(at: IndexSet(0..<result.count))
        }
        let newAssets = OrderedSet(allAssets)
        let fileNames = newAssets.compactMap { asset -> String? in
            let date = asset.creationDate ?? Date()
            return NCUtilityFileSystem().createFileName(asset.originalFilename, fileDate: date, fileType: asset.mediaType)
        }

        return(Array(newAssets), fileNames)
    }
}
