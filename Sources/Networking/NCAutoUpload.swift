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

class NCAutoUpload: NSObject {
    @objc static let shared: NCAutoUpload = {
        let instance = NCAutoUpload()
        return instance
    }()

    private var endForAssetToUpload: Bool = false
    private let appDelegate = UIApplication.shared.delegate as? AppDelegate
    private var applicationState = UIApplication.shared.applicationState

    // MARK: -

    @objc func initAutoUpload(viewController: UIViewController?, completion: @escaping (_ items: Int) -> Void) {
        guard let account = NCManageDatabase.shared.getActiveAccount(), account.autoUpload else {
            completion(0)
            return
        }
        applicationState = UIApplication.shared.applicationState

        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: viewController) { hasPermission in
            guard hasPermission else {
                NCManageDatabase.shared.setAccountAutoUploadProperty("autoUpload", state: false)
                completion(0)
                return
            }
            DispatchQueue.global().async {
                self.uploadAssetsNewAndFull(viewController: viewController, selector: NCGlobal.shared.selectorUploadAutoUpload, log: "Init Auto Upload") { items in
                    completion(items)
                }
            }
        }
    }

    @objc func autoUploadFullPhotos(viewController: UIViewController?, log: String) {

        applicationState = UIApplication.shared.applicationState

        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: viewController) { hasPermission in
            guard hasPermission else { return }
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_create_full_upload_")
            NCContentPresenter.shared.showWarning(error: error, priority: .max)
            NCActivityIndicator.shared.start()
            DispatchQueue.global().async {
                self.uploadAssetsNewAndFull(viewController: viewController, selector: NCGlobal.shared.selectorUploadAutoUploadAll, log: log) { _ in
                    NCActivityIndicator.shared.stop()
                }
            }
        }
    }

    private func uploadAssetsNewAndFull(viewController: UIViewController?, selector: String, log: String, completion: @escaping (_ items: Int) -> Void) {
        guard let account = NCManageDatabase.shared.getActiveAccount() else {
            completion(0)
            return
        }

        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: account.urlBase, userId: account.userId, account: account.account)
        let autoUploadSubfolderGranularity = NCManageDatabase.shared.getAccountAutoUploadSubfolderGranularity()
        var metadatas: [tableMetadata] = []

        self.getCameraRollAssets(viewController: viewController, account: account, selector: selector, alignPhotoLibrary: false) { assets in
            guard let assets = assets, !assets.isEmpty else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Automatic upload, no new assets found [" + log + "]")
                completion(0)
                return
            }
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Automatic upload, new \(assets.count) assets found [" + log + "]")
            // Create the folder for auto upload & if request the subfolders
            if !NCNetworking.shared.createFolder(assets: assets, selector: selector, useSubFolder: account.autoUploadCreateSubfolder, account: account.account, urlBase: account.urlBase, userId: account.userId, withPush: false) {
                if selector == NCGlobal.shared.selectorUploadAutoUploadAll {
                    let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_error_createsubfolders_upload_")
                    NCContentPresenter.shared.showError(error: error, priority: .max)
                }
                return completion(0)
            }

            self.endForAssetToUpload = false

            for asset in assets {

                var livePhoto = false
                var session: String = ""
                let dateFormatter = DateFormatter()
                let assetDate = asset.creationDate ?? Date()
                dateFormatter.dateFormat = "yyyy"
                let year = dateFormatter.string(from: assetDate)
                dateFormatter.dateFormat = "MM"
                let month = dateFormatter.string(from: assetDate)
                dateFormatter.dateFormat = "dd"
                let day = dateFormatter.string(from: assetDate)
                let assetMediaType = asset.mediaType
                var serverUrl: String = ""
                let fileName = CCUtility.createFileName(asset.value(forKey: "filename") as? String, fileDate: assetDate, fileType: assetMediaType, keyFileName: NCGlobal.shared.keyFileNameAutoUploadMask, keyFileNameType: NCGlobal.shared.keyFileNameAutoUploadType, keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginalAutoUpload, forcedNewFileName: false)!

                if asset.mediaSubtypes.contains(.photoLive) && CCUtility.getLivePhoto() {
                    livePhoto = true
                }

                if selector == NCGlobal.shared.selectorUploadAutoUploadAll {
                    session = NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload
                } else {
                    if assetMediaType == PHAssetMediaType.image && account.autoUploadWWAnPhoto == false {
                        session = NCNetworking.shared.sessionIdentifierBackground
                    } else if assetMediaType == PHAssetMediaType.video && account.autoUploadWWAnVideo == false {
                        session = NCNetworking.shared.sessionIdentifierBackground
                    } else if assetMediaType == PHAssetMediaType.image && account.autoUploadWWAnPhoto {
                        session = NCNetworking.shared.sessionIdentifierBackgroundWWan
                    } else if assetMediaType == PHAssetMediaType.video && account.autoUploadWWAnVideo {
                        session = NCNetworking.shared.sessionIdentifierBackgroundWWan
                    } else { session = NCNetworking.shared.sessionIdentifierBackground }
                }

                if account.autoUploadCreateSubfolder {
                    if (autoUploadSubfolderGranularity == 0) {
                        serverUrl = autoUploadPath + "/" + year
                    }
                    else if (autoUploadSubfolderGranularity == 2) {
                        serverUrl = autoUploadPath + "/" + year + "/" + month + "/" + day
                    }
                    else {  // Month Granularity is default
                        serverUrl = autoUploadPath + "/" + year + "/" + month
                    }
                } else {
                    serverUrl = autoUploadPath
                }

                // MOST COMPATIBLE SEARCH --> HEIC --> JPG
                var fileNameSearchMetadata = fileName
                let ext = (fileNameSearchMetadata as NSString).pathExtension.uppercased()

                if ext == "HEIC" && CCUtility.getFormatCompatibility() {
                    fileNameSearchMetadata = (fileNameSearchMetadata as NSString).deletingPathExtension + ".jpg"
                }
                
                if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", account.account, serverUrl, fileNameSearchMetadata)) != nil {
                    if selector == NCGlobal.shared.selectorUploadAutoUpload {
                        NCManageDatabase.shared.addPhotoLibrary([asset], account: account.account)
                    }
                } else {
                    let metadata = NCManageDatabase.shared.createMetadata(account: account.account, user: account.user, userId: account.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: serverUrl, urlBase: account.urlBase, url: "", contentType: "", isLivePhoto: livePhoto)
                    metadata.assetLocalIdentifier = asset.localIdentifier
                    metadata.session = session
                    metadata.sessionSelector = selector
                    metadata.status = NCGlobal.shared.metadataStatusWaitUpload
                    if assetMediaType == PHAssetMediaType.video {
                        metadata.classFile = NKCommon.TypeClassFile.video.rawValue
                    } else if assetMediaType == PHAssetMediaType.image {
                        metadata.classFile = NKCommon.TypeClassFile.image.rawValue
                    }
                    if selector == NCGlobal.shared.selectorUploadAutoUpload {
                        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Automatic upload added \(metadata.fileNameView) with Identifier \(metadata.assetLocalIdentifier)")
                        NCManageDatabase.shared.addPhotoLibrary([asset], account: account.account)
                    }
                    metadatas.append(metadata)
                }
            }

            self.endForAssetToUpload = true

            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start createProcessUploads")
            NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: metadatas, completion: completion)
        }
    }

    // MARK: -

    @objc func alignPhotoLibrary(viewController: UIViewController?) {
        guard let activeAccount = NCManageDatabase.shared.getActiveAccount() else { return }

        getCameraRollAssets(viewController: viewController, account: activeAccount, selector: NCGlobal.shared.selectorUploadAutoUploadAll, alignPhotoLibrary: true) { assets in
            NCManageDatabase.shared.clearTable(tablePhotoLibrary.self, account: activeAccount.account)
            guard let assets = assets else { return }

            NCManageDatabase.shared.addPhotoLibrary(assets, account: activeAccount.account)
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Align Photo Library \(assets.count)")
        }
    }

    private func getCameraRollAssets(viewController: UIViewController?, account: tableAccount, selector: String, alignPhotoLibrary: Bool, completion: @escaping (_ assets: [PHAsset]?) -> Void) {

        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: viewController) { hasPermission in
            guard hasPermission else {
                completion(nil)
                return
            }
            let assetCollection = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
            if assetCollection.count == 0 {
                completion(nil)
                return
            }

            let predicateImage = NSPredicate(format: "mediaType == %i", PHAssetMediaType.image.rawValue)
            let predicateVideo = NSPredicate(format: "mediaType == %i", PHAssetMediaType.video.rawValue)
            var predicate: NSPredicate?
            let fetchOptions = PHFetchOptions()
            var newAssets: [PHAsset] = []

            if alignPhotoLibrary || (account.autoUploadImage && account.autoUploadVideo) {
                predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicateImage, predicateVideo])
            } else if account.autoUploadImage {
                predicate = predicateImage
            } else if account.autoUploadVideo {
                predicate = predicateVideo
            } else {
                return completion(nil)
            }

            fetchOptions.predicate = predicate
            let assets: PHFetchResult<PHAsset> = PHAsset.fetchAssets(in: assetCollection.firstObject!, options: fetchOptions)

            if selector == NCGlobal.shared.selectorUploadAutoUpload {
                let idAssets = NCManageDatabase.shared.getPhotoLibraryIdAsset(image: account.autoUploadImage, video: account.autoUploadVideo, account: account.account)
                assets.enumerateObjects { asset, _, _ in
                    var creationDateString = ""
                    if let creationDate = asset.creationDate {
                        creationDateString = String(describing: creationDate)
                    }
                    let idAsset = account.account + asset.localIdentifier + creationDateString
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
