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
import NCCommunication

class NCAutoUpload: NSObject, CLLocationManagerDelegate {
    @objc static let shared: NCAutoUpload = {
        let instance = NCAutoUpload()
        return instance
    }()

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    public var locationManager: CLLocationManager?
    private var endForAssetToUpload: Bool = false

    // MARK: -

    @objc func startSignificantChangeUpdates() {

        if locationManager == nil {

            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.distanceFilter = 10
        }

        locationManager?.requestAlwaysAuthorization()
        locationManager?.startMonitoringSignificantLocationChanges()
    }

    @objc func stopSignificantChangeUpdates() {

        locationManager?.stopMonitoringSignificantLocationChanges()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        let location = locations.last
        guard let latitude = location?.coordinate.latitude else { return }
        guard let longitude = location?.coordinate.longitude else { return }

        NCCommunicationCommon.shared.writeLog("Location manager: latitude \(latitude) longitude \(longitude)")

        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            if activeAccount.autoUpload && activeAccount.autoUploadBackground && UIApplication.shared.applicationState == UIApplication.State.background {
                NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: nil) { hasPermission in
                    if hasPermission {
                        self.uploadAssetsNewAndFull(viewController: nil, selector: NCGlobal.shared.selectorUploadAutoUpload, log: "Change location") { items in
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUpdateBadgeNumber)
                            if items > 0 {
                                self.appDelegate.networkingProcessUpload?.startProcess()
                            }
                        }
                    }
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedAlways {
            NCManageDatabase.shared.setAccountAutoUploadProperty("autoUploadBackground", state: false)
            self.stopSignificantChangeUpdates()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NCAskAuthorization.shared.askAuthorizationLocationManager { hasFullPermissions in
            if !hasFullPermissions {
                NCManageDatabase.shared.setAccountAutoUploadProperty("autoUploadBackground", state: false)
                self.stopSignificantChangeUpdates()
            }
        }
    }

    // MARK: -

    @objc func initAutoUpload(viewController: UIViewController?, completion: @escaping (_ items: Int) -> Void) {
        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            if activeAccount.autoUpload {
                NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: viewController) { hasPermission in
                    if hasPermission {
                        self.uploadAssetsNewAndFull(viewController: viewController, selector: NCGlobal.shared.selectorUploadAutoUpload, log: "Init Auto Upload") { items in
                            if items > 0 {
                                self.appDelegate.networkingProcessUpload?.startProcess()
                            }
                            completion(items)
                        }
                        if activeAccount.autoUploadBackground {
                            NCAskAuthorization.shared.askAuthorizationLocationManager { hasFullPermissions in
                                if hasFullPermissions {
                                    self.startSignificantChangeUpdates()
                                } else {
                                    NCManageDatabase.shared.setAccountAutoUploadProperty("autoUploadBackground", state: false)
                                    self.stopSignificantChangeUpdates()
                                }
                            }
                        }
                    } else {
                        NCManageDatabase.shared.setAccountAutoUploadProperty("autoUpload", state: false)
                        self.stopSignificantChangeUpdates()
                        completion(0)
                    }
                }
            } else {
                completion(0)
            }
        } else {
            stopSignificantChangeUpdates()
            completion(0)
        }
    }

    @objc func autoUploadFullPhotos(viewController: UIViewController?, log: String) {
        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: appDelegate.window?.rootViewController) { hasPermission in
            if hasPermission {
                NCContentPresenter.shared.messageNotification("_attention_", description: "_create_full_upload_", delay: NCGlobal.shared.dismissAfterSecondLong, type: .info, errorCode: NCGlobal.shared.errorNoError, priority: .max)
                NCUtility.shared.startActivityIndicator(backgroundView: nil, blurEffect: true)
                self.uploadAssetsNewAndFull(viewController: viewController, selector: NCGlobal.shared.selectorUploadAutoUploadAll, log: log) { _ in
                    NCUtility.shared.stopActivityIndicator()
                }
            }
        }
    }

    private func uploadAssetsNewAndFull(viewController: UIViewController?, selector: String, log: String, completion: @escaping (_ items: Int) -> Void) {

        if appDelegate.account == "" { return }

        guard let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", appDelegate.account)) else { return }
        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: account.urlBase, account: account.account)
        var counterLivePhoto: Int = 0
        var metadataFull: [tableMetadata] = []
        var counterItemsUpload: Int = 0
        DispatchQueue.global(qos: .background).async {

            self.getCameraRollAssets(viewController: viewController, account: account, selector: selector, alignPhotoLibrary: false) { assets in

                if assets == nil || assets?.count == 0 {
                    NCCommunicationCommon.shared.writeLog("Automatic upload, no new assets found [" + log + "]")
                    DispatchQueue.main.async {
                        completion(counterItemsUpload)
                    }
                    return
                } else {
                    NCCommunicationCommon.shared.writeLog("Automatic upload, new \(assets?.count ?? 0) assets found [" + log + "]")
                }
                guard let assets = assets else { return }

                // Create the folder for auto upload & if request the subfolders
                if !NCNetworking.shared.createFolder(assets: assets, selector: selector, useSubFolder: account.autoUploadCreateSubfolder, account: account.account, urlBase: account.urlBase) {
                    DispatchQueue.main.async {
                        if selector == NCGlobal.shared.selectorUploadAutoUploadAll {
                            NCContentPresenter.shared.messageNotification("_error_", description: "_error_createsubfolders_upload_", delay: NCGlobal.shared.dismissAfterSecond, type: .error, errorCode: NCGlobal.shared.errorInternalError, priority: .max)
                        }
                        return completion(counterItemsUpload)
                    }
                }

                self.endForAssetToUpload = false

                for asset in assets {

                    var livePhoto = false
                    var session: String = ""
                    guard let assetDate = asset.creationDate else { continue }
                    let assetMediaType = asset.mediaType
                    let formatter = DateFormatter()
                    var serverUrl: String = ""

                    let fileName = CCUtility.createFileName(asset.value(forKey: "filename") as? String, fileDate: assetDate, fileType: assetMediaType, keyFileName: NCGlobal.shared.keyFileNameAutoUploadMask, keyFileNameType: NCGlobal.shared.keyFileNameAutoUploadType, keyFileNameOriginal: NCGlobal.shared.keyFileNameOriginalAutoUpload, forcedNewFileName: false)!

                    if asset.mediaSubtypes.contains(.photoLive) && CCUtility.getLivePhoto() {
                        livePhoto = true
                    }

                    if selector == NCGlobal.shared.selectorUploadAutoUploadAll {
                        session = NCCommunicationCommon.shared.sessionIdentifierUpload
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

                    formatter.dateFormat = "yyyy"
                    let yearString = formatter.string(from: assetDate)
                    formatter.dateFormat = "MM"
                    let monthString = formatter.string(from: assetDate)

                    if account.autoUploadCreateSubfolder {
                        serverUrl = autoUploadPath + "/" + yearString + "/" + monthString
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

                        /* INSERT METADATA FOR UPLOAD */
                        let metadataForUpload = NCManageDatabase.shared.createMetadata(account: account.account, user: account.user, userId: account.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: serverUrl, urlBase: account.urlBase, url: "", contentType: "", livePhoto: livePhoto)
                        metadataForUpload.assetLocalIdentifier = asset.localIdentifier
                        metadataForUpload.session = session
                        metadataForUpload.sessionSelector = selector
                        metadataForUpload.size = NCUtilityFileSystem.shared.getFileSize(asset: asset)
                        metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
                        if assetMediaType == PHAssetMediaType.video {
                            metadataForUpload.classFile = NCCommunicationCommon.typeClassFile.video.rawValue
                        } else if assetMediaType == PHAssetMediaType.image {
                            metadataForUpload.classFile = NCCommunicationCommon.typeClassFile.image.rawValue
                        }

                        if selector == NCGlobal.shared.selectorUploadAutoUpload {
                            NCCommunicationCommon.shared.writeLog("Automatic upload added \(metadataForUpload.fileNameView) (\(metadataForUpload.size) bytes) with Identifier \(metadataForUpload.assetLocalIdentifier)")
                            self.appDelegate.networkingProcessUpload?.createProcessUploads(metadatas: [metadataForUpload], verifyAlreadyExists: true)
                            NCManageDatabase.shared.addPhotoLibrary([asset], account: account.account)
                        } else if selector == NCGlobal.shared.selectorUploadAutoUploadAll {
                            metadataFull.append(metadataForUpload)
                        }
                        counterItemsUpload += 1

                        /* INSERT METADATA MOV LIVE PHOTO FOR UPLOAD */
                        if livePhoto {

                            counterLivePhoto += 1
                            let fileName = (fileName as NSString).deletingPathExtension + ".mov"
                            let ocId = NSUUID().uuidString
                            let filePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!

                            CCUtility.extractLivePhotoAsset(asset, filePath: filePath) { url in
                                if url != nil {
                                    let metadataForUpload = NCManageDatabase.shared.createMetadata(account: account.account, user: account.user, userId: account.userId, fileName: fileName, fileNameView: fileName, ocId: ocId, serverUrl: serverUrl, urlBase: account.urlBase, url: "", contentType: "", livePhoto: livePhoto)
                                    metadataForUpload.session = session
                                    metadataForUpload.sessionSelector = selector
                                    metadataForUpload.size = NCUtilityFileSystem.shared.getFileSize(filePath: filePath)
                                    metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
                                    metadataForUpload.classFile = NCCommunicationCommon.typeClassFile.video.rawValue

                                    if selector == NCGlobal.shared.selectorUploadAutoUpload {
                                        NCCommunicationCommon.shared.writeLog("Automatic upload added Live Photo \(metadataForUpload.fileNameView) (\(metadataForUpload.size) bytes) with Identifier \(metadataForUpload.assetLocalIdentifier)")
                                        self.appDelegate.networkingProcessUpload?.createProcessUploads(metadatas: [metadataForUpload], verifyAlreadyExists: true)

                                    } else if selector == NCGlobal.shared.selectorUploadAutoUploadAll {
                                        metadataFull.append(metadataForUpload)
                                    }
                                    counterItemsUpload += 1
                                }
                                counterLivePhoto -= 1
                                if counterLivePhoto == 0 && self.endForAssetToUpload {
                                    DispatchQueue.main.async {
                                        if selector == NCGlobal.shared.selectorUploadAutoUploadAll {
                                            self.appDelegate.networkingProcessUpload?.createProcessUploads(metadatas: metadataFull)
                                        }
                                        completion(counterItemsUpload)
                                    }
                                }
                            }
                        }
                    }
                }

                self.endForAssetToUpload = true

                if counterLivePhoto == 0 {
                    DispatchQueue.main.async {
                        if selector == NCGlobal.shared.selectorUploadAutoUploadAll {
                            self.appDelegate.networkingProcessUpload?.createProcessUploads(metadatas: metadataFull)
                        }
                        completion(counterItemsUpload)
                    }
                }
            }
        }
    }

    // MARK: -

    @objc func alignPhotoLibrary(viewController: UIViewController?) {
        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            getCameraRollAssets(viewController: viewController, account: activeAccount, selector: NCGlobal.shared.selectorUploadAutoUploadAll, alignPhotoLibrary: true) { assets in
                NCManageDatabase.shared.clearTable(tablePhotoLibrary.self, account: activeAccount.account)
                if let assets = assets {
                    NCManageDatabase.shared.addPhotoLibrary(assets, account: activeAccount.account)
                    NCCommunicationCommon.shared.writeLog("Align Photo Library \(assets.count)")
                }
            }
        }
    }

    private func getCameraRollAssets(viewController: UIViewController?, account: tableAccount, selector: String, alignPhotoLibrary: Bool, completion: @escaping (_ assets: [PHAsset]?) -> Void) {

        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: viewController) { hasPermission in
            if hasPermission {
                let assetCollection = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
                if assetCollection.count > 0 {

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
                        var creationDate = ""
                        var idAsset = ""
                        let idsAsset = NCManageDatabase.shared.getPhotoLibraryIdAsset(image: account.autoUploadImage, video: account.autoUploadVideo, account: account.account)
                        assets.enumerateObjects { asset, _, _ in
                            if asset.creationDate != nil { creationDate = String(describing: asset.creationDate!) }
                            idAsset = account.account + asset.localIdentifier + creationDate
                            if !(idsAsset?.contains(idAsset) ?? false) {
                                newAssets.append(asset)
                            }
                        }
                    } else {
                        assets.enumerateObjects { asset, _, _ in
                            newAssets.append(asset)
                        }
                    }
                    completion(newAssets)
                } else {
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
    }
}
