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

import Foundation
import CoreLocation
import NCCommunication

class NCAutoUpload: NSObject, CLLocationManagerDelegate {
    @objc static let shared: NCAutoUpload = {
        let instance = NCAutoUpload()
        return instance
    }()
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    public var locationManager: CLLocationManager?
    private var hud: CCHud?
    private var endForAssetToUpload: Bool = false

    // MARK: -
    
    @objc func startSignificantChangeUpdates() {
        
        if locationManager == nil {
            
            locationManager = CLLocationManager.init()
            locationManager?.delegate = self
            locationManager?.distanceFilter = 100
            locationManager?.requestAlwaysAuthorization()
        }
        
        locationManager?.startMonitoringSignificantLocationChanges()
    }
    
    @objc func stopSignificantChangeUpdates() {
        
        locationManager?.stopMonitoringSignificantLocationChanges()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let location = locations.last
        guard let latitude = location?.coordinate.latitude else { return }
        guard let longitude = location?.coordinate.longitude else { return }
        
        NCCommunicationCommon.shared.writeLog("update location manager: latitude \(latitude) longitude \(longitude)")
        
        if let account = NCManageDatabase.shared.getAccountActive() {
            if account.autoUpload && account.autoUploadBackground && UIApplication.shared.applicationState == UIApplication.State.background {
                NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: nil) { (hasPermission) in
                    if hasPermission {
                        self.uploadAssetsNewAndFull(viewController: nil, selector: NCBrandGlobal.shared.selectorUploadAutoUpload)
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        NCAskAuthorization.shared.askAuthorizationLocationManager() { (hasFullPermissions) in
            if !hasFullPermissions {
                NCManageDatabase.shared.setAccountAutoUploadProperty("autoUploadBackground", state: false)
                self.stopSignificantChangeUpdates()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NCAskAuthorization.shared.askAuthorizationLocationManager() { (hasFullPermissions) in
            if !hasFullPermissions {
                NCManageDatabase.shared.setAccountAutoUploadProperty("autoUploadBackground", state: false)
                self.stopSignificantChangeUpdates()
            }
        }
    }
    
    // MARK: -
    
    @objc func initAutoUpload(viewController: UIViewController?) {
        if let account = NCManageDatabase.shared.getAccountActive() {
            if account.autoUpload {
                NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: viewController) { (hasPermission) in
                    if hasPermission {
                        self.uploadAssetsNewAndFull(viewController:viewController, selector: NCBrandGlobal.shared.selectorUploadAutoUpload)
                        if account.autoUploadBackground {
                            NCAskAuthorization.shared.askAuthorizationLocationManager() { (hasFullPermissions) in
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
                    }
                }
            }
        } else {
            stopSignificantChangeUpdates()
        }
    }
    
    @objc func autoUploadFullPhotos(viewController: UIViewController?) {
        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: appDelegate.window.rootViewController) { (hasPermission) in
            if hasPermission {
                self.uploadAssetsNewAndFull(viewController: viewController, selector: NCBrandGlobal.shared.selectorUploadAutoUploadAll)
            }
        }
    }
    
    private func uploadAssetsNewAndFull(viewController: UIViewController?, selector: String) {
        
        if appDelegate.account == nil || appDelegate.account.count == 0 { return }
        guard let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", appDelegate.account)) else { return }
        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: account.urlBase, account: account.account)
        var counterLivePhoto: Int = 0
        var metadataFull: [tableMetadata] = []
        
        DispatchQueue.global(qos: .background).async {
        
            self.getCameraRollAssets(viewController: viewController, account: account, selector: selector, alignPhotoLibrary: false) { (assets) in
                
                if assets == nil || assets?.count == 0 {
                    NCCommunicationCommon.shared.writeLog("Automatic upload, no new assets found")
                    return
                } else {
                    NCCommunicationCommon.shared.writeLog("Automatic upload, new \(assets?.count ?? 0) assets found")
                }
                guard let assets = assets else { return }
                
                if selector == NCBrandGlobal.shared.selectorUploadAutoUploadAll {
                    DispatchQueue.main.async {
                        self.hud = CCHud.init(view: self.appDelegate.window.rootViewController?.view)
                        NCContentPresenter.shared.messageNotification("_attention_", description: "_create_full_upload_", delay: NCBrandGlobal.shared.dismissAfterSecondLong, type: .info, errorCode: 0, forced: true)
                        self.hud?.visibleHudTitle(NSLocalizedString("_wait_", comment: ""), mode: MBProgressHUDMode.indeterminate, color: NCBrandColor.shared.brand)
                    }
                }
                
                // Create the folder for auto upload & if request the subfolders
                if NCNetworking.shared.createFolder(assets: assets, selector: selector, useSubFolder: account.autoUploadCreateSubfolder, account: account.account, urlBase: account.urlBase) {
                    if selector == NCBrandGlobal.shared.selectorUploadAutoUploadAll {
                        DispatchQueue.main.async {
                            NCContentPresenter.shared.messageNotification("_error_", description: "_error_createsubfolders_upload_", delay: NCBrandGlobal.shared.dismissAfterSecond, type: .error, errorCode: NCBrandGlobal.shared.ErrorInternalError, forced: true)
                            self.hud?.hideHud()
                        }
                        return
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
                    
                    let fileName = CCUtility.createFileName(asset.value(forKey: "filename") as? String, fileDate: assetDate, fileType: assetMediaType, keyFileName: NCBrandGlobal.shared.keyFileNameAutoUploadMask, keyFileNameType: NCBrandGlobal.shared.keyFileNameAutoUploadType, keyFileNameOriginal: NCBrandGlobal.shared.keyFileNameOriginalAutoUpload)!
                    
                    if (asset.mediaSubtypes.rawValue == PHAssetMediaSubtype.photoLive.rawValue || asset.mediaSubtypes.rawValue == (PHAssetMediaSubtype.photoHDR.rawValue + PHAssetMediaSubtype.photoLive.rawValue)) && CCUtility.getLivePhoto() {
                        livePhoto = true
                    }
                    
                    if selector == NCBrandGlobal.shared.selectorUploadAutoUploadAll {
                        session = NCCommunicationCommon.shared.sessionIdentifierUpload
                    } else {
                        if assetMediaType == PHAssetMediaType.image && account.autoUploadWWAnPhoto == false { session = NCNetworking.shared.sessionIdentifierBackground }
                        else if assetMediaType == PHAssetMediaType.video && account.autoUploadWWAnVideo == false { session = NCNetworking.shared.sessionIdentifierBackground }
                        else if assetMediaType == PHAssetMediaType.image && account.autoUploadWWAnPhoto { session = NCNetworking.shared.sessionIdentifierBackgroundWWan }
                        else if assetMediaType == PHAssetMediaType.video && account.autoUploadWWAnVideo { session = NCNetworking.shared.sessionIdentifierBackgroundWWan }
                        else { session = NCNetworking.shared.sessionIdentifierBackground }
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
                        
                        if selector == NCBrandGlobal.shared.selectorUploadAutoUpload {
                            NCManageDatabase.shared.addPhotoLibrary([asset], account: account.account)
                        }
                        
                    } else {
                        
                        /* INSERT METADATA FOR UPLOAD */
                        let metadataForUpload = NCManageDatabase.shared.createMetadata(account: account.account, fileName: fileName, ocId: NSUUID().uuidString, serverUrl: serverUrl, urlBase: account.urlBase, url: "", contentType: "", livePhoto: livePhoto)
                        metadataForUpload.assetLocalIdentifier = asset.localIdentifier
                        metadataForUpload.session = session
                        metadataForUpload.sessionSelector = selector
                        metadataForUpload.size = NCUtilityFileSystem.shared.getFileSize(asset: asset)
                        metadataForUpload.status = NCBrandGlobal.shared.metadataStatusWaitUpload
                        if assetMediaType == PHAssetMediaType.video {
                            metadataForUpload.typeFile = NCBrandGlobal.shared.metadataTypeFileVideo
                        } else if (assetMediaType == PHAssetMediaType.image) {
                            metadataForUpload.typeFile = NCBrandGlobal.shared.metadataTypeFileImage
                        }
                        
                        if selector == NCBrandGlobal.shared.selectorUploadAutoUpload {
                            NCCommunicationCommon.shared.writeLog("Automatic upload added \(metadataForUpload.fileNameView) (\(metadataForUpload.size) bytes) with Identifier \(metadataForUpload.assetLocalIdentifier)")
                            NCManageDatabase.shared.addMetadataForAutoUpload(metadataForUpload)
                            NCManageDatabase.shared.addPhotoLibrary([asset], account: account.account)
                        } else if selector == NCBrandGlobal.shared.selectorUploadAutoUploadAll {
                            metadataFull.append(metadataForUpload)
                        }
                        
                        /* INSERT METADATA MOV LIVE PHOTO FOR UPLOAD */
                        if livePhoto {
                            
                            counterLivePhoto += 1
                            let fileName = (fileName as NSString).deletingPathExtension + ".mov"
                            let ocId = NSUUID().uuidString
                            let filePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!
                            CCUtility.extractLivePhotoAsset(asset, filePath: filePath) { (url) in
                                if url != nil {
                                    let metadataForUpload = NCManageDatabase.shared.createMetadata(account: account.account, fileName: fileName, ocId: ocId, serverUrl: serverUrl, urlBase: account.urlBase, url: "", contentType: "", livePhoto: livePhoto)
                                    metadataForUpload.session = session
                                    metadataForUpload.sessionSelector = selector
                                    metadataForUpload.size = NCUtilityFileSystem.shared.getFileSize(filePath: filePath)
                                    metadataForUpload.status = NCBrandGlobal.shared.metadataStatusWaitUpload
                                    metadataForUpload.typeFile = NCBrandGlobal.shared.metadataTypeFileVideo
                                    
                                    if selector == NCBrandGlobal.shared.selectorUploadAutoUpload {
                                        NCCommunicationCommon.shared.writeLog("Automatic upload added Live Photo \(metadataForUpload.fileNameView) (\(metadataForUpload.size) bytes) with Identifier \(metadataForUpload.assetLocalIdentifier)")
                                        NCManageDatabase.shared.addMetadataForAutoUpload(metadataForUpload)
                                    } else if selector == NCBrandGlobal.shared.selectorUploadAutoUploadAll {
                                        metadataFull.append(metadataForUpload)
                                    }
                                }
                            }
                            counterLivePhoto -= 1
                            if self.endForAssetToUpload && counterLivePhoto == 0 && selector == NCBrandGlobal.shared.selectorUploadAutoUploadAll {
                                DispatchQueue.main.async {
                                    NCManageDatabase.shared.addMetadatas(metadataFull)
                                    self.hud?.hideHud()
                                }
                            }
                        }
                    }
                }
                
                self.endForAssetToUpload = true
                
                if counterLivePhoto == 0 && selector == NCBrandGlobal.shared.selectorUploadAutoUploadAll {
                    DispatchQueue.main.async {
                        NCManageDatabase.shared.addMetadatas(metadataFull)
                        self.hud?.hideHud()
                    }
                }
            } // END
        } // END DispatchQueue.global(qos: .background).async
    }
    
    // MARK: -

    @objc func alignPhotoLibrary(viewController: UIViewController?) {
        if let account = NCManageDatabase.shared.getAccountActive() {
            getCameraRollAssets(viewController: viewController, account: account, selector: NCBrandGlobal.shared.selectorUploadAutoUploadAll, alignPhotoLibrary: true) { (assets) in
                NCManageDatabase.shared.clearTable(tablePhotoLibrary.self, account: account.account)
                if let assets = assets {
                    NCManageDatabase.shared.addPhotoLibrary(assets, account: account.account)
                    NCCommunicationCommon.shared.writeLog("Align Photo Library \(assets.count)")
                }
            }
        }
    }
    
    private func getCameraRollAssets(viewController: UIViewController?, account: tableAccount, selector: String, alignPhotoLibrary: Bool, completion: @escaping (_ assets: [PHAsset]?)->()) {
                
        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: viewController) { (hasPermission) in
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
                        completion(nil)
                        return
                    }
                    
                    fetchOptions.predicate = predicate
                    let assets: PHFetchResult<PHAsset> = PHAsset.fetchAssets(in: assetCollection.firstObject!, options: fetchOptions)
                    
                    if selector == NCBrandGlobal.shared.selectorUploadAutoUpload {
                        var creationDate = ""
                        var idAsset = ""
                        let idsAsset = NCManageDatabase.shared.getPhotoLibraryIdAsset(image: account.autoUploadImage, video: account.autoUploadVideo, account: account.account)
                        assets.enumerateObjects { (asset, _, _) in
                            if asset.creationDate != nil { creationDate = String(describing: asset.creationDate!) }
                            idAsset = account.account + asset.localIdentifier + creationDate
                            if !(idsAsset?.contains(idAsset) ?? false) {
                                newAssets.append(asset)
                            }
                        }
                    } else {
                        assets.enumerateObjects { (asset, _, _) in
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
