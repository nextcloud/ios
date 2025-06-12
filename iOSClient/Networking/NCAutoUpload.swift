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

    func initAutoUpload(controller: NCMainTabBarController? = nil, account: String) async -> Int {
        guard self.networking.isOnline,
              let tblAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)),
              tblAccount.autoUploadStart else {
            return 0
        }
        let albumIds = NCKeychain().getAutoUploadAlbumIds(account: account)
        let selectedAlbums = PHAssetCollection.allAlbums.filter({albumIds.contains($0.localIdentifier)})

        let result = await getCameraRollAssets(controller: controller, assetCollections: selectedAlbums, tblAccount: tableAccount(value: tblAccount))

        guard let assets = result.assets,
              !assets.isEmpty,
              let fileNames = result.fileNames else {
            return 0
        }

        let num = await uploadAssets(controller: controller, tblAccount: tableAccount(value: tblAccount), assets: assets, fileNames: fileNames)

        return num
    }

    func autoUploadSelectedAlbums(controller: NCMainTabBarController?, assetCollections: [PHAssetCollection], account: String) async {
        guard let tblAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", account))
        else {
            return
        }

        let result = await getCameraRollAssets(controller: controller, tblAccount: tableAccount(value: tblAccount))

        guard let assets = result.assets,
              !assets.isEmpty,
              let fileNames = result.fileNames else {
            return
        }

        _ = await uploadAssets(controller: controller, tblAccount: tblAccount, assets: assets, fileNames: fileNames)
    }

    private func uploadAssets(controller: NCMainTabBarController?, tblAccount: tableAccount, assets: [PHAsset], fileNames: [String]) async -> Int {
        let session = NCSession.shared.getSession(account: tblAccount.account)
        let autoUploadServerUrlBase = self.database.getAccountAutoUploadServerUrlBase(account: tblAccount.account, urlBase: tblAccount.urlBase, userId: tblAccount.userId)
        var metadatas: [tableMetadata] = []
        let formatCompatibility = NCKeychain().formatCompatibility
        let keychainLivePhoto = NCKeychain().livePhoto
        let fileSystem = NCUtilityFileSystem()
        let skipFileNames = await self.database.fetchSkipFileNames(account: tblAccount.account, autoUploadServerUrlBase: autoUploadServerUrlBase)

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

            let metadata = await self.database.createMetadata(
                fileName: fileName,
                fileNameView: fileName,
                ocId: UUID().uuidString,
                serverUrl: serverUrl,
                url: "",
                contentType: "",
                session: session,
                sceneIdentifier: controller?.sceneIdentifier
            )

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
                case .video: return NKCommon.TypeClassFile.video.rawValue
                case .image: return NKCommon.TypeClassFile.image.rawValue
                default: return ""
                }
            }()

            metadatas.append(metadata)
        }

        /// Set last date in autoUploadOnlyNewSinceDate
        if let metadata = metadatas.last {
            let date = metadata.creationDate as Date
            self.database.updateAccountProperty(\.autoUploadOnlyNewSinceDate, value: date, account: session.account)
        }

        if !metadatas.isEmpty {
            let metadatasFolder = await self.database.createMetadatasFolder(assets: assets, useSubFolder: tblAccount.autoUploadCreateSubfolder, session: session)
            self.database.addMetadatas(metadatasFolder + metadatas, sync: false)
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
        let autoUploadServerUrlBase = self.database.getAccountAutoUploadServerUrlBase(account: tblAccount.account, urlBase: tblAccount.urlBase, userId: tblAccount.userId)
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
        } else if let lastDate = self.database.fetchLastAutoUploadedDate(account: tblAccount.account, autoUploadServerUrlBase: autoUploadServerUrlBase) {
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
