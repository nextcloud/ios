//
//  NCNetworkingNotificationCenter.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/04/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

@objc class NCNetworkingNotificationCenter: NSObject {
    @objc public static let shared: NCNetworkingNotificationCenter = {
        let instance = NCNetworkingNotificationCenter()
        
        NotificationCenter.default.addObserver(instance, selector: #selector(downloadFileStart(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadFileStart), object: nil)
        NotificationCenter.default.addObserver(instance, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadedFile), object: nil)

        NotificationCenter.default.addObserver(instance, selector: #selector(uploadFileStart(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadFileStart), object: nil)
        NotificationCenter.default.addObserver(instance, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadedFile), object: nil)
        
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var viewerQuickLook: NCViewerQuickLook?
    
    //MARK: - Download

    @objc func downloadFileStart(_ notification: NSNotification) {
        
//        if let userInfo = notification.userInfo as NSDictionary? {
//            if let ocId = userInfo["ocId"] as? String, let serverUrl = userInfo["serverUrl"] as? String { }
//        }
    }
    
    @objc func downloadedFile(_ notification: NSNotification) {
            
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let selector = userInfo["selector"] as? String, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String {
        
                if metadata.account != appDelegate.account { return }
                
                if errorCode == 0 {
                    
                    switch selector {
                    case selectorLoadFileQuickLook:
                        
                        let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
                        CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: fileNamePath)

                        viewerQuickLook = NCViewerQuickLook.init()
                        viewerQuickLook?.quickLook(url: URL(fileURLWithPath: fileNamePath), viewController: appDelegate.activeMain)
                        
                    case selectorLoadFileView, selectorLoadFileViewFavorite:
                        
                        if UIApplication.shared.applicationState == UIApplication.State.active {
                            
                            let fileURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
                            
                            if metadata.contentType.contains("opendocument") && !NCUtility.shared.isRichDocument(metadata) {
                                
                                NCMainCommon.sharedInstance.openIn(fileURL: fileURL, selector: selector)
                                
                            } else if metadata.typeFile == k_metadataTypeFile_compress || metadata.typeFile == k_metadataTypeFile_unknown {

                                NCMainCommon.sharedInstance.openIn(fileURL: fileURL, selector: selector)
                                
                            } else if metadata.typeFile == k_metadataTypeFile_imagemeter {
                                
                                NCMainCommon.sharedInstance.openIn(fileURL: fileURL, selector: selector)
                                
                            } else {
                                
                                if appDelegate.activeMain.view.window != nil {
                                    appDelegate.activeMain.shouldPerformSegue(metadata, selector: selector)
                                } else if appDelegate.activeFavorites.view.window != nil {
                                    appDelegate.activeFavorites.shouldPerformSegue(metadata, selector: selector)
                                }
                            }
                        }
                        
                    case selectorOpenIn, selectorOpenInDetail:
                        
                        if UIApplication.shared.applicationState == UIApplication.State.active {
                            let fileURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
                            NCMainCommon.sharedInstance.openIn(fileURL: fileURL, selector: selector)
                        }
                        
                    case selectorSaveAlbum:
                        
                        appDelegate.activeMain.save(toPhotoAlbum: metadata)
                        
                    case selectorLoadCopy:
                        
                        appDelegate.activeMain.copyFile(toPasteboard: metadata)
                        
                    case selectorLoadOffline:
                        
                        NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, offline: true)
                        
                    default:
                        break
                    }
                            
                } else {
                    
                    // File do not exists on server, remove in local
                    if (errorCode == 404 || errorCode == -1011) { // - 1011 = kCFURLErrorBadServerResponse
                        
                        do {
                            try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                        } catch { }
                        
                        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                        NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                        
                    } else {
                        NCContentPresenter.shared.messageNotification("_download_file_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                }
            }
        }
    }
    
    //MARK: - Upload

    @objc func uploadFileStart(_ notification: NSNotification) {
        
//        if let userInfo = notification.userInfo as NSDictionary? {
//            if let ocId = userInfo["ocId"] as? String, let serverUrl = userInfo["serverUrl"] as? String, let _ = userInfo["task"] as? URLSessionUploadTask { }
//        }
    }
    
    @objc func uploadedFile(_ notification: NSNotification) {
    
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String {
                                                
                if metadata.account == appDelegate.account {
                    if errorCode == 0 {
                        //appDelegate.startLoadAutoUpload()
                    } else {
                        if errorCode != -999 && errorCode != 401 && errorDescription != "" {
                            NCContentPresenter.shared.messageNotification("_upload_file_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                }
            }
        }
    }
    
}

