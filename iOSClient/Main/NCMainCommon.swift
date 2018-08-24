//
//  NCMainCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/07/18.
//  Copyright © 2018 TWS. All rights reserved.
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

class NCMainCommon: NSObject {
    
    @objc static let sharedInstance: NCMainCommon = {
        let instance = NCMainCommon()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK: -
    
    @objc func triggerProgressTask(_ notification: Notification, sectionDataSourceFileIDIndexPath: NSDictionary, tableView: UITableView) {
        
        guard let dic = notification.userInfo else {
            return
        }
        
        let fileID = dic["fileID"] as! NSString
        _ = dic["serverUrl"] as! NSString
        let status = dic["status"] as! Int
        let progress = dic["progress"] as! CGFloat
        let totalBytes = dic["totalBytes"] as! Double
        let totalBytesExpected = dic["totalBytesExpected"] as! Double
        
        appDelegate.listProgressMetadata.setObject([progress as NSNumber, totalBytes as NSNumber, totalBytesExpected as NSNumber], forKey: fileID)
        
        guard let indexPath = sectionDataSourceFileIDIndexPath.object(forKey: fileID) else {
            return
        }
        
        if isValidIndexPath(indexPath as! IndexPath, tableView: tableView) {
            
            if let cell = tableView.cellForRow(at: indexPath as! IndexPath) as? CCCellMainTransfer {
                
                var image = ""
                
                if status == k_metadataStatusInDownload {
                    image = "↓"
                } else if status == k_metadataStatusInUpload {
                    image = "↑"
                }
                
                cell.labelInfoFile.text = CCUtility.transformedSize(totalBytesExpected) + " - " + image + CCUtility.transformedSize(totalBytes)
                cell.transferButton.progress = progress
            }
        }
    }
    
    @objc func cancelTransferMetadata(_ metadata: tableMetadata, reloadDatasource: Bool) {
        
        var actionReloadDatasource = k_action_NULL
        
        if metadata.session.count == 0 {
            return
        }
        
        guard let session = CCNetworking.shared().getSessionfromSessionDescription(metadata.session) else {
            return
        }
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            return
        }
        
        // SESSION EXTENSION
        if metadata.session == k_download_session_extension || metadata.session == k_upload_session_extension {
            
            if (metadata.session == k_upload_session_extension) {
                
                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageFileID(metadata.fileID))
                } catch { }
                
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "fileID == %@", metadata.fileID), clearDateReadDirectoryID: metadata.directoryID)
                
                actionReloadDatasource = k_action_DEL
                
            } else {
                
                NCManageDatabase.sharedInstance.setMetadataSession("", sessionError: "", sessionSelector: "", sessionTaskIdentifier: Int(k_taskIdentifierDone), status: Int(k_metadataStatusNormal), predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
                
                actionReloadDatasource = k_action_MOD
            }
            
            self.reloadDatasource(ServerUrl: serverUrl, fileID: metadata.fileID, action: actionReloadDatasource)
            
            return
        }
        
        session.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) in
            
            var cancel = false
            
            // DOWNLOAD
            if metadata.session.count > 0 && metadata.session.contains("download") {
                for task in downloadTasks {
                    if task.taskIdentifier == metadata.sessionTaskIdentifier {
                        task.cancel()
                        cancel = true
                    }
                }
                if cancel == false {
                    NCManageDatabase.sharedInstance.setMetadataSession("", sessionError: "", sessionSelector: "", sessionTaskIdentifier: Int(k_taskIdentifierDone), status: Int(k_metadataStatusNormal), predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
                }
                actionReloadDatasource = k_action_MOD
            }
            
            // UPLOAD
            if metadata.session.count > 0 && metadata.session.contains("upload") {
                for task in uploadTasks {
                    if task.taskIdentifier == metadata.sessionTaskIdentifier {
                        task.cancel()
                        cancel = true
                    }
                }
                if cancel == false {
                    do {
                        try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageFileID(metadata.fileID))
                    }
                    catch { }
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "fileID == %@", metadata.fileID), clearDateReadDirectoryID: metadata.directoryID)
                }
                actionReloadDatasource = k_action_DEL
            }
            
            if cancel == false {
                self.reloadDatasource(ServerUrl: serverUrl, fileID: metadata.fileID, action: actionReloadDatasource)
            }
        }
    }
    
    @objc func cancelAllTransfer() {
        
        // Delete k_metadataStatusWaitUpload OR k_metadataStatusUploadError
        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND (status == %d OR status == %d)", appDelegate.activeAccount, k_metadataStatusWaitUpload, k_metadataStatusUploadError), clearDateReadDirectoryID: nil)
        
        if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND status != %d AND status != %d", appDelegate.activeAccount, k_metadataStatusNormal, k_metadataStatusHide), sorted: "fileName", ascending: true)  {
            
            for metadata in metadatas {
                
                // Modify
                if (metadata.status == k_metadataStatusWaitDownload || metadata.status == k_metadataStatusDownloadError) {
                    metadata.session = ""
                    metadata.sessionSelector = ""
                    metadata.status = Int(k_metadataStatusNormal)
                    
                    _ = NCManageDatabase.sharedInstance.addMetadata(metadata)
                }
                
                // Cancel Task
                if metadata.status == k_metadataStatusDownloading || metadata.status == k_metadataStatusUploading {
                    cancelTransferMetadata(metadata, reloadDatasource: false)
                }
            }
        }
        
        self.reloadDatasource(ServerUrl: nil, fileID: nil, action: k_action_NULL)
    }
    
    //MARK: -
    
    @objc func cellForRowAtIndexPath(_ indexPath: IndexPath, tableView: UITableView ,metadata: tableMetadata, metadataFolder: tableMetadata?, serverUrl: String, autoUploadFileName: String, autoUploadDirectory: String) -> UITableViewCell {
        
        // Create File System
        if metadata.directory {
            CCUtility.getDirectoryProviderStorageFileID(metadata.fileID)
        } else {
            CCUtility.getDirectoryProviderStorageFileID(metadata.fileID, fileNameView: metadata.fileNameView)
        }
        
        // CCCell
        if metadata.status == k_metadataStatusNormal {
            
            // NORMAL
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "CellMain", for: indexPath) as! CCCellMain
            cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0)
            cell.accessoryType = UITableViewCellAccessoryType.none
            cell.file.image = nil
            cell.status.image = nil
            cell.favorite.image = nil
            cell.shared.image = nil
            cell.local.image = nil
            cell.imageTitleSegue = nil
            cell.shared.isUserInteractionEnabled = false
            
            cell.backgroundColor = NCBrandColor.sharedInstance.backgroundView
            
            // change color selection
            let selectionColor = UIView()
            selectionColor.backgroundColor = NCBrandColor.sharedInstance.getColorSelectBackgrond()
            cell.selectedBackgroundView = selectionColor
            cell.tintColor = NCBrandColor.sharedInstance.brandElement
            
            cell.labelTitle.textColor = UIColor.black
            cell.labelTitle.text = metadata.fileNameView
            
            // Share
            let sharesLink = appDelegate.sharesLink.object(forKey: serverUrl + metadata.fileName)
            let sharesUserAndGroup = appDelegate.sharesUserAndGroup.object(forKey: serverUrl + metadata.fileName)
            var isShare = false
            var isMounted = false
            
            if metadataFolder != nil {
                isShare = metadata.permissions.contains(k_permission_shared) && !metadataFolder!.permissions.contains(k_permission_shared)
                isMounted = metadata.permissions.contains(k_permission_mounted) && !metadataFolder!.permissions.contains(k_permission_mounted)
            }
            
            if metadata.directory {
                
                // lable Info
                cell.labelInfoFile.text = CCUtility.dateDiff(metadata.date as Date)
                
                // File Image & Image Title Segue
                if metadata.e2eEncrypted {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderEncrypted"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "lock")
                } else if metadata.fileName == autoUploadFileName && serverUrl == autoUploadDirectory {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderMedia"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "media")
                } else if isShare {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_shared_with_me"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "share")
                } else if isMounted {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_external"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "shareMounted")
                } else if (sharesUserAndGroup != nil) {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_shared_with_me"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "share")
                } else if (sharesLink != nil) {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_public"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                    cell.imageTitleSegue = UIImage.init(named: "sharebylink")
                } else {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
                }
                
                // Image Status Lock Passcode
                let lockServerUrl = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)!
                let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.activeAccount, lockServerUrl))
                if tableDirectory != nil && tableDirectory!.lock && CCUtility.getBlockCode() != nil {
                    cell.status.image = UIImage.init(named: "passcode")
                }
                
            } else {
                
                let iconFileExists = FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileNameView))
                
                // Lable Info
                cell.labelInfoFile.text = CCUtility.dateDiff(metadata.date as Date) + " " + CCUtility.transformedSize(metadata.size)
                
                // File Image
                if iconFileExists {
                    cell.file.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileNameView))
                } else {
                    if metadata.iconName.count > 0 {
                        cell.file.image = UIImage.init(named: metadata.iconName)
                    } else {
                        cell.file.image = UIImage.init(named: "file")
                    }
                }
                
                // Local Image
                let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
                if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.fileID, fileNameView: metadata.fileNameView) {
                    cell.local.image = UIImage.init(named: "local")
                }
                
                // Status Image
                let tableE2eEncryption = NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNameIdentifier == %@", appDelegate.activeAccount, metadata.fileName))
                if tableE2eEncryption != nil &&  NCUtility.sharedInstance.isEncryptedMetadata(metadata) {
                    cell.status.image = UIImage.init(named: "encrypted")
                }
                
                // Share
                if (isShare) {
                    cell.shared.image =  CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
                } else if (isMounted) {
                    cell.shared.image =  CCGraphics.changeThemingColorImage(UIImage.init(named: "shareMounted"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
                } else if (sharesLink != nil) {
                    cell.shared.image =  CCGraphics.changeThemingColorImage(UIImage.init(named: "sharebylink"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
                } else if (sharesUserAndGroup != nil) {
                    cell.shared.image =  CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
                }
            }
            
            //
            // File & Directory
            //
            
            // Favorite
            if metadata.favorite {
                cell.favorite.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), multiplier: 2, color: NCBrandColor.sharedInstance.yellowFavorite)
            }
            
            // More Image
            cell.more.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
            
            return cell
            
        } else {
         
            // TRASNFER
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "CellMainTransfer", for: indexPath) as! CCCellMainTransfer
            cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0)
            cell.accessoryType = UITableViewCellAccessoryType.none
            cell.file.image = nil
            cell.status.image = nil
            
            cell.backgroundColor = NCBrandColor.sharedInstance.backgroundView

            cell.labelTitle.textColor = UIColor.black
            cell.labelTitle.text = metadata.fileNameView
            
            cell.transferButton.tintColor = NCBrandColor.sharedInstance.icon
            
            var progress: CGFloat = 0.0
            var totalBytes: Double = 0.0
            //var totalBytesExpected : Double = 0
            let progressArray = appDelegate.listProgressMetadata.object(forKey: metadata.fileID) as? NSArray
            if progressArray != nil && progressArray?.count == 3 {
                progress = progressArray?.object(at: 0) as! CGFloat
                totalBytes = progressArray?.object(at: 1) as! Double
                //totalBytesExpected = progressArray?.object(at: 2) as! Double
            }
            
            // Write status on Label Info
            switch metadata.status {
            case Int(k_metadataStatusWaitDownload):
                cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_download_", comment: "")
                progress = 0.0
                break
            case Int(k_metadataStatusInDownload):
                cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_download_", comment: "")
                progress = 0.0
                break
            case Int(k_metadataStatusDownloading):
                cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size) + " - ↓" + CCUtility.transformedSize(totalBytes)
                break
            case Int(k_metadataStatusWaitUpload):
                cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_wait_upload_", comment: "")
                progress = 0.0
                break
            case Int(k_metadataStatusInUpload):
                cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size) + " - " + NSLocalizedString("_status_in_upload_", comment: "")
                progress = 0.0
                break
            case Int(k_metadataStatusUploading):
                cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size) + " - ↑" + CCUtility.transformedSize(totalBytes)
                break
            default:
                cell.labelInfoFile.text = CCUtility.transformedSize(metadata.size)
                progress = 0.0
            }
            
            let iconFileExists = FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileNameView))

            if iconFileExists {
                cell.file.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(metadata.fileID, fileNameView: metadata.fileNameView))
            } else {
                if metadata.iconName.count > 0 {
                    cell.file.image = UIImage.init(named: metadata.iconName)
                } else {
                    cell.file.image = UIImage.init(named: "file")
                }
            }
            
            // Session Upload Extension
            if metadata.session == k_upload_session_extension && (metadata.status == k_metadataStatusInUpload || metadata.status == k_metadataStatusUploading) {
                
                cell.labelTitle.isEnabled = false
                cell.labelInfoFile.isEnabled = false
                
            } else {
                
                cell.labelTitle.isEnabled = true
                cell.labelInfoFile.isEnabled = true
            }
            
            // downloadFile
            if metadata.status == k_metadataStatusWaitDownload || metadata.status == k_metadataStatusInDownload || metadata.status == k_metadataStatusDownloading || metadata.status == k_metadataStatusDownloadError {
                //
            }
            
            // downloadFile Error
            if metadata.status == k_metadataStatusDownloadError {
                
                cell.status.image = UIImage.init(named: "statuserror")
                
                if metadata.sessionError.count == 0 {
                    cell.labelInfoFile.text = NSLocalizedString("_error_", comment: "") + ", " + NSLocalizedString("_file_not_downloaded_", comment: "")
                } else {
                    cell.labelInfoFile.text = metadata.sessionError
                }
            }
            
            // uploadFile
            if metadata.status == k_metadataStatusWaitUpload || metadata.status == k_metadataStatusInUpload || metadata.status == k_metadataStatusUploading || metadata.status == k_metadataStatusUploadError {
                
                if (!iconFileExists) {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "uploadCloud"), multiplier: 2, color: NCBrandColor.sharedInstance.brandElement)
                }
                
                cell.labelTitle.isEnabled = false
            }
            
            // uploadFileError
            if metadata.status == k_metadataStatusUploadError {
                
                cell.labelTitle.isEnabled = false
                cell.status.image = UIImage.init(named: "statuserror")
                
                if !iconFileExists {
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "uploadCloud"), multiplier: 2, color: NCBrandColor.sharedInstance.brandElement)
                }
                
                if metadata.sessionError.count == 0 {
                    cell.labelInfoFile.text = NSLocalizedString("_error_", comment: "") + ", " + NSLocalizedString("_file_not_uploaded_", comment: "")
                } else {
                    cell.labelInfoFile.text = metadata.sessionError
                }
            }
            
            // Progress
            cell.transferButton.progress = progress
            
            return cell
        }
    }
    
    @objc func getMetadataFromSectionDataSourceIndexPath(_ indexPath: IndexPath?, sectionDataSource: CCSectionDataSourceMetadata?) -> tableMetadata? {
        
        guard let indexPath = indexPath else {
            return nil
        }
        
        guard let sectionDataSource = sectionDataSource else {
            return nil
        }
        
        let section = indexPath.section + 1
        let row = indexPath.row + 1
        let totSections = sectionDataSource.sections.count
        
        if totSections < section || section > totSections {
            return nil
        }
        
        let valueSection = sectionDataSource.sections.object(at: indexPath.section)
        guard let filesID = sectionDataSource.sectionArrayRow.object(forKey: valueSection) as? NSArray else {
            return nil
        }
        
        let totRows = filesID.count
        if totRows < row || row > totRows {
            return nil
        }
        
        let fileID = filesID.object(at: indexPath.row)
        let metadata = sectionDataSource.allRecordsDataSource.object(forKey: fileID) as? tableMetadata
      
        return metadata
    }
    
    @objc func reloadDatasource(ServerUrl: String?, fileID: String?, action: Int32) {
        
        DispatchQueue.main.async {
            if self.appDelegate.activeMain != nil {
                self.appDelegate.activeMain.reloadDatasource(ServerUrl, fileID: fileID, action: Int(action))
            }
            if self.appDelegate.activeFavorites != nil {
                self.appDelegate.activeFavorites.reloadDatasource(fileID, action: Int(action))
            }
            if self.appDelegate.activeTransfers != nil {
                self.appDelegate.activeTransfers.reloadDatasource(fileID, action: Int(action))
            }
        }
    }
    
    @objc func isValidIndexPath(_ indexPath: IndexPath, tableView: UITableView) -> Bool {
        
        return indexPath.section < tableView.numberOfSections && indexPath.row < tableView.numberOfRows(inSection: indexPath.section)
    }
    
    //MARK: -
    
    @objc func deleteFile(metadatas: NSArray, e2ee: Bool, serverUrl: String, folderFileID: String, completion: @escaping (_ errorCode: Int, _ message: String)->()) {
        
        var copyMetadatas = [tableMetadata]()
        
        for metadata in metadatas {
            copyMetadatas.append(tableMetadata.init(value: metadata))
        }
        
        if e2ee {
            DispatchQueue.global().async {
                let error = NCNetworkingEndToEnd.sharedManager().lockFolderEncrypted(onServerUrl: serverUrl, fileID: folderFileID, user: self.appDelegate.activeUser, userID: self.appDelegate.activeUserID, password: self.appDelegate.activePassword, url: self.appDelegate.activeUrl)
                DispatchQueue.main.async {
                    if error == nil {
                        self.delete(metadatas: copyMetadatas, serverUrl:serverUrl, e2ee: e2ee, completion: completion)
                    } else {
                        self.appDelegate.messageNotification("_delete_", description: error?.localizedDescription, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
                        return
                    }
                }
            }
        } else {
            delete(metadatas: copyMetadatas, serverUrl:serverUrl, e2ee: e2ee, completion: completion)
        }
    }
    
    private func delete(metadatas: [tableMetadata], serverUrl: String, e2ee: Bool, completion: @escaping (_ errorCode: Int, _ message: String)->()) {
        
        var count: Int = 0
        var completionErrorCode: Int = 0
        var completionMessage = ""
        
        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        for metadata in metadatas {
            
            guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                continue
            }
            
            self.appDelegate.filterFileID.add(metadata.fileID)
            
            ocNetworking?.deleteFileOrFolder(metadata.fileName, serverUrl: serverUrl, completion: { (message, errorCode) in
                
                count += 1

                if errorCode == 0 || errorCode == 404 {
                    
                    do {
                        try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageFileID(metadata.fileID))
                    } catch { }
                    
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "fileID == %@", metadata.fileID), clearDateReadDirectoryID: metadata.directoryID)
                    NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
                    NCManageDatabase.sharedInstance.deletePhotos(fileID: metadata.fileID)
                    
                    if metadata.directory {
                        NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName))
                    }
                    
                    if (e2ee) {
                        NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, serverUrl, metadata.fileName))
                    }
                    
                } else {
                    
                    self.appDelegate.filterFileID.remove(metadata.fileID)
                    
                    completionErrorCode = errorCode
                    completionMessage = ""
                    if message != nil {
                        completionMessage = message!
                    }
                }
                
                if count == metadatas.count {
                    if e2ee {
                        DispatchQueue.global().async {
                            NCNetworkingEndToEnd.sharedManager().rebuildAndSendMetadata(onServerUrl: serverUrl, account: self.appDelegate.activeAccount, user: self.appDelegate.activeUser, userID: self.appDelegate.activeUserID, password: self.appDelegate.activePassword, url: self.appDelegate.activeUrl)
                            DispatchQueue.main.async {
                                completion(completionErrorCode, completionMessage)
                            }
                        }
                    } else {
                        completion(completionErrorCode, completionMessage)
                    }
                }
            })
        }
        
        self.reloadDatasource(ServerUrl: serverUrl, fileID: nil, action: k_action_NULL)
        self.appDelegate.activeMedia.reloadDatasource(nil, action: Int(k_action_NULL))
    }
}
    
//MARK: -

class CCMainTabBarController : UITabBarController, UITabBarControllerDelegate {
        
    override func viewDidLoad() {
            
        super.viewDidLoad()
        delegate = self
    }
        
    //Delegate methods
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            
        let tabViewControllers = tabBarController.viewControllers!
        guard let toIndex = tabViewControllers.index(of: viewController) else {
                
            if let vc = viewController as? UINavigationController {
                vc.popToRootViewController(animated: true);
            }
                
            return false
        }
            
        animateToTab(toIndex: toIndex)
            
        return true
    }
        
    func animateToTab(toIndex: Int) {
            
        let tabViewControllers = viewControllers!
        let fromView = selectedViewController!.view!
        let toView = tabViewControllers[toIndex].view!
        let fromIndex = tabViewControllers.index(of: selectedViewController!)
            
        guard fromIndex != toIndex else {return}
            
        // Add the toView to the tab bar view
        fromView.superview?.addSubview(toView)
        fromView.superview?.backgroundColor = UIColor.white
            
        // Position toView off screen (to the left/right of fromView)
        let screenWidth = UIScreen.main.bounds.size.width;
        let scrollRight = toIndex > fromIndex!;
        let offset = (scrollRight ? screenWidth : -screenWidth)
        toView.center = CGPoint(x: (fromView.center.x) + offset, y: (toView.center.y))
            
        // Disable interaction during animation
        view.isUserInteractionEnabled = false
            
        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                
            // Slide the views by -offset
            fromView.center = CGPoint(x: fromView.center.x - offset, y: fromView.center.y);
            toView.center   = CGPoint(x: toView.center.x - offset, y: toView.center.y);
                
        }, completion: { finished in
                
            // Remove the old view from the tabbar view.
            fromView.removeFromSuperview()
            self.selectedIndex = toIndex
            self.view.isUserInteractionEnabled = true
        })
    }
}

//
// https://stackoverflow.com/questions/44822558/ios-11-uitabbar-uitabbaritem-positioning-issue/46348796#46348796
//
extension UITabBar {
    // Workaround for iOS 11's new UITabBar behavior where on iPad, the UITabBar inside
    // the Master view controller shows the UITabBarItem icon next to the text
    override open var traitCollection: UITraitCollection {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return UITraitCollection(horizontalSizeClass: .compact)
        }
        return super.traitCollection
    }
}

//MARK: -

class NCNetworkingMain: NSObject, CCNetworkingDelegate {

    @objc static let sharedInstance: NCNetworkingMain = {
        let instance = NCNetworkingMain()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    // DOWNLOAD
    func downloadStart(_ fileID: String!, account: String!, task: URLSessionDownloadTask!, serverUrl: String!) {
        NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, fileID: fileID, action: Int32(k_action_MOD))
        appDelegate.updateApplicationIconBadgeNumber()
    }
    
    func downloadFileSuccessFailure(_ fileName: String!, fileID: String!, serverUrl: String!, selector: String!, errorMessage: String!, errorCode: Int) {
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileID)) else {
            return
        }
        
        if errorCode == 0 {
            
            NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, fileID: fileID, action: Int32(k_action_MOD))
            
            // Synchronized
            if selector == selectorDownloadSynchronize {
                //
            }
            
            // open View File
            if selector == selectorLoadFileView && UIApplication.shared.applicationState == UIApplicationState.active {
            
                if metadata.typeFile == k_metadataTypeFile_compress || metadata.typeFile == k_metadataTypeFile_unknown {
                
                    if appDelegate.activeMain.view.window != nil {
                        appDelegate.activeMain.open(in: metadata)
                    }
                    if appDelegate.activeFavorites.view.window != nil {
                        appDelegate.activeFavorites.open(in: metadata)
                    }
                    
                } else {
                    
                    if appDelegate.activeMain.view.window != nil {
                        appDelegate.activeMain.metadata = metadata;
                        appDelegate.activeMain.shouldPerformSegue()
                    }
                    if appDelegate.activeFavorites.view.window != nil {
                        appDelegate.activeFavorites.metadata = metadata;
                        appDelegate.activeFavorites.shouldPerformSegue()
                    }
                }
            }
            
            // Open in...
            if selector == selectorOpenIn && UIApplication.shared.applicationState == UIApplicationState.active {

                if appDelegate.activeMain.view.window != nil {
                    appDelegate.activeMain.open(in: metadata)
                }
                if appDelegate.activeFavorites.view.window != nil {
                    appDelegate.activeFavorites.open(in: metadata)
                }
            }
            
            // Save to Photo Album
            if selector == selectorSave {
                
                appDelegate.activeMain.save(toPhotoAlbum: metadata)
            }
            
            // Copy File
            if selector == selectorLoadCopy {
                
                appDelegate.activeMain.copyFile(toPasteboard: metadata)
            }
            
            //selectorLoadViewImage
            if selector == selectorLoadViewImage {
                
                if appDelegate.activeDetail != nil {
                    appDelegate.activeDetail.downloadPhotoBrowserSuccessFailure(metadata, selector: selector, errorCode: errorCode)
                }
                if appDelegate.activeMedia != nil {
                    appDelegate.activeMedia.downloadFileSuccessFailure(metadata.fileName, fileID: metadata.fileID, serverUrl: serverUrl, selector: selector, errorMessage: errorMessage, errorCode: errorCode)
                }
            }
            
            self.appDelegate.performSelector(onMainThread: #selector(self.appDelegate.loadAutoDownloadUpload), with: nil, waitUntilDone: true)
            
        } else {
            
            // File do not exists on server, remove in local
            if (errorCode == kOCErrorServerPathNotFound || errorCode == -1011) { // - 1011 = kCFURLErrorBadServerResponse
                
                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageFileID(metadata.fileID))
                } catch { }
                
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "fileID == %@", metadata.fileID), clearDateReadDirectoryID: metadata.directoryID)
                NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
                NCManageDatabase.sharedInstance.deletePhotos(fileID: fileID)
                
                NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, fileID: fileID, action: Int32(k_action_DEL))
            }
            
            if selector == selectorLoadViewImage {
                
                if appDelegate.activeDetail.view.window != nil {
                    appDelegate.activeDetail.downloadPhotoBrowserSuccessFailure(metadata, selector: selector, errorCode: errorCode)
                }
                if appDelegate.activeMedia.view.window != nil {
                    appDelegate.activeMedia.downloadFileSuccessFailure(metadata.fileName, fileID: metadata.fileID, serverUrl: serverUrl, selector: selector, errorMessage: errorMessage, errorCode: errorCode)
                }
                
                NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, fileID: fileID, action: Int32(k_action_MOD))
            }
        }       
    }
    
    // UPLOAD
    
    func uploadStart(_ fileID: String!, account: String!, task: URLSessionUploadTask!, serverUrl: String!) {
        NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, fileID: fileID, action: Int32(k_action_MOD))
        appDelegate.updateApplicationIconBadgeNumber()
    }
    
    func uploadFileSuccessFailure(_ fileName: String!, fileID: String!, assetLocalIdentifier: String!, serverUrl: String!, selector: String!, errorMessage: String!, errorCode: Int) {
        
        NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, fileID: fileID, action: Int32(k_action_MOD))
        
        if errorCode == 0 {
            self.appDelegate.performSelector(onMainThread: #selector(self.appDelegate.loadAutoDownloadUpload), with: nil, waitUntilDone: true)
        } else {
            NCManageDatabase.sharedInstance.addActivityClient(fileName, fileID: assetLocalIdentifier, action: k_activityDebugActionUpload, selector: selector, note: errorMessage, type: k_activityTypeFailure, verbose: false, activeUrl: appDelegate.activeUrl)
            
            if errorCode != -999 && errorCode != kOCErrorServerUnauthorized && errorMessage != "" {
                appDelegate.messageNotification("_upload_file_", description: errorMessage, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            }
        }
    }
}




