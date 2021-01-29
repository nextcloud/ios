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

    // MARK: -
    
    @objc public func startSignificantChangeUpdates() {
        
        if locationManager == nil {
            
            locationManager = CLLocationManager.init()
            locationManager?.delegate = self
            locationManager?.requestAlwaysAuthorization()
        }
        
        locationManager?.startMonitoringSignificantLocationChanges()
    }
    
    @objc public func stopSignificantChangeUpdates() {
        
        locationManager?.stopMonitoringSignificantLocationChanges()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let location = locations.last
        let latitude = String(describing: location?.coordinate.latitude)
        let longitude = String(describing: location?.coordinate.longitude)
        
        NCCommunicationCommon.shared.writeLog("update location manager: latitude " + latitude + ", longitude " + longitude)
        
        if let account = NCManageDatabase.shared.getAccountActive() {
            if account.autoUpload && account.autoUploadBackground && UIApplication.shared.applicationState == UIApplication.State.background {
                self.uploadNewAssets()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        statusAuthorizationLocationChanged()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusAuthorizationLocationChanged()
    }
    
    func statusAuthorizationLocationChanged() {
        NCManageDatabase.shared.setAccountAutoUploadProperty("autoUploadBackground", state: false)
        self.stopSignificantChangeUpdates()
    }
    
    // MARK: -
    
    @objc func initStateAutoUpload(viewController: UIViewController?) {
        
        if let account = NCManageDatabase.shared.getAccountActive() {
            if account.autoUpload {
                setupAutoUpload()
                if account.autoUploadBackground {
                    NCAskAuthorization.shared.askAuthorizationLocationManager(viewController: appDelegate.window.rootViewController) { (hasPermissions) in
                        if hasPermissions {
                            self.startSignificantChangeUpdates()
                        } else {
                            NCManageDatabase.shared.setAccountAutoUploadProperty("autoUploadBackground", state: false)
                            self.stopSignificantChangeUpdates()
                        }
                    }
                }
            }
        } else {
            stopSignificantChangeUpdates()
        }
    }
    
    @objc func setupAutoUpload() {
        
        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: appDelegate.window.rootViewController) { (hasPermission) in
            if hasPermission {
                self.uploadNewAssets()
            } else {
                NCManageDatabase.shared.setAccountAutoUploadProperty("autoUpload", state: false)
                self.stopSignificantChangeUpdates()
            }
        }
        
    }
    
    @objc func uploadNewAssets() {
        
    }
    
    @objc func setupAutoUploadFull() {
        
    }
    
    @objc func alignPhotoLibrary() {
        if let account = NCManageDatabase.shared.getAccountActive() {
            getCameraRollAssets(account: account, selector: NCBrandGlobal.shared.selectorUploadAutoUploadAll, alignPhotoLibrary: true) { (assets) in
                NCManageDatabase.shared.clearTable(tablePhotoLibrary.self, account: account.account)
                if let assets = assets {
                    NCManageDatabase.shared.addPhotoLibrary(assets, account: account.account)
                    NCCommunicationCommon.shared.writeLog("Align Photo Library \(assets.count)")
                }
            }
        }
    }
    
    func getCameraRollAssets(account: tableAccount, selector: String, alignPhotoLibrary: Bool, completion: @escaping (_ assets: [PHAsset]?)->()) {
                
        NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: appDelegate.window.rootViewController) { (hasPermission) in
            if hasPermission {
                let assetCollection = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
                if assetCollection.count > 0 {
                    
                    let predicateImage = NSPredicate(format: "mediaType == %i", PHAssetMediaType.image as! CVarArg)
                    let predicateVideo = NSPredicate(format: "mediaType == %i", PHAssetMediaType.video as! CVarArg)
                    var predicate: NSPredicate?
                    let fetchOptions = PHFetchOptions()
                    

                    if alignPhotoLibrary || (account.autoUploadImage && account.autoUploadVideo) {
                        predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicateImage, predicateVideo])
                    } else if account.autoUploadImage {
                        predicate = predicateImage
                    } else if account.autoUploadVideo {
                        predicate = predicateVideo
                    }
                    
                    fetchOptions.predicate = predicate
                    let assets: PHFetchResult<PHAsset> = PHAsset.fetchAssets(in: assetCollection.firstObject!, options: fetchOptions)
                    
                    if selector == NCBrandGlobal.shared.selectorUploadAutoUpload {
                        var newAssets: [PHAsset] = []
                        var creationDate = ""
                        var idAsset = ""
                        let idsAsset = NCManageDatabase.shared.getPhotoLibraryIdAsset(image: account.autoUploadImage, video: account.autoUploadVideo, account: account.account)
                        assets.enumerateObjects { (asset, count, stop) in
                            if asset.creationDate != nil { creationDate = String(describing: asset.creationDate) }
                            idAsset = account.account + asset.localIdentifier + creationDate
                            if !(idsAsset?.contains(idAsset) ?? false) {
                                newAssets.append(asset)
                            }
                            completion(newAssets)
                        }
                    } else {
                        completion(assets.copy() as? [PHAsset])
                    }
                }
            }
            
            completion(nil)
        }
    }
}
