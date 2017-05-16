//
//  CCActions.swift
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 06/02/17.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

@objc protocol CCActionsDeleteDelegate {
    
    func deleteFileOrFolderSuccess(_ metadataNet: CCMetadataNet)
    func deleteFileOrFolderFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger)
}

@objc protocol CCActionsRenameDelegate {

    func renameSuccess(_ metadataNet: CCMetadataNet)
    func renameMoveFileOrFolderFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger)
    
    func uploadFileSuccess(_ metadataNet: CCMetadataNet, fileID: String, serverUrl: String, selector: String, selectorPost: String)
    func uploadFileFailure(_ metadataNet: CCMetadataNet, fileID: String, serverUrl: String, selector: String, message: String, errorCode: NSInteger)
}

@objc protocol CCActionsSearchDelegate {
    
    func searchSuccess(_ metadataNet: CCMetadataNet, metadatas: [Any])
    func searchFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger)
}

@objc protocol CCActionsDownloadThumbnailDelegate {
    
    func downloadThumbnailSuccess(_ metadataNet: CCMetadataNet)
}

@objc protocol CCActionsSettingFavoriteDelegate {
    
    func settingFavoriteSuccess(_ metadataNet: CCMetadataNet)
    func settingFavoriteFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger)
}

@objc protocol CCActionsListingFavoritesDelegate {
    
    func listingFavoritesSuccess(_ metadataNet: CCMetadataNet, metadatas: [Any])
    func listingFavoritesFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger)
}

class CCActions: NSObject {
    
    //MARK: Shared Instance
    
    static let sharedInstance: CCActions = {
        let instance = CCActions()
        return instance
    }()
    
    //MARK: Local Variable
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK: Init
    
    override init() {
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Delete File or Folder
    // --------------------------------------------------------------------------------------------

    func deleteFileOrFolder(_ metadata: CCMetadata, delegate: AnyObject) {
        
        let serverUrl = CCCoreData.getServerUrl(fromDirectoryID: metadata.directoryID, activeAccount: appDelegate.activeAccount)
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)

        // fix CCActions.swift line 88 2.17.2 (00005)
        if (serverUrl == nil) {
            
            print("[LOG] Server URL not found \(metadata.directoryID)")
            
            appDelegate.messageNotification("_delete_", description: "_file_not_found_reload_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            
            return
        }
        
        if metadata.cryptated == true {
            
            metadataNet.action = actionDeleteFileDirectory
            metadataNet.delegate = delegate
            metadataNet.fileID = metadata.fileID
            metadataNet.fileNamePrint = metadata.fileNamePrint
            metadataNet.metadata = metadata
            metadataNet.serverUrl = serverUrl
            
            // data crypto
            metadataNet.fileName = metadata.fileNameData
            metadataNet.selector = selectorDeleteCrypto
            
            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            
            // plist
            metadataNet.fileName = metadata.fileName;
            metadataNet.selector = selectorDeletePlist

            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            
        } else {
            
            metadataNet.action = actionDeleteFileDirectory
            metadataNet.delegate = delegate
            metadataNet.fileID = metadata.fileID
            metadataNet.fileName = metadata.fileName
            metadataNet.fileNamePrint = metadata.fileNamePrint
            metadataNet.metadata = metadata
            metadataNet.selector = selectorDelete
            metadataNet.serverUrl = serverUrl

            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
        }
    }
    
    func deleteFileOrFolderSuccess(_ metadataNet: CCMetadataNet) {
        
        CCCoreData.deleteFile(metadataNet.metadata, serverUrl: metadataNet.serverUrl, directoryUser: appDelegate.directoryUser, activeAccount: appDelegate.activeAccount)
        
        metadataNet.delegate?.deleteFileOrFolderSuccess(metadataNet)
    }
    
    func deleteFileOrFolderFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger) {
        
        if errorCode == 404 {
            
            CCCoreData.deleteFile(metadataNet.metadata, serverUrl: metadataNet.serverUrl, directoryUser: appDelegate.directoryUser, activeAccount: appDelegate.activeAccount)
        }

        if message.length > 0 {
            
            appDelegate.messageNotification("_delete_", description: message as String, visible: true, delay:TimeInterval(k_dismissAfterSecond), type:TWMessageBarMessageType.error, errorCode: errorCode)
        }
        
        metadataNet.delegate?.deleteFileOrFolderFailure(metadataNet, message: message, errorCode: errorCode)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Rename File or Folder
    // --------------------------------------------------------------------------------------------
    
    func renameFileOrFolder(_ metadata: CCMetadata, fileName: String, delegate: AnyObject) {

        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        let fileName = CCUtility.removeForbiddenCharactersServer(fileName)!
        
        let serverUrl = CCCoreData.getServerUrl(fromDirectoryID: metadata.directoryID, activeAccount: appDelegate.activeAccount)!
        
        if fileName.characters.count == 0 {
            return
        }
        
        if metadata.fileNamePrint == fileName {
            return
        }
        
        if metadata.cryptated {
            
            let crypto = CCCrypto.sharedManager() as! CCCrypto
            
            // Encrypted
            
            let newTitle = AESCrypt.encrypt(fileName, password: crypto.getKeyPasscode(metadata.uuid))
            
            if !crypto.updateTitleFilePlist(metadata.fileName, title: newTitle, directoryUser: appDelegate.directoryUser) {
                
                print("[LOG] Rename cryptated error \(fileName)")
                
                appDelegate.messageNotification("_rename_", description: "_file_not_found_reload_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
                
                return
            }
            
            if !metadata.directory {
                
                do {
                    
                    let file = "\(appDelegate.directoryUser!)/\(metadata.fileID!)"
                    let dataFile = try NSData.init(contentsOfFile: file, options:[])
                    
                    do {
                        
                        let dataFileEncrypted = try RNEncryptor.encryptData(dataFile as Data!, with: kRNCryptorAES256Settings, password: crypto.getKeyPasscode(metadata.uuid))
                        
                        do {
                            
                            let fileUrl = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(metadata.fileNameData!)")
                            try dataFileEncrypted.write(to: fileUrl, options: [])
                            
                        } catch let error {
                            print(error.localizedDescription)
                            return
                        }
                        
                    } catch let error {
                        print(error.localizedDescription)
                        return
                    }

                } catch let error {
                    print(error.localizedDescription)
                    return
                }
            }
            
            metadataNet.action = actionUploadOnlyPlist
            metadataNet.delegate = delegate
            metadataNet.fileName = metadata.fileName
            metadataNet.metadata = metadata
            metadataNet.selectorPost = selectorReadFolderForced
            metadataNet.serverUrl = serverUrl
            metadataNet.session = k_upload_session_foreground
            metadataNet.taskStatus = Int(k_taskStatusResume)
            
            if CCCoreData.isOfflineLocalFileID(metadata.fileID, activeAccount: appDelegate.activeAccount) {
                metadataNet.selectorPost = selectorAddOffline
            }
            
            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            
            // delete file in filesystem
            CCCoreData.deleteFile(metadata, serverUrl: serverUrl, directoryUser: appDelegate.directoryUser, activeAccount: appDelegate.activeAccount)
 
        } else {
 
            let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: appDelegate.activeUser, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl, isCryptoCloudMode: false);
            let error = ocNetworking?.readFileSync("\(serverUrl)/\(fileName)");
            
            // Verify if exists the fileName TO
            if error == nil {
                
                let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_file_already_exists_", comment: ""), preferredStyle: UIAlertControllerStyle.alert)
                
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) {
                    (result : UIAlertAction) -> Void in
                }
                
                alertController.addAction(okAction)
                
                delegate.present(alertController, animated: true, completion: nil)
                
                return;
            }
            
            // Plain
            
            metadataNet.action = actionMoveFileOrFolder
            metadataNet.delegate = delegate
            metadataNet.fileID = metadata.fileID
            metadataNet.fileName = metadata.fileName
            metadataNet.fileNamePrint = metadata.fileNamePrint
            metadataNet.fileNameTo = fileName
            metadataNet.metadata = metadata
            metadataNet.selector = selectorRename
            metadataNet.serverUrl = serverUrl
            metadataNet.serverUrlTo = serverUrl
            
            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
        }
    }
    
    func renameSuccess(_ metadataNet: CCMetadataNet) {
        
        if metadataNet.metadata.directory {
            
            let directory = CCUtility.stringAppendServerUrl(metadataNet.serverUrl, addFileName: metadataNet.fileName)
            let directoryTo = CCUtility.stringAppendServerUrl(metadataNet.serverUrl, addFileName: metadataNet.fileNameTo)

            CCCoreData.renameDirectory(directory, serverUrlTo: directoryTo, activeAccount: appDelegate.activeAccount)
            
        } else {
            
            CCCoreData.renameLocalFile(withFileID: metadataNet.metadata.fileID, fileNameTo: metadataNet.fileNameTo, fileNamePrintTo: metadataNet.fileNameTo, activeAccount: appDelegate.activeAccount)
        }
        
        metadataNet.delegate?.renameSuccess(metadataNet)
    }
    
    func renameMoveFileOrFolderFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger) {
        
        if message.length > 0 {
            
            var title : String = ""
            
            if metadataNet.selector == selectorRename {
                
                title = "_delete_"
            }
            
            if metadataNet.selector == selectorMove {
                
                title = "_move_"
            }
            
            appDelegate.messageNotification(title, description: message as String, visible: true, delay:TimeInterval(k_dismissAfterSecond), type:TWMessageBarMessageType.error, errorCode: errorCode)
        }
        
        metadataNet.delegate?.renameMoveFileOrFolderFailure(metadataNet, message: message as NSString, errorCode: errorCode)
    }
    
    func uploadFileSuccess(_ metadataNet: CCMetadataNet, fileID: String, serverUrl: String, selector: String, selectorPost: String) {
        
        metadataNet.delegate?.uploadFileSuccess(metadataNet, fileID:fileID, serverUrl: serverUrl, selector: selector, selectorPost: selectorPost)
    }
    
    func uploadFileFailure(_ metadataNet: CCMetadataNet, fileID: String, serverUrl: String, selector: String, message: String, errorCode: NSInteger) {
        
        metadataNet.delegate?.uploadFileFailure(metadataNet, fileID:fileID, serverUrl: serverUrl, selector: selector, message: message, errorCode: errorCode)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Search
    // --------------------------------------------------------------------------------------------
    
    func search(_ serverUrl : String, fileName : String, depth : String, delegate: AnyObject) {
        
        // Search DAV API
            
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
            
        metadataNet.action = actionSearch
        metadataNet.delegate = delegate
        metadataNet.fileName = fileName
        metadataNet.options = depth
        metadataNet.selector = selectorSearch
        metadataNet.serverUrl = serverUrl

        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    func searchSuccess(_ metadataNet: CCMetadataNet, metadatas: [CCMetadata]) {
        
        metadataNet.delegate?.searchSuccess(metadataNet, metadatas: metadatas)
    }
    
    func searchFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger) {
        
        metadataNet.delegate?.searchFailure(metadataNet, message: message, errorCode: errorCode)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Download Tumbnail
    // --------------------------------------------------------------------------------------------

    func downloadTumbnail(_ metadata: CCMetadata, delegate: AnyObject) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        let serverUrl = CCCoreData.getServerUrl(fromDirectoryID: metadata.directoryID, activeAccount: appDelegate.activeAccount)
        
        metadataNet.action = actionDownloadThumbnail
        metadataNet.delegate = delegate
        metadataNet.fileID = metadata.fileID
        metadataNet.fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: serverUrl, activeUrl: appDelegate.activeUrl)
        metadataNet.fileNameLocal = metadata.fileID
        metadataNet.fileNamePrint = metadata.fileNamePrint
        metadataNet.metadata = metadata
        metadataNet.options = "m"
        metadataNet.priority = Operation.QueuePriority.low.rawValue
        metadataNet.selector = selectorDownloadThumbnail;
        metadataNet.serverUrl = serverUrl;

        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }

    func downloadThumbnailSuccess(_ metadataNet: CCMetadataNet) {
        
        metadataNet.delegate?.downloadThumbnailSuccess(metadataNet)
    }
    
    func downloadThumbnailFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger) {
        
        NSLog("[LOG] Thumbnail Error \(metadataNet.fileName!) \(message) error %\(errorCode))")
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Setting Favorite
    // --------------------------------------------------------------------------------------------
    
    func settingFavorite(_ metadata: CCMetadata, favorite: Bool, delegate: AnyObject) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        let serverUrl = CCCoreData.getServerUrl(fromDirectoryID: metadata.directoryID, activeAccount: appDelegate.activeAccount)
        
        metadataNet.action = actionSettingFavorite
        metadataNet.delegate = delegate
        metadataNet.fileID = metadata.fileID
        metadataNet.fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: serverUrl, activeUrl: appDelegate.activeUrl)
        metadataNet.metadata = metadata
        metadataNet.options = "\(favorite)"
        metadataNet.priority = Operation.QueuePriority.normal.rawValue
        metadataNet.selector = selectorAddFavorite
        metadataNet.serverUrl = serverUrl;
        
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    func settingFavoriteSuccess(_ metadataNet: CCMetadataNet) {
        
        metadataNet.delegate?.settingFavoriteSuccess(metadataNet)
    }
    
    func settingFavoriteFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger) {
        
        appDelegate.messageNotification("_favorites_", description: message as String, visible: true, delay:TimeInterval(k_dismissAfterSecond), type:TWMessageBarMessageType.error, errorCode: errorCode)

        metadataNet.delegate?.settingFavoriteFailure(metadataNet, message: message, errorCode: errorCode)
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Linsting Favorites
    // --------------------------------------------------------------------------------------------
    
    func listingFavorites(_ serverUrl: String, delegate: AnyObject) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionListingFavorites
        metadataNet.delegate = delegate
        metadataNet.priority = Operation.QueuePriority.normal.rawValue
        metadataNet.serverUrl = serverUrl
        
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    func listingFavoritesSuccess(_ metadataNet: CCMetadataNet, metadatas: [CCMetadata]) {
        
        metadataNet.delegate?.listingFavoritesSuccess(metadataNet, metadatas: metadatas)
    }
    
    func listingFavoritesFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger) {
        
        metadataNet.delegate?.listingFavoritesFailure(metadataNet, message: message, errorCode: errorCode)
    }

}






