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
    private let hud = NCHud()

    // MARK: -

    func initAutoUpload(controller: NCMainTabBarController?, account: String, completion: @escaping (_ num: Int) -> Void) {
        DispatchQueue.global().async {
            guard NCNetworking.shared.isOnline,
                  let tableAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)),
                  tableAccount.autoUploadStart else {
                return completion(0)
            }

            NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { [self] hasPermission in
                guard hasPermission else {
                    self.database.setAccountAutoUploadProperty("autoUpload", state: false)
                    return completion(0)
                }
                let albumIds = NCKeychain().getAutoUploadAlbumIds(account: account)
                let selectedAlbums = PHAssetCollection.allAlbums.filter({albumIds.contains($0.localIdentifier)})

                self.uploadAssets(controller: controller, assetCollections: selectedAlbums, log: "Init Auto Upload", account: account) { num in
                    completion(num)
                }
            }
        }
    }

    func initAutoUpload(controller: NCMainTabBarController? = nil, account: String) async -> Int {
        await withUnsafeContinuation({ continuation in
            initAutoUpload(controller: controller, account: account) { num in
                continuation.resume(returning: num)
            }
        })
    }

    func autoUploadSelectedAlbums(controller: NCMainTabBarController?, assetCollections: [PHAssetCollection], log: String, account: String) {
        hud.initHudRing(view: controller?.view, text: NSLocalizedString("_creating_db_photo_progress", comment: ""))
        NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
            guard hasPermission else { return }
            DispatchQueue.global().async {
                self.uploadAssets(controller: controller, assetCollections: assetCollections, log: log, account: account) { _ in
                    self.hud.dismiss()
                }
            }
        }
    }

    private func uploadAssets(controller: NCMainTabBarController?, assetCollections: [PHAssetCollection] = [], log: String, account: String, completion: @escaping (_ num: Int) -> Void) {
        guard let tblAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)) else {
            return completion(0)
        }
        let session = NCSession.shared.getSession(account: account)
        let autoUploadServerUrl = self.database.getAccountAutoUploadPath(session: session)
        var metadatas: [tableMetadata] = []

        self.getCameraRollAssets(controller: controller, assetCollections: assetCollections, account: account, autoUploadServerUrl: autoUploadServerUrl) { assets, fileNames in
            guard let assets,
                  let fileNames,
                  !assets.isEmpty,
                  assets.count == fileNames.count
            else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Automatic upload, no new assets found [" + log + "]")
                return completion(0)
            }
            var index: Int = 0
            var lastUploadDate = Date()

            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Automatic upload, new \(assets.count) assets found [" + log + "]")

            NCNetworking.shared.createFolder(assets: assets, useSubFolder: tblAccount.autoUploadCreateSubfolder, session: session)

            self.hud.setText(text: NSLocalizedString("_creating_db_photo_progress", comment: ""))
            self.hud.progress(0.0)
            self.endForAssetToUpload = false

            for asset in assets {
                var isLivePhoto = false
                var uploadSession: String = ""
                let assetMediaType = asset.mediaType
                var serverUrl: String = ""
                let fileName = fileNames[index]

                if tblAccount.autoUploadCreateSubfolder {
                    serverUrl = NCUtilityFileSystem().createGranularityPath(asset: asset, serverUrl: autoUploadServerUrl)
                } else {
                    serverUrl = autoUploadServerUrl
                }

                if asset.mediaSubtypes.contains(.photoLive), NCKeychain().livePhoto {
                    isLivePhoto = true
                }

                if assetMediaType == PHAssetMediaType.image && tblAccount.autoUploadWWAnPhoto == false {
                    uploadSession = NCNetworking.shared.sessionUploadBackground
                } else if assetMediaType == PHAssetMediaType.video && tblAccount.autoUploadWWAnVideo == false {
                    uploadSession = NCNetworking.shared.sessionUploadBackground
                } else if assetMediaType == PHAssetMediaType.image && tblAccount.autoUploadWWAnPhoto {
                    uploadSession = NCNetworking.shared.sessionUploadBackgroundWWan
                } else if assetMediaType == PHAssetMediaType.video && tblAccount.autoUploadWWAnVideo {
                    uploadSession = NCNetworking.shared.sessionUploadBackgroundWWan
                } else {
                    uploadSession = NCNetworking.shared.sessionUploadBackground
                }

                // MOST COMPATIBLE --> HEIC --> JPG
                var fileNameCompatible = fileName
                let ext = (fileNameCompatible as NSString).pathExtension.lowercased()

                if ext == "heic", NCKeychain().formatCompatibility {
                    fileNameCompatible = (fileNameCompatible as NSString).deletingPathExtension + ".jpg"
                }

                index += 1
                self.hud.progress(num: Float(index), total: Float(assets.count))

                // Verify if already exists
                if self.database.shouldSkipAutoUploadTransfer(account: session.account, serverUrl: serverUrl, autoUploadServerUrl: autoUploadServerUrl, fileName: fileNameCompatible) {
                    continue
                }

                let metadata = self.database.createMetadata(fileName: fileName,
                                                            fileNameView: fileName,
                                                            ocId: NSUUID().uuidString,
                                                            serverUrl: serverUrl,
                                                            url: "",
                                                            contentType: "",
                                                            session: session,
                                                            sceneIdentifier: controller?.sceneIdentifier)

                if isLivePhoto {
                    metadata.livePhotoFile = (metadata.fileName as NSString).deletingPathExtension + ".mov"
                }
                metadata.assetLocalIdentifier = asset.localIdentifier
                metadata.session = uploadSession
                metadata.sessionSelector = NCGlobal.shared.selectorUploadAutoUpload
                metadata.status = NCGlobal.shared.metadataStatusWaitUpload
                metadata.sessionDate = Date()
                if assetMediaType == PHAssetMediaType.video {
                    metadata.classFile = NKCommon.TypeClassFile.video.rawValue
                } else if assetMediaType == PHAssetMediaType.image {
                    metadata.classFile = NKCommon.TypeClassFile.image.rawValue
                }

                let metadataCreationDate = metadata.creationDate as Date

                if lastUploadDate < metadataCreationDate {
                    lastUploadDate = metadataCreationDate
                }
                /*
                 if result.autoUploadOnlyNew {
                     self.database.setAutoUploadOnlyNewSinceDate(account: metadata.account, date: metadata.creationDate as Date)
                 }
                 */

                metadatas.append(metadata)
            }

            self.endForAssetToUpload = true
            self.database.addMetadatas(metadatas, sync: false)
        }
    }

    // MARK: -

    func processAssets(_ assetCollection: PHAssetCollection, _ fetchOptions: PHFetchOptions, _ tableAccount: tableAccount, _ account: String) -> [PHAsset] {
        let assets: PHFetchResult<PHAsset> = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
        var assetResult: [PHAsset] = []

        assets.enumerateObjects { asset, _, _ in
            assetResult.append(asset)
        }

        return assetResult
    }

    private func getCameraRollAssets(controller: NCMainTabBarController?, assetCollections: [PHAssetCollection] = [], account: String, autoUploadServerUrl: String, completion: @escaping (_ assets: [PHAsset]?, _ fileNames: [String]?) -> Void) {
        NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { [self] hasPermission in
            guard hasPermission,
                  let tblAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)) else {
                return completion(nil, nil)
            }
            var newAssets: OrderedSet<PHAsset> = []
            let fetchOptions = PHFetchOptions()
            var mediaPredicates: [NSPredicate] = []
            var datePredicates: [NSPredicate] = []

            if tblAccount.autoUploadImage {
                mediaPredicates.append(NSPredicate(format: "mediaType == %i", PHAssetMediaType.image.rawValue))
            }

            if tblAccount.autoUploadVideo {
                mediaPredicates.append(NSPredicate(format: "mediaType == %i", PHAssetMediaType.video.rawValue))
            }

            if tblAccount.autoUploadOnlyNew {
                datePredicates.append(NSPredicate(format: "creationDate > %@", tblAccount.autoUploadOnlyNewSinceDate as NSDate))
            } else if let autoUploadLastUploadedDate = self.database.fetchLastAutoUploadedDate(account: account, autoUploadServerUrl: autoUploadServerUrl) {
                datePredicates.append(NSPredicate(format: "creationDate > %@", autoUploadLastUploadedDate as NSDate))
            }

            // Combine media type predicates with OR (if any exist)
            let finalMediaPredicate = mediaPredicates.isEmpty ? nil : NSCompoundPredicate(orPredicateWithSubpredicates: mediaPredicates)
            let finalDatePredicate = datePredicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: datePredicates)

            var finalPredicate: NSPredicate?

            if let finalMediaPredicate, let finalDatePredicate {
                finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [finalMediaPredicate, finalDatePredicate])
            } else if let finalMediaPredicate {
                finalPredicate = finalMediaPredicate
            } else if let finalDatePredicate {
                finalPredicate = finalDatePredicate
            }

            fetchOptions.predicate = finalPredicate

            // Add assets into a set to avoid duplicate photos (same photo in multiple albums)
            if assetCollections.isEmpty {
                let assetCollection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
                guard let assetCollection = assetCollection.firstObject
                else {
                    return completion(nil, nil)
                }
                let allAssets = processAssets(assetCollection, fetchOptions, tblAccount, account)
                print(allAssets)
                newAssets = OrderedSet(allAssets)
                print(newAssets)
            } else {
                var allAssets: [PHAsset] = []
                for assetCollection in assetCollections {
                    allAssets += processAssets(assetCollection, fetchOptions, tblAccount, account)
                }
                newAssets = OrderedSet(allAssets)
            }

            DispatchQueue.main.async {
                var fileNames: [String] = []
                for asset in newAssets {
                    let assetDate = asset.creationDate ?? Date()
                    let assetMediaType = asset.mediaType
                    let fileName = NCUtilityFileSystem().createFileName(asset.originalFilename as String, fileDate: assetDate, fileType: assetMediaType)
                    fileNames.append(fileName)
                }
                DispatchQueue.global().async {
                    completion(Array(newAssets), fileNames)
                }
            }
        }
    }
}
