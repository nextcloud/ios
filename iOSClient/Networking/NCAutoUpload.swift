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
    private var endForAssetToUpload: Bool = false

    func initAutoUpload(controller: NCMainTabBarController?, account: String, completion: @escaping (_ num: Int) -> Void) {
        guard NCNetworking.shared.isOnline,
              let tblAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)),
              tblAccount.autoUploadStart
        else {
            return completion(0)
        }
        let albumIds = NCKeychain().getAutoUploadAlbumIds(account: account)
        let selectedAlbums = PHAssetCollection.allAlbums.filter({albumIds.contains($0.localIdentifier)})

        self.getCameraRollAssets(controller: controller, assetCollections: selectedAlbums, tblAccount: tableAccount(value: tblAccount)) { assets, fileNames in
            guard let assets,
                  !assets.isEmpty,
                  let fileNames else {
                return completion(0)
            }
            self.uploadAssets(controller: controller, tblAccount: tableAccount(value: tblAccount), assets: assets, fileNames: fileNames) { num in
                completion(num)
            }
        }
    }

    func autoUploadSelectedAlbums(controller: NCMainTabBarController?, assetCollections: [PHAssetCollection], log: String, account: String) {
        guard let tblAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", account))
        else {
            return
        }
        self.getCameraRollAssets(controller: controller, assetCollections: assetCollections, tblAccount: tableAccount(value: tblAccount)) { assets, fileNames in
            guard let assets,
                  !assets.isEmpty,
                  let fileNames else {
                return
            }
            self.uploadAssets(controller: controller, tblAccount: tblAccount, assets: assets, fileNames: fileNames)
        }
    }

    private func uploadAssets(controller: NCMainTabBarController?, tblAccount: tableAccount, assets: [PHAsset], fileNames: [String], completion: @escaping (_ num: Int) -> Void = { _ in }) {
        let session = NCSession.shared.getSession(account: tblAccount.account)
        let autoUploadServerUrlBase = self.database.getAccountAutoUploadServerUrlBase(account: tblAccount.account, urlBase: tblAccount.urlBase, userId: tblAccount.userId)
        var metadatas: [tableMetadata] = []
        let formatCompatibility = NCKeychain().formatCompatibility
        let keychainLivePhoto = NCKeychain().livePhoto
        let fileSystem = NCUtilityFileSystem()
        let skipFileNames = self.database.fetchSkipFileNames(account: tblAccount.account, autoUploadServerUrlBase: autoUploadServerUrlBase)

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Automatic upload, new \(assets.count) assets found")

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
            let uploadSession = onWWAN ? NCNetworking.shared.sessionUploadBackgroundWWan : NCNetworking.shared.sessionUploadBackground

            let metadata = self.database.createMetadata(
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
            self.database.createMetadatasFolder(assets: assets, useSubFolder: tblAccount.autoUploadCreateSubfolder, session: session) { metadatasFolder in
                self.database.addMetadatas(metadatasFolder + metadatas, sync: false)
                completion(metadatas.count)
            }
        } else {
            completion(metadatas.count)
        }
    }

    // MARK: -

    private func getCameraRollAssets(controller: NCMainTabBarController?, assetCollections: [PHAssetCollection] = [], tblAccount: tableAccount, completion: @escaping (_ assets: [PHAsset]?, _ fileNames: [String]?) -> Void) {
        NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { [self] hasPermission in
            guard hasPermission else {
                return completion(nil, nil)
            }
            DispatchQueue.global().async {
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
                    return completion(nil, nil)
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

                completion(Array(newAssets), fileNames)
            }
        }
    }
}
