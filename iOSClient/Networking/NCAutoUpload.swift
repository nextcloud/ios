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

            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Automatic upload, new \(assets.count) assets found [" + log + "]")

            NCNetworking.shared.createFolder(assets: assets, useSubFolder: tblAccount.autoUploadCreateSubfolder, session: session)

            self.hud.setText(text: NSLocalizedString("_creating_db_photo_progress", comment: ""))
            self.hud.progress(0.0)
            self.endForAssetToUpload = false

            for (index, asset) in assets.enumerated() {
                let fileName = fileNames[index]
                let mediaType = asset.mediaType
                let isLivePhoto = asset.mediaSubtypes.contains(.photoLive) && NCKeychain().livePhoto
                let serverUrl = tblAccount.autoUploadCreateSubfolder ? NCUtilityFileSystem().createGranularityPath(asset: asset, serverUrl: autoUploadServerUrl) : autoUploadServerUrl
                let onWWAN = (mediaType == .image && tblAccount.autoUploadWWAnPhoto) || (mediaType == .video && tblAccount.autoUploadWWAnVideo)
                let uploadSession = onWWAN ? NCNetworking.shared.sessionUploadBackgroundWWan : NCNetworking.shared.sessionUploadBackground

                // Convert HEIC if compatibility mode is on
                let fileNameCompatible: String = {
                    let ext = (fileName as NSString).pathExtension.lowercased()
                    guard ext == "heic", NCKeychain().formatCompatibility else {
                        return fileName
                    }
                    return ((fileName as NSString).deletingPathExtension + ".jpg")
                }()

                self.hud.progress(num: Float(index + 1), total: Float(assets.count))

                guard !self.database.shouldSkipAutoUploadTransfer(
                    account: session.account,
                    serverUrl: serverUrl,
                    autoUploadServerUrl: autoUploadServerUrl,
                    fileName: fileNameCompatible
                ) else {
                    continue
                }

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

            self.endForAssetToUpload = true
            self.database.addMetadatas(metadatas, sync: false)
        }
    }

    // MARK: -

    private func getCameraRollAssets(controller: NCMainTabBarController?, assetCollections: [PHAssetCollection] = [], account: String, autoUploadServerUrl: String, completion: @escaping (_ assets: [PHAsset]?, _ fileNames: [String]?) -> Void) {
        NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { [self] hasPermission in
            guard hasPermission,
                  let tblAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", account))
            else {
                return completion(nil, nil)
            }
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
            } else if let lastDate = self.database.fetchLastAutoUploadedDate(account: account, autoUploadServerUrl: autoUploadServerUrl) {
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

            DispatchQueue.main.async {
                let fileNames = newAssets.compactMap { asset -> String? in
                    let date = asset.creationDate ?? Date()
                    return NCUtilityFileSystem().createFileName(asset.originalFilename, fileDate: date, fileType: asset.mediaType)
                }
                DispatchQueue.global().async {
                    completion(Array(newAssets), fileNames)
                }
            }
        }
    }
}
