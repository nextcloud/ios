//
//  NCAutoUpload.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/01/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import CoreLocation
import NextcloudKit
import Photos
import JGProgressHUD

class NCAutoUpload: NSObject {
    static let shared = NCAutoUpload()

    private var endForAssetToUpload: Bool = false
    private var applicationState = UIApplication.shared.applicationState
    private let hud = JGProgressHUD()

    // MARK: -

    func initAutoUpload(controller: UIViewController?, account: String, completion: @escaping (_ num: Int) -> Void) {
        guard NCNetworking.shared.isOnline,
              let tableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", account)),
              tableAccount.autoUpload else {
            return completion(0)
        }
        applicationState = UIApplication.shared.applicationState

        NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
            guard hasPermission else {
                NCManageDatabase.shared.setAccountAutoUploadProperty("autoUpload", state: false)
                return completion(0)
            }
            DispatchQueue.global(qos: .userInteractive).async {
                self.uploadAssetsNewAndFull(controller: controller, selector: NCGlobal.shared.selectorUploadAutoUpload, log: "Init Auto Upload", account: account) { num in
                    completion(num)
                }
            }
        }
    }

    func initAutoUpload(controller: UIViewController? = nil, account: String) async -> Int {
        await withUnsafeContinuation({ continuation in
            initAutoUpload(controller: controller, account: account) { num in
                continuation.resume(returning: num)
            }
        })
    }

    func autoUploadFullPhotos(controller: UIViewController?, log: String, account: String) {
        applicationState = UIApplication.shared.applicationState
        hud.indicatorView = JGProgressHUDRingIndicatorView()
        if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
            indicatorView.ringWidth = 1.5
            indicatorView.ringColor = NCBrandColor.shared.getElement(account: account)
        }
        hud.tapOnHUDViewBlock = { _ in

        }
        if let controller {
            hud.show(in: controller.view)
        }

        NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
            guard hasPermission else { return }
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_create_full_upload_")
            NCContentPresenter().showWarning(error: error, priority: .max)
            DispatchQueue.global(qos: .userInteractive).async {
                self.uploadAssetsNewAndFull(controller: controller, selector: NCGlobal.shared.selectorUploadAutoUploadAll, log: log, account: account) { _ in
                    self.hud.dismiss()
                }
            }
        }
    }

    private func uploadAssetsNewAndFull(controller: UIViewController?, selector: String, log: String, account: String, completion: @escaping (_ num: Int) -> Void) {
        guard let tableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", account)) else {
            return completion(0)
        }
        let session = NCSession.shared.getSession(account: account)
        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(session: session)
        var metadatas: [tableMetadata] = []

        self.getCameraRollAssets(controller: controller, selector: selector, alignPhotoLibrary: false, account: account) { assets in
            guard let assets, !assets.isEmpty else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Automatic upload, no new assets found [" + log + "]")
                return completion(0)
            }

            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Automatic upload, new \(assets.count) assets found [" + log + "]")
            // Create the folder for auto upload & if request the subfolders
            if !NCNetworking.shared.createFolder(assets: assets, useSubFolder: tableAccount.autoUploadCreateSubfolder, withPush: false, session: session) {
                if selector == NCGlobal.shared.selectorUploadAutoUploadAll {
                    let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_error_createsubfolders_upload_")
                    NCContentPresenter().showError(error: error, priority: .max)
                }
                return completion(0)
            }

            self.endForAssetToUpload = false

            for asset in assets {
                var isLivePhoto = false
                var uploadSession: String = ""
                let assetDate = asset.creationDate ?? Date()
                let assetMediaType = asset.mediaType
                var serverUrl: String = ""
                let fileName = NCUtilityFileSystem().createFileName(asset.originalFilename as String, fileDate: assetDate, fileType: assetMediaType)

                if tableAccount.autoUploadCreateSubfolder {
                    serverUrl = NCUtilityFileSystem().createGranularityPath(asset: asset, serverUrl: autoUploadPath)
                } else {
                    serverUrl = autoUploadPath
                }

                if asset.mediaSubtypes.contains(.photoLive), NCKeychain().livePhoto {
                    isLivePhoto = true
                }

                if selector == NCGlobal.shared.selectorUploadAutoUploadAll {
                    uploadSession = NCNetworking.shared.sessionUpload
                } else {
                    if assetMediaType == PHAssetMediaType.image && tableAccount.autoUploadWWAnPhoto == false {
                        uploadSession = NCNetworking.shared.sessionUploadBackground
                    } else if assetMediaType == PHAssetMediaType.video && tableAccount.autoUploadWWAnVideo == false {
                        uploadSession = NCNetworking.shared.sessionUploadBackground
                    } else if assetMediaType == PHAssetMediaType.image && tableAccount.autoUploadWWAnPhoto {
                        uploadSession = NCNetworking.shared.sessionUploadBackgroundWWan
                    } else if assetMediaType == PHAssetMediaType.video && tableAccount.autoUploadWWAnVideo {
                        uploadSession = NCNetworking.shared.sessionUploadBackgroundWWan
                    } else {
                        uploadSession = NCNetworking.shared.sessionUploadBackground
                    }
                }

                // MOST COMPATIBLE SEARCH --> HEIC --> JPG
                var fileNameSearchMetadata = fileName
                let ext = (fileNameSearchMetadata as NSString).pathExtension.uppercased()

                if ext == "HEIC", NCKeychain().formatCompatibility {
                    fileNameSearchMetadata = (fileNameSearchMetadata as NSString).deletingPathExtension + ".jpg"
                }

                if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", session.account, serverUrl, fileNameSearchMetadata)) != nil {
                    if selector == NCGlobal.shared.selectorUploadAutoUpload {
                        NCManageDatabase.shared.addPhotoLibrary([asset], account: session.account)
                    }
                } else {
                    let metadata = NCManageDatabase.shared.createMetadata(fileName: fileName,
                                                                          fileNameView: fileName,
                                                                          ocId: NSUUID().uuidString,
                                                                          serverUrl: serverUrl,
                                                                          url: "",
                                                                          contentType: "",
                                                                          session: session,
                                                                          sceneIdentifier: nil)

                    if isLivePhoto {
                        metadata.livePhotoFile = (metadata.fileName as NSString).deletingPathExtension + ".mov"
                    }
                    metadata.assetLocalIdentifier = asset.localIdentifier
                    metadata.session = uploadSession
                    metadata.sessionSelector = selector
                    metadata.status = NCGlobal.shared.metadataStatusWaitUpload
                    metadata.sessionDate = Date()
                    if assetMediaType == PHAssetMediaType.video {
                        metadata.classFile = NKCommon.TypeClassFile.video.rawValue
                    } else if assetMediaType == PHAssetMediaType.image {
                        metadata.classFile = NKCommon.TypeClassFile.image.rawValue
                    }
                    if selector == NCGlobal.shared.selectorUploadAutoUpload {
                        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Automatic upload added \(metadata.fileNameView) with Identifier \(metadata.assetLocalIdentifier)")
                        NCManageDatabase.shared.addPhotoLibrary([asset], account: account)
                    }
                    metadatas.append(metadata)
                }
            }

            self.endForAssetToUpload = true

            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start createProcessUploads")
            NCNetworkingProcess.shared.createProcessUploads(metadatas: metadatas, completion: completion)
        }
    }

    // MARK: -

    @objc func alignPhotoLibrary(controller: UIViewController?, account: String) {
        getCameraRollAssets(controller: controller, selector: NCGlobal.shared.selectorUploadAutoUploadAll, alignPhotoLibrary: true, account: account) { assets in
            NCManageDatabase.shared.clearTable(tablePhotoLibrary.self, account: account)
            guard let assets = assets else { return }

            NCManageDatabase.shared.addPhotoLibrary(assets, account: account)
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Align Photo Library \(assets.count)")
        }
    }

    private func getCameraRollAssets(controller: UIViewController?, selector: String, alignPhotoLibrary: Bool, account: String, completion: @escaping (_ assets: [PHAsset]?) -> Void) {
        NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
            guard hasPermission,
                  let tableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", account)) else {
                return completion(nil)
            }
            let assetCollection = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
            guard let assetCollection = assetCollection.firstObject else { return completion(nil) }
            let predicateImage = NSPredicate(format: "mediaType == %i", PHAssetMediaType.image.rawValue)
            let predicateVideo = NSPredicate(format: "mediaType == %i", PHAssetMediaType.video.rawValue)
            var predicate: NSPredicate?
            let fetchOptions = PHFetchOptions()
            var newAssets: [PHAsset] = []

            if alignPhotoLibrary || (tableAccount.autoUploadImage && tableAccount.autoUploadVideo) {
                predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicateImage, predicateVideo])
            } else if tableAccount.autoUploadImage {
                predicate = predicateImage
            } else if tableAccount.autoUploadVideo {
                predicate = predicateVideo
            } else {
                return completion(nil)
            }

            fetchOptions.predicate = predicate
            let assets: PHFetchResult<PHAsset> = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)

            if selector == NCGlobal.shared.selectorUploadAutoUpload {
                let idAssets = NCManageDatabase.shared.getPhotoLibraryIdAsset(image: tableAccount.autoUploadImage, video: tableAccount.autoUploadVideo, account: account)
                assets.enumerateObjects { asset, _, _ in
                    var creationDateString = ""
                    if let creationDate = asset.creationDate {
                        creationDateString = String(describing: creationDate)
                    }
                    let idAsset = account + asset.localIdentifier + creationDateString
                    if !(idAssets?.contains(idAsset) ?? false) {
                        newAssets.append(asset)
                    }
                }
            } else {
                assets.enumerateObjects { asset, _, _ in
                    newAssets.append(asset)
                }
            }
            completion(newAssets)
        }
    }
}
