//
//  NCMainCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/07/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
import TLPhotoPicker
import ZIPFoundation
import NCCommunication

//MARK: - Main Common

class NCMainCommon: NSObject, PhotoEditorDelegate, NCAudioRecorderViewControllerDelegate, UIDocumentInteractionControllerDelegate {
    
    @objc static let sharedInstance: NCMainCommon = {
        let instance = NCMainCommon()
        instance.createImagesThemingColor()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadataEditPhoto: tableMetadata?
    var docController: UIDocumentInteractionController?

    lazy var operationQueueReloadDatasource: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Reload main datasource queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    //MARK: -
    
    struct NCMainCommonImages {
        static var cellSharedImage = UIImage()
        static var cellCanShareImage = UIImage()
        static var cellShareByLinkImage = UIImage()
        static var cellFavouriteImage = UIImage()
        static var cellMoreImage = UIImage()
        static var cellCommentImage = UIImage()
        
        static var cellFolderEncryptedImage = UIImage()
        static var cellFolderSharedWithMeImage = UIImage()
        static var cellFolderPublicImage = UIImage()
        static var cellFolderGroupImage = UIImage()
        static var cellFolderExternalImage = UIImage()
        static var cellFolderAutomaticUploadImage = UIImage()
        static var cellFolderImage = UIImage()
    }
    
    @objc func createImagesThemingColor() {
        NCMainCommonImages.cellSharedImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 100, height: 100, color: NCBrandColor.sharedInstance.textView)
        NCMainCommonImages.cellCanShareImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 100, height: 100, color: NCBrandColor.sharedInstance.graySoft)
        NCMainCommonImages.cellShareByLinkImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "sharebylink"), width: 100, height: 100, color: NCBrandColor.sharedInstance.textView)
        NCMainCommonImages.cellFavouriteImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 100, height: 100, color: NCBrandColor.sharedInstance.yellowFavorite)
        NCMainCommonImages.cellMoreImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.optionItem)
        NCMainCommonImages.cellCommentImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "comment"), width: 30, height: 30, color: NCBrandColor.sharedInstance.graySoft)
        
        NCMainCommonImages.cellFolderEncryptedImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderEncrypted"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderSharedWithMeImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_shared_with_me"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderPublicImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_public"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderGroupImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_group"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderExternalImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_external"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderAutomaticUploadImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderAutomaticUpload"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
    }
    
    //MARK: -
    
    @objc func triggerProgressTask(_ notification: Notification, sectionDataSourceocIdIndexPath: NSDictionary, tableView: UITableView, viewController: UIViewController, serverUrlViewController: String?) {
        
        if viewController.viewIfLoaded?.window == nil {
            return
        }
        
        guard let dic = notification.userInfo else {
            return
        }
        
        let account = dic["account"] as? NSString ?? ""
        let ocId = dic["ocId"] as? NSString ?? ""
        let serverUrl = dic["serverUrl"] as? String ?? ""
        let status = dic["status"] as? Int ?? Int(k_taskIdentifierDone)
        let progress = dic["progress"] as? CGFloat ?? 0
        let totalBytes = dic["totalBytes"] as? Double ?? 0
        let totalBytesExpected = dic["totalBytesExpected"] as? Double ?? 0
        
        if (account != self.appDelegate.activeAccount! as NSString) && !(viewController is CCTransfers) {
            return
        }
        
        if serverUrlViewController != nil && serverUrlViewController! != serverUrl {
            return
        }
        
        appDelegate.listProgressMetadata.setObject([progress as NSNumber, totalBytes as NSNumber, totalBytesExpected as NSNumber], forKey: ocId)
        
        guard let indexPath = sectionDataSourceocIdIndexPath.object(forKey: ocId) else {
            return
        }
        
        if isValidIndexPath(indexPath as! IndexPath, view: tableView) {
            
            if let cell = tableView.cellForRow(at: indexPath as! IndexPath) as? CCCellMainTransfer {
                
                var image = ""
                
                if status == k_metadataStatusInDownload {
                    image = "↓"
                } else if status == k_metadataStatusInUpload {
                    image = "↑"
                }
                
                cell.labelInfoFile?.text = CCUtility.transformedSize(totalBytesExpected) + " - " + image + CCUtility.transformedSize(totalBytes)
                cell.transferButton?.progress = progress
            }
        }
    }
    
    @objc func cancelTransferMetadata(_ metadata: tableMetadata, reloadDatasource: Bool, uploadStatusForcedStart: Bool) {
        
        var actionReloadDatasource = k_action_NULL
        var metadata = metadata
        
        if metadata.session.count == 0 { return }
        guard let session = CCNetworking.shared().getSessionfromSessionDescription(metadata.session) else { return }
        
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
                    NCManageDatabase.sharedInstance.setMetadataSession("", sessionError: "", sessionSelector: "", sessionTaskIdentifier: Int(k_taskIdentifierDone), status: Int(k_metadataStatusNormal), predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                }
                actionReloadDatasource = k_action_MOD
            }
            
            // UPLOAD
            if metadata.session.count > 0 && metadata.session.contains("upload") {
                for task in uploadTasks {
                    if task.taskIdentifier == metadata.sessionTaskIdentifier {
                        if uploadStatusForcedStart {
                            metadata.status = Int(k_metadataStatusUploadForcedStart)
                            metadata = NCManageDatabase.sharedInstance.addMetadata(metadata) ?? metadata
                        }
                        task.cancel()
                        cancel = true
                    }
                }
                if cancel == false {
                    do {
                        try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                    }
                    catch { }
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                }
                actionReloadDatasource = k_action_DEL
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.reloadDatasource(ServerUrl: metadata.serverUrl, ocId: metadata.ocId, action: actionReloadDatasource)
            }
        }
    }
    
    @objc func cancelAllTransfer() {
        
        // Delete k_metadataStatusWaitUpload OR k_metadataStatusUploadError
        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "status == %d OR status == %d", appDelegate.activeAccount, k_metadataStatusWaitUpload, k_metadataStatusUploadError))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "status != %d AND status != %d", k_metadataStatusNormal, k_metadataStatusHide), sorted: "fileName", ascending: true)  {
                
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
                        self.cancelTransferMetadata(metadata, reloadDatasource: false, uploadStatusForcedStart: false)
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            return
        }
    }
    
    //MARK: -
    
    func collectionViewCellForItemAt(_ indexPath: IndexPath, collectionView: UICollectionView, cell: UICollectionViewCell, metadata: tableMetadata, metadataFolder: tableMetadata?, serverUrl: String, isEditMode: Bool, selectocId: [String], autoUploadFileName: String, autoUploadDirectory: String, hideButtonMore: Bool, downloadThumbnail: Bool, shares: [tableShare]?, source: UIViewController) {
        
        var tableShare: tableShare?
        
        // Share
        if shares != nil {
            for share in shares! {
                if share.fileName == metadata.fileName {
                    tableShare = share
                    break
                }
            }
        }
        
        // Download preview
        if downloadThumbnail {
            NCNetworkingMain.sharedInstance.downloadThumbnail(with: metadata, view: collectionView, indexPath: indexPath)
        }
        
        var isShare = false
        var isMounted = false
        
        if metadataFolder != nil {
            isShare = metadata.permissions.contains(k_permission_shared) && !metadataFolder!.permissions.contains(k_permission_shared)
            isMounted = metadata.permissions.contains(k_permission_mounted) && !metadataFolder!.permissions.contains(k_permission_mounted)
        }
        
        if cell is NCListCell {
            
            let cell = cell as! NCListCell
           
            cell.delegate = source as? NCListCellDelegate
            
            cell.objectId = metadata.ocId
            cell.indexPath = indexPath
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
            cell.imageStatus.image = nil
            cell.imageLocal.image = nil
            cell.imageFavorite.image = nil
            cell.shared.image = nil
            
            if metadata.directory {
                
                if metadata.e2eEncrypted {
                    cell.imageItem.image = NCMainCommonImages.cellFolderEncryptedImage
                } else if isShare {
                    cell.imageItem.image = NCMainCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType != Int(shareTypeLink.rawValue)) {
                    cell.imageItem.image = NCMainCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType == Int(shareTypeLink.rawValue)) {
                    cell.imageItem.image = NCMainCommonImages.cellFolderPublicImage
                } else if metadata.mountType == "group" {
                    cell.imageItem.image = NCMainCommonImages.cellFolderGroupImage
                } else if isMounted {
                    cell.imageItem.image = NCMainCommonImages.cellFolderExternalImage
                } else if metadata.fileName == autoUploadFileName && serverUrl == autoUploadDirectory {
                    cell.imageItem.image = NCMainCommonImages.cellFolderAutomaticUploadImage
                } else {
                    cell.imageItem.image = NCMainCommonImages.cellFolderImage
                }
                
                cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date)
                
                let lockServerUrl = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)!
                let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.activeAccount, lockServerUrl))
                
                // Status image: passcode
                if tableDirectory != nil && tableDirectory!.lock && CCUtility.getBlockCode() != nil {
                    cell.imageStatus.image = UIImage.init(named: "passcode")
                }
                
                // Local image: offline
                if tableDirectory != nil && tableDirectory!.offline {
                    cell.imageLocal.image = UIImage.init(named: "offlineFlag")
                }
                
            } else {
                
                if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileName)) {
                    NCUtility.sharedInstance.loadImage(ocId: metadata.ocId, fileNameView: metadata.fileNameView) { (image) in
                        cell.imageItem.image = image
                    }
                } else {
                    if metadata.iconName.count > 0 {
                        cell.imageItem.image = UIImage.init(named: metadata.iconName)
                    } else {
                        cell.imageItem.image = UIImage.init(named: "file")
                    }
                }
                
                cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date) + ", " + CCUtility.transformedSize(metadata.size)
                
                // image Local
                let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    if tableLocalFile!.offline { cell.imageLocal.image = UIImage.init(named: "offlineFlag") }
                    else { cell.imageLocal.image = UIImage.init(named: "local") }
                }
            }
            
            // image Favorite
            if metadata.favorite {
                cell.imageFavorite.image = NCMainCommonImages.cellFavouriteImage
            }
            
            // Share image
            if (isShare) {
                cell.shared.image = NCMainCommonImages.cellSharedImage
            } else if (tableShare != nil && tableShare!.shareType == Int(shareTypeLink.rawValue)) {
                cell.shared.image = NCMainCommonImages.cellShareByLinkImage
            } else if (tableShare != nil && tableShare!.shareType != Int(shareTypeLink.rawValue)) {
                cell.shared.image = NCMainCommonImages.cellSharedImage
            } else {
                cell.shared.image = NCMainCommonImages.cellCanShareImage
            }
            if metadata.ownerId != appDelegate.activeUserID {
                // Load avatar
                let fileNameSource = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-" + metadata.ownerId + ".png"
                let fileNameSourceAvatar = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-avatar-" + metadata.ownerId + ".png"
                if FileManager.default.fileExists(atPath: fileNameSourceAvatar) {
                    cell.shared.image = UIImage(contentsOfFile: fileNameSourceAvatar)
                } else if FileManager.default.fileExists(atPath: fileNameSource) {
                    cell.shared.image = NCUtility.sharedInstance.createAvatar(fileNameSource: fileNameSource, fileNameSourceAvatar: fileNameSourceAvatar)
                } else {
                    NCCommunication.sharedInstance.downloadAvatar(urlString: appDelegate.activeUrl, userID: metadata.ownerId, fileNameLocalPath: fileNameSource, size: Int(k_avatar_size), account: appDelegate.activeAccount) { (account, data, errorCode, errorMessage) in
                        if errorCode == 0 && account == self.appDelegate.activeAccount {
                            cell.shared.image = NCUtility.sharedInstance.createAvatar(fileNameSource: fileNameSource, fileNameSourceAvatar: fileNameSourceAvatar)
                        }
                    }
                }
            }
            
            if isEditMode {
                cell.imageItemLeftConstraint.constant = 45
                cell.imageSelect.isHidden = false
                
                if selectocId.contains(metadata.ocId) {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = NCUtility.sharedInstance.cellBlurEffect(with: cell.bounds)
                } else {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedNo"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = nil
                }
            } else {
                cell.imageItemLeftConstraint.constant = 10
                cell.imageSelect.isHidden = true
                cell.backgroundView = nil
            }
            
            // Remove last separator
            if collectionView.numberOfItems(inSection: indexPath.section) == indexPath.row + 1 {
                cell.separator.isHidden = true
            } else {
                cell.separator.isHidden = false
            }
            
        } else if cell is NCGridCell {
            
            let cell = cell as! NCGridCell

            cell.delegate = source as? NCGridCellDelegate
            
            cell.objectId = metadata.ocId
            cell.indexPath = indexPath
            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
            cell.imageStatus.image = nil
            cell.imageLocal.image = nil
            cell.imageFavorite.image = nil
            
            if metadata.directory {
                
                if metadata.e2eEncrypted {
                    cell.imageItem.image = NCMainCommonImages.cellFolderEncryptedImage
                } else if isShare {
                    cell.imageItem.image = NCMainCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType != Int(shareTypeLink.rawValue)) {
                    cell.imageItem.image = NCMainCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType == Int(shareTypeLink.rawValue)) {
                    cell.imageItem.image = NCMainCommonImages.cellFolderPublicImage
                } else if metadata.mountType == "group" {
                    cell.imageItem.image = NCMainCommonImages.cellFolderGroupImage
                } else if isMounted {
                    cell.imageItem.image = NCMainCommonImages.cellFolderExternalImage
                } else if metadata.fileName == autoUploadFileName && serverUrl == autoUploadDirectory {
                    cell.imageItem.image = NCMainCommonImages.cellFolderAutomaticUploadImage
                } else {
                    cell.imageItem.image = NCMainCommonImages.cellFolderImage
                }
                
    
                let lockServerUrl = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)!
                let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.activeAccount, lockServerUrl))
                
                // Status image: passcode
                if tableDirectory != nil && tableDirectory!.lock && CCUtility.getBlockCode() != nil {
                    cell.imageStatus.image = UIImage.init(named: "passcode")
                }
                
                // Local image: offline
                if tableDirectory != nil && tableDirectory!.offline {
                    cell.imageLocal.image = UIImage.init(named: "offlineFlag")
                }
                
            } else {
                
                if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileName)) {
                    NCUtility.sharedInstance.loadImage(ocId: metadata.ocId, fileNameView: metadata.fileNameView) { (image) in
                        cell.imageItem.image = image
                    }
                } else {
                    if metadata.iconName.count > 0 {
                        cell.imageItem.image = UIImage.init(named: metadata.iconName)
                    } else {
                        cell.imageItem.image = UIImage.init(named: "file")
                    }
                }
                
                // image Local
                let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    if tableLocalFile!.offline { cell.imageLocal.image = UIImage.init(named: "offlineFlag") }
                    else { cell.imageLocal.image = UIImage.init(named: "local") }
                }
            }
            
            // image Favorite
            if metadata.favorite {
                cell.imageFavorite.image = NCMainCommonImages.cellFavouriteImage
            }
            
            if isEditMode {
                cell.imageSelect.isHidden = false
                if selectocId.contains(metadata.ocId) {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = NCUtility.sharedInstance.cellBlurEffect(with: cell.bounds)
                } else {
                    cell.imageSelect.isHidden = true
                    cell.backgroundView = nil
                }
            } else {
                cell.imageSelect.isHidden = true
                cell.backgroundView = nil
            }
            
        } else if cell is NCGridMediaCell {
            
            let cell = cell as! NCGridMediaCell
            
            cell.imageStatus.image = nil
            cell.imageLocal.image = nil
            cell.imageFavorite.image = nil
            
            if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileName)) {
                cell.imageItem.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileName))
//                NCUtility.sharedInstance.loadImage(ocId: metadata.ocId, fileNameView: metadata.fileNameView) { (image) in
//                    cell.imageItem.image = image
//                }
            } else {
                if metadata.iconName.count > 0 {
                    cell.imageItem.image = UIImage.init(named: metadata.iconName)
                } else {
                    cell.imageItem.image = UIImage.init(named: "file")
                }
            }
            
            // image Local
            let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                if tableLocalFile!.offline { cell.imageLocal.image = UIImage.init(named: "offlineFlag") }
                else { cell.imageLocal.image = UIImage.init(named: "local") }
            }
            
            // image Favorite
            if metadata.favorite {
                cell.imageFavorite.image = NCMainCommonImages.cellFavouriteImage
            }
            
            if isEditMode {
                cell.imageSelect.isHidden = false
                if selectocId.contains(metadata.ocId) {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.imageVisualEffect.isHidden = false
                    cell.imageVisualEffect.alpha = 0.4
                } else {
                    cell.imageSelect.isHidden = true
                    cell.imageVisualEffect.isHidden = true
                }
            } else {
                cell.imageSelect.isHidden = true
                cell.imageVisualEffect.isHidden = true
            }
        }
    }
    
    @objc func cellForRowAtIndexPath(_ indexPath: IndexPath, tableView: UITableView ,metadata: tableMetadata, metadataFolder: tableMetadata?, serverUrl: String, autoUploadFileName: String, autoUploadDirectory: String, tableShare: tableShare?) -> UITableViewCell {
        
        // Create File System
        if metadata.directory {
            CCUtility.getDirectoryProviderStorageOcId(metadata.ocId)
        } else {
            CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
        }
        
        // CCCell
        if metadata.status == k_metadataStatusNormal {
            
            // NORMAL
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "CellMain", for: indexPath) as! CCCellMain
            cell.separatorInset = UIEdgeInsets.init(top: 0, left: 60, bottom: 0, right: 0)
            cell.accessoryType = UITableViewCell.AccessoryType.none
            cell.file.image = nil
            cell.status.image = nil
            cell.favorite.image = nil
            cell.shared.image = nil
            cell.local.image = nil
            cell.comment.image = nil
            cell.shared.isUserInteractionEnabled = false
            cell.viewShared.backgroundColor = NCBrandColor.sharedInstance.backgroundView
            cell.backgroundColor = NCBrandColor.sharedInstance.backgroundView
            
            // change color selection
            let selectionColor = UIView()
            selectionColor.backgroundColor = NCBrandColor.sharedInstance.select
            cell.selectedBackgroundView = selectionColor
            cell.tintColor = NCBrandColor.sharedInstance.brandElement
            
            cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
            cell.labelTitle.text = metadata.fileNameView
            
            // Download preview
            NCNetworkingMain.sharedInstance.downloadThumbnail(with: metadata, view: tableView, indexPath: indexPath)
            
            // Share
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
                    cell.file.image = NCMainCommonImages.cellFolderEncryptedImage
                } else if isShare {
                    cell.file.image = NCMainCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType != Int(shareTypeLink.rawValue)) {
                    cell.file.image = NCMainCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType == Int(shareTypeLink.rawValue)) {
                    cell.file.image = NCMainCommonImages.cellFolderPublicImage
                } else if metadata.mountType == "group" {
                    cell.file.image = NCMainCommonImages.cellFolderGroupImage
                } else if isMounted {
                    cell.file.image = NCMainCommonImages.cellFolderExternalImage
                } else if metadata.fileName == autoUploadFileName && serverUrl == autoUploadDirectory {
                    cell.file.image = NCMainCommonImages.cellFolderAutomaticUploadImage
                } else {
                    cell.file.image = NCMainCommonImages.cellFolderImage
                }
                
                let lockServerUrl = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)!
                let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.activeAccount, lockServerUrl))
                // Local image: offline
                if tableDirectory != nil && tableDirectory!.offline {
                    cell.local.image = UIImage.init(named: "offlineFlag")
                }
                // Status image: passcode
                if tableDirectory != nil && tableDirectory!.lock && CCUtility.getBlockCode() != nil {
                    cell.status.image = UIImage.init(named: "passcode")
                }
                
            } else {
                
                let iconFileExists = FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView))
                
                // Lable Info
                cell.labelInfoFile.text = CCUtility.dateDiff(metadata.date as Date) + ", " + CCUtility.transformedSize(metadata.size)
                
                // File Image
                if iconFileExists {
                    NCUtility.sharedInstance.loadImage(ocId: metadata.ocId, fileNameView: metadata.fileNameView) { (image) in
                        cell.file.image = image
                    }
                } else {
                    if metadata.iconName.count > 0 {
                        cell.file.image = UIImage.init(named: metadata.iconName)
                    } else {
                        cell.file.image = UIImage.init(named: "file")
                    }
                }
                
                // Local Image - Offline
                let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    if tableLocalFile!.offline { cell.local.image = UIImage.init(named: "offlineFlag") }
                    else { cell.local.image = UIImage.init(named: "local") }
                }
                
                // Status image: encrypted
                let tableE2eEncryption = NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNameIdentifier == %@", appDelegate.activeAccount, metadata.fileName))
                if tableE2eEncryption != nil &&  NCUtility.sharedInstance.isEncryptedMetadata(metadata) {
                    cell.status.image = UIImage.init(named: "encrypted")
                }
            }
            
            //
            // File & Directory
            //
            
            // Favorite
            if metadata.favorite {
                cell.favorite.image = NCMainCommonImages.cellFavouriteImage
            }
            
            // Share image
            if (isShare) {
                cell.shared.image = NCMainCommonImages.cellSharedImage
            } else if (tableShare != nil && tableShare!.shareType == Int(shareTypeLink.rawValue)) {
                cell.shared.image = NCMainCommonImages.cellShareByLinkImage
            } else if (tableShare != nil && tableShare!.shareType != Int(shareTypeLink.rawValue)) {
                cell.shared.image = NCMainCommonImages.cellSharedImage
            } else {
                cell.shared.image = NCMainCommonImages.cellCanShareImage
            }
            if metadata.ownerId != appDelegate.activeUserID {
                // Load avatar
                let fileNameSource = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-" + metadata.ownerId + ".png"
                let fileNameSourceAvatar = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-avatar-" + metadata.ownerId + ".png"
                if FileManager.default.fileExists(atPath: fileNameSourceAvatar) {
                    if let avatar = UIImage(contentsOfFile: fileNameSourceAvatar) {
                        cell.shared.image = avatar
                    }
                } else if FileManager.default.fileExists(atPath: fileNameSource) {
                    if let avatar = NCUtility.sharedInstance.createAvatar(fileNameSource: fileNameSource, fileNameSourceAvatar: fileNameSourceAvatar) {
                        cell.shared.image = avatar
                    }
                } else {
                    NCCommunication.sharedInstance.downloadAvatar(urlString: appDelegate.activeUrl, userID: metadata.ownerId, fileNameLocalPath: fileNameSource, size: Int(k_avatar_size), account: appDelegate.activeAccount) { (account, data, errorCode, errorMessage) in
                        if errorCode == 0 && account == self.appDelegate.activeAccount {
                            cell.shared.image = NCUtility.sharedInstance.createAvatar(fileNameSource: fileNameSource, fileNameSourceAvatar: fileNameSourceAvatar)
                        }
                    }
                }
            }
            
            // Comment
            if metadata.commentsUnread {
                cell.comment.image = NCMainCommonImages.cellCommentImage
                cell.labelTitleTrailingConstraint.constant = 160
            } else {
                cell.labelTitleTrailingConstraint.constant = 110
            }
            
            // More Image
            cell.more.image = NCMainCommonImages.cellMoreImage
            
            return cell
            
        } else {
         
            // TRASNFER
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "CellMainTransfer", for: indexPath) as! CCCellMainTransfer
            cell.separatorInset = UIEdgeInsets.init(top: 0, left: 60, bottom: 0, right: 0)
            cell.accessoryType = UITableViewCell.AccessoryType.none
            cell.file.image = nil
            cell.status.image = nil
            cell.user.image = nil
            
            cell.backgroundColor = NCBrandColor.sharedInstance.backgroundView

            cell.labelTitle.text = metadata.fileNameView
            cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
            
            cell.transferButton.tintColor = NCBrandColor.sharedInstance.optionItem
            
            var progress: CGFloat = 0.0
            var totalBytes: Double = 0.0
            //var totalBytesExpected : Double = 0
            let progressArray = appDelegate.listProgressMetadata.object(forKey: metadata.ocId) as? NSArray
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
            
            let iconFileExists = FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView))

            if iconFileExists {
                NCUtility.sharedInstance.loadImage(ocId: metadata.ocId, fileNameView: metadata.fileNameView) { (image) in
                    cell.file.image = image
                }
            } else {
                if metadata.iconName.count > 0 {
                    cell.file.image = UIImage.init(named: metadata.iconName)
                } else {
                    cell.file.image = UIImage.init(named: "file")
                }
            }
            
            // Session Upload Extension
            if metadata.session == k_upload_session_extension {
                
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
            
            // User
            if metadata.account != appDelegate.activeAccount {
                let tableAccount = NCManageDatabase.sharedInstance.getAccount(predicate: NSPredicate(format: "account == %@", metadata.account))
                if tableAccount != nil {
                    let fileNamePath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(tableAccount!.user, activeUrl: tableAccount!.url) + "-" + tableAccount!.user + ".png"
                    var avatar = UIImage.init(contentsOfFile: fileNamePath)
                    if avatar != nil {
                        let avatarImageView = CCAvatar.init(image: avatar, borderColor: UIColor.black, borderWidth: 0.5)
                        let imageSize = avatarImageView?.bounds.size
                        UIGraphicsBeginImageContext(imageSize!)
                        let context = UIGraphicsGetCurrentContext()
                        avatarImageView?.layer.render(in: context!)
                        avatar = UIGraphicsGetImageFromCurrentImageContext()
                        UIGraphicsEndImageContext()
                        cell.user.image = avatar
                    }
                }
            }
            
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
        
        let ocId = filesID.object(at: indexPath.row)
        let metadata = sectionDataSource.allRecordsDataSource.object(forKey: ocId) as? tableMetadata
      
        return metadata
    }
    
    @objc func reloadDatasource(ServerUrl: String?, ocId: String?, action: Int32) {
        
        if operationQueueReloadDatasource.operationCount > 0 {
            return
        }
        
       
        if self.appDelegate.activeMain != nil && ServerUrl != nil && self.appDelegate.activeMain.serverUrl == ServerUrl {
            self.operationQueueReloadDatasource.addOperation {
                DispatchQueue.main.async {
                    self.appDelegate.activeMain.reloadDatasource(ServerUrl, ocId: ocId, action: Int(action))
                }
            }
        }
        if self.appDelegate.activeFavorites != nil && self.appDelegate.activeFavorites.viewIfLoaded?.window != nil {
            self.operationQueueReloadDatasource.addOperation {
                DispatchQueue.main.async {
                    self.appDelegate.activeFavorites.reloadDatasource(ocId, action: Int(action))
                }
            }
        }
        if self.appDelegate.activeTransfers != nil && self.appDelegate.activeTransfers.viewIfLoaded?.window != nil {
            self.operationQueueReloadDatasource.addOperation {
                DispatchQueue.main.async {
                    self.appDelegate.activeTransfers.reloadDatasource(ocId, action: Int(action))
                }
            }
        }
    }
    
    @objc func isValidIndexPath(_ indexPath: IndexPath, view: Any) -> Bool {
        
        if view is UICollectionView {
            return indexPath.section < (view as! UICollectionView).numberOfSections && indexPath.row < (view as! UICollectionView).numberOfItems(inSection: indexPath.section)
        }
        
        if view is UITableView {
            return indexPath.section < (view as! UITableView).numberOfSections && indexPath.row < (view as! UITableView).numberOfRows(inSection: indexPath.section)
        }
        
        return true
    }
    
    //MARK: -
    
    @objc func deleteFile(metadatas: NSArray, e2ee: Bool, serverUrl: String, folderocId: String, completion: @escaping (_ errorCode: Int, _ message: String)->()) {
        
        var copyMetadatas = [tableMetadata]()
        
        for metadata in metadatas {
            copyMetadatas.append(tableMetadata.init(value: metadata))
        }
        
        if e2ee {
            DispatchQueue.global().async {
                let error = NCNetworkingEndToEnd.sharedManager().lockFolderEncrypted(onServerUrl: serverUrl, ocId: folderocId, user: self.appDelegate.activeUser, userID: self.appDelegate.activeUserID, password: self.appDelegate.activePassword, url: self.appDelegate.activeUrl)
                DispatchQueue.main.async {
                    if error == nil {
                        self.delete(metadatas: copyMetadatas, serverUrl:serverUrl, e2ee: e2ee, completion: completion)
                    } else {
                        NCContentPresenter.shared.messageNotification("_delete_", description: error?.localizedDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                        return
                    }
                }
            }
        } else {
            delete(metadatas: copyMetadatas, serverUrl: serverUrl, e2ee: e2ee) { (errorCode, message) in
                if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_delete_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
                completion(errorCode, message)
            }
        }
    }
    
    private func delete(metadatas: [tableMetadata], serverUrl: String, e2ee: Bool, completion: @escaping (_ errorCode: Int, _ message: String)->()) {
        
        var count: Int = 0
        var completionErrorCode: Int = 0
        var completionMessage = ""
                
        for metadata in metadatas {
            
            // verify permission
            let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_delete)
            if metadata.permissions != "" && permission == false {
                completion(Int(k_CCErrorInternalError), "_no_permission_delete_file_")
                return
            }
            
            self.appDelegate.filterocId.add(metadata.ocId)
            
            let path = metadata.serverUrl + "/" + metadata.fileName
            
            OCNetworking.sharedManager().deleteFileOrFolder(withAccount: appDelegate.activeAccount, path: path, completion: { (account, message, errorCode) in
                
                if account == self.appDelegate.activeAccount {
                    
                    count += 1

                    if errorCode == 0 || errorCode == kOCErrorServerPathNotFound {
                        
                        do {
                            try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                        } catch { }
                        
                        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                        NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                        
                        if metadata.directory {
                            NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName), account: metadata.account)
                        }
                        
                        if (e2ee) {
                            NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, serverUrl, metadata.fileName))
                        }
                        
                        // Rich Workspace
                        if metadata.fileNameView.lowercased() == k_fileNameRichWorkspace.lowercased() {
                            self.appDelegate.activeMain.readFileReloadFolder()
                        }
                        
                        self.appDelegate.filterocId.remove(metadata.ocId)
                        
                    } else {
                        
                        completionErrorCode = errorCode
                        completionMessage = ""
                        if message != nil {
                            completionMessage = message!
                        }
                        
                        self.appDelegate.filterocId.remove(metadata.ocId)
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
                }
            })
        }
        
        self.reloadDatasource(ServerUrl: serverUrl, ocId: nil, action: k_action_NULL)
    }
    
    @objc func editPhoto(_ metadata: tableMetadata, viewController: UIViewController) {
        guard let path = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView) else {
            return
        }
        guard let image = UIImage(contentsOfFile: path) else {
            return
        }
        
        self.metadataEditPhoto = metadata

        let photoEditor = PhotoEditorViewController(nibName:"PhotoEditorViewController",bundle: Bundle(for: PhotoEditorViewController.self))
        
        photoEditor.image = image
        photoEditor.photoEditorDelegate = self
        photoEditor.hiddenControls = [.save, .share, .sticker]
        
        photoEditor.cancelButtonImage = CCGraphics.changeThemingColorImage(UIImage(named: "photoEditorCancel")!, multiplier:2, color: .white)
        photoEditor.cropButtonImage = CCGraphics.changeThemingColorImage(UIImage(named: "photoEditorCrop")!, multiplier:2, color: .white)
        photoEditor.drawButtonImage = CCGraphics.changeThemingColorImage(UIImage(named: "photoEditorDraw")!, multiplier:2, color: .white)
        photoEditor.textButtonImage = CCGraphics.changeThemingColorImage(UIImage(named: "photoEditorText")!, multiplier:2, color: .white)
        photoEditor.clearButtonImage = CCGraphics.changeThemingColorImage(UIImage(named: "photoEditorClear")!, multiplier:2, color: .white)
        photoEditor.continueButtonImage = CCGraphics.changeThemingColorImage(UIImage(named: "photoEditorDone")!, multiplier:2, color: .white)
        
        photoEditor.modalPresentationStyle = .fullScreen
        viewController.present(photoEditor, animated: true, completion: nil)
    }
    
    func doneEditing(image: UIImage) {
        guard let metadata = self.metadataEditPhoto else {
            return
        }
        guard let path = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView) else {
            return
        }
        guard let filetype = NCUtility.sharedInstance.isEditImage(metadata.fileNameView as NSString) else {
            return
        }
        if filetype == "PNG" {
            do {
                try image.pngData()?.write(to: NSURL(fileURLWithPath:path) as URL, options: .atomic)
            } catch { return }
        } else if filetype == "JPG" {
            let imageData = image.jpegData(compressionQuality: 1)
            do {
                try imageData?.write(to: NSURL(fileURLWithPath:path) as URL)
            } catch { return }
        }
        // write icon
        CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, extension: filetype, filterGrayScale: false, typeFile: metadata.typeFile, writeImage: true)

        // upload
        metadata.session = k_upload_session
        metadata.sessionSelector = selectorUploadFile
        metadata.status = Int(k_metadataStatusWaitUpload)
        
        _ = NCManageDatabase.sharedInstance.addMetadata(metadata)
    }
    
    func canceledEditing() {
        print("Canceled")
    }
    
    //MARK: - download Open Selector
    
    @objc func downloadOpen(metadata: tableMetadata, selector: String) {
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            
            NCNetworkingMain.sharedInstance.downloadFileSuccessFailure(metadata.fileName, ocId: metadata.ocId, serverUrl: metadata.serverUrl, selector: selector, errorMessage: "", errorCode: 0)
                        
        } else {
            
            metadata.session = k_download_session
            metadata.sessionError = ""
            metadata.sessionSelector = selector //selectorOpenIn
            metadata.status = Int(k_metadataStatusWaitDownload)
            
            _ = NCManageDatabase.sharedInstance.addMetadata(metadata)
            reloadDatasource(ServerUrl: metadata.serverUrl, ocId: metadata.ocId, action: k_action_MOD)
        }
    }

    //MARK: - OpenIn
    
    func openIn(metadata: tableMetadata) {
        
        docController = UIDocumentInteractionController(url: NSURL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)) as URL)
        docController?.delegate = self
        
        guard let splitViewController = self.appDelegate.window?.rootViewController as? UISplitViewController else {
            return
        }
        
        guard let view = splitViewController.viewControllers.first?.view else {
            return
        }
        
        guard let frame = splitViewController.viewControllers.first?.view.frame else {
            return
        }
        
        docController?.presentOptionsMenu(from: frame, in: view, animated: true)
    }
    
    //MARK: - OpenShare
    @objc func openShare(ViewController: UIViewController, metadata: tableMetadata, indexPage: Int) {
        
        let shareNavigationController = UIStoryboard(name: "NCShare", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let shareViewController = shareNavigationController.topViewController as! NCSharePaging
        
        shareViewController.metadata = metadata
        shareViewController.indexPage = indexPage
        
        shareNavigationController.modalPresentationStyle = .formSheet
        ViewController.present(shareNavigationController, animated: true, completion: nil)
    }
    
    //MARK: - NCAudioRecorder
    
    func startAudioRecorder() {
    
        let fileName = CCUtility.createFileNameDate(NSLocalizedString("_voice_memo_filename_", comment: ""), extension: "m4a")!
        let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as! NCAudioRecorderViewController
    
        viewController.delegate = self
        viewController.createRecorder(fileName: fileName)
        viewController.modalTransitionStyle = .crossDissolve
        viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
    
        self.appDelegate.window.rootViewController?.present(viewController, animated: true, completion: nil)
    }
    
    func didFinishRecording(_ viewController: NCAudioRecorderViewController, fileName: String) {
        
        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadVoiceNote", bundle: nil).instantiateInitialViewController() else { return }
        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        
        let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadVoiceNote
        viewController.setup(serverUrl: appDelegate.activeMain.serverUrl, fileNamePath: NSTemporaryDirectory() + fileName, fileName: fileName)
        self.appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
    }
    
    func didFinishWithoutRecording(_ viewController: NCAudioRecorderViewController, fileName: String) {
    }
}
    
//MARK: - Main TabBarController

class CCMainTabBarController : UITabBarController, UITabBarControllerDelegate {
        
    override func viewDidLoad() {
            
        super.viewDidLoad()
        delegate = self
    }
        
    //Delegate methods
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            
        let tabViewControllers = tabBarController.viewControllers!
        guard let toIndex = tabViewControllers.firstIndex(of: viewController) else {
                
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
        let fromIndex = tabViewControllers.firstIndex(of: selectedViewController!)
            
        guard fromIndex != toIndex else {return}
            
        // Add the toView to the tab bar view
        fromView.superview?.addSubview(toView)
        fromView.superview?.backgroundColor = NCBrandColor.sharedInstance.backgroundView
            
        // Position toView off screen (to the left/right of fromView)
        let screenWidth = UIScreen.main.bounds.size.width;
        let scrollRight = toIndex > fromIndex!;
        let offset = (scrollRight ? screenWidth : -screenWidth)
        toView.center = CGPoint(x: (fromView.center.x) + offset, y: (toView.center.y))
            
        // Disable interaction during animation
        view.isUserInteractionEnabled = false
            
        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIView.AnimationOptions.curveEaseOut, animations: {
                
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

//MARK: - Networking Main

class NCNetworkingMain: NSObject, CCNetworkingDelegate {

    @objc static let sharedInstance: NCNetworkingMain = {
        let instance = NCNetworkingMain()
        return instance
    }()
    
    lazy var operationQueueNetworkingMain: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.nextcloud.operationQueueNetworkingMain"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    // DOWNLOAD
    func downloadStart(_ ocId: String!, account: String!, task: URLSessionDownloadTask!, serverUrl: String!) {
        NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, ocId: ocId, action: Int32(k_action_MOD))
        appDelegate.updateApplicationIconBadgeNumber()
    }
    
    func downloadFileSuccessFailure(_ fileName: String!, ocId: String!, serverUrl: String!, selector: String!, errorMessage: String!, errorCode: Int) {
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", ocId)) else {
            return
        }
        
        if metadata.account != appDelegate.activeAccount {
            NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, ocId: ocId, action: Int32(k_action_MOD))
            return
        }
        
        if errorCode == 0 {
            
            NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, ocId: ocId, action: Int32(k_action_MOD))
            
            // Synchronized
            if selector == selectorDownloadSynchronize {
                appDelegate.updateApplicationIconBadgeNumber()
                appDelegate.startLoadAutoDownloadUpload()
                return
            }
            
            // Modify Photo
            if selector == selectorDownloadEditPhoto {
                NCMainCommon.sharedInstance.editPhoto(metadata, viewController: appDelegate.activeMain)
                return
            }
            
            // open View File
            if (selector == selectorLoadFileView || selector == selectorLoadFileInternalView) && UIApplication.shared.applicationState == UIApplication.State.active {
            
                var uti = CCUtility.insertTypeFileIconName(metadata.fileNameView, metadata: metadata)
                if uti == nil {
                    uti = ""
                } else if uti!.contains("opendocument") && !NCUtility.sharedInstance.isRichDocument(metadata) {
                    metadata.typeFile = k_metadataTypeFile_unknown
                }
                
                if metadata.typeFile == k_metadataTypeFile_imagemeter {
                    
                    if NCBrandOptions.sharedInstance.use_imi_viewer == false {
                        NCMainCommon.sharedInstance.openIn(metadata: metadata)
                        return
                    }
                    
                    if !NCUtility.sharedInstance.IMUnzip(metadata: metadata) {
                        NCContentPresenter.shared.messageNotification("_error_", description: "Bundle imagemeter error. 🤷‍♂️", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: 0)
                        return
                    }
                    
                    let storyboard = UIStoryboard(name: "IMImagemeter", bundle: nil)
                    let imiVC = storyboard.instantiateInitialViewController() as! IMImagemeterViewer
                    imiVC.metadata = metadata
                    imiVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                    
                    self.appDelegate.window.rootViewController?.present(imiVC, animated: true, completion: nil)
                    
                    return
                }
                
                if metadata.typeFile == k_metadataTypeFile_compress || metadata.typeFile == k_metadataTypeFile_unknown {

                    NCMainCommon.sharedInstance.openIn(metadata: metadata)
                    
                } else {
                    
                    if appDelegate.activeMain.view.window != nil {
                        appDelegate.activeMain.shouldPerformSegue(metadata, selector: selector)
                    }
                    if appDelegate.activeFavorites.view.window != nil {
                        appDelegate.activeFavorites.shouldPerformSegue(metadata, selector: selector)
                    }
                }
            }
            
            // Open in...
            if selector == selectorOpenIn && UIApplication.shared.applicationState == UIApplication.State.active {

                NCMainCommon.sharedInstance.openIn(metadata: metadata)
            }
            
            // Save to Photo Album
            if selector == selectorSave {
                
                appDelegate.activeMain.save(toPhotoAlbum: metadata)
            }
            
            // Copy File
            if selector == selectorLoadCopy {
                
                appDelegate.activeMain.copyFile(toPasteboard: metadata)
            }
            
            // Set as available offline
            if selector == selectorLoadOffline {
                
                NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, offline: true)
            }
            
            //selectorLoadViewImage
            if selector == selectorLoadViewImage {
                
                if appDelegate.activeDetail != nil {
                    appDelegate.activeDetail.downloadPhotoBrowserSuccessFailure(metadata, selector: selector, errorCode: errorCode)
                }
            }
            
            appDelegate.startLoadAutoDownloadUpload()
            
        } else {
            
            // File do not exists on server, remove in local
            if (errorCode == kOCErrorServerPathNotFound || errorCode == -1011) { // - 1011 = kCFURLErrorBadServerResponse
                
                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }
                
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                
                NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, ocId: ocId, action: Int32(k_action_DEL))
            }
            
            if selector == selectorLoadViewImage {
                
                if appDelegate.activeDetail.view.window != nil {
                    appDelegate.activeDetail.downloadPhotoBrowserSuccessFailure(metadata, selector: selector, errorCode: errorCode)
                }
                
                NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, ocId: ocId, action: Int32(k_action_MOD))
            }
        }
        
        appDelegate.startLoadAutoDownloadUpload()
    }
    
    // UPLOAD
    
    func uploadStart(_ ocId: String!, account: String!, task: URLSessionUploadTask!, serverUrl: String!) {
        NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, ocId: ocId, action: Int32(k_action_MOD))
        appDelegate.updateApplicationIconBadgeNumber()
    }
    
    func uploadFileSuccessFailure(_ fileName: String!, ocId: String!, assetLocalIdentifier: String!, serverUrl: String!, selector: String!, errorMessage: String!, errorCode: Int) {
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", ocId)) else {
            return
        }
        
        if metadata.account != appDelegate.activeAccount {
            NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, ocId: ocId, action: Int32(k_action_MOD))
            return
        }
        
        NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, ocId: ocId, action: Int32(k_action_MOD))
        
        if errorCode == 0 {
            appDelegate.startLoadAutoDownloadUpload()
        } else {
            if errorCode != -999 && errorCode != kOCErrorServerUnauthorized && errorMessage != "" {
                NCContentPresenter.shared.messageNotification("_upload_file_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
    
    @objc func downloadThumbnail(with metadata: tableMetadata, view: Any, indexPath: IndexPath) {
        operationQueueNetworkingMain.addOperation(NCOperationNetworkingMain.init(metadata: metadata, view: view, indexPath: indexPath, networkingFunc: "downloadThumbnail"))
    }
    
    func downloadThumbnail(with metadata: tableMetadata, view: Any, indexPath: IndexPath, closure: @escaping () -> ()) {
        
        if !metadata.isInvalidated && metadata.hasPreview && (!CCUtility.fileProviderStorageIconExists(metadata.ocId, fileNameView: metadata.fileName) || metadata.typeFile == k_metadataTypeFile_document) {
            
            let width = NCUtility.sharedInstance.getScreenWidthForPreview()
            let height = NCUtility.sharedInstance.getScreenHeightForPreview()
            
            OCNetworking.sharedManager().downloadPreview(withAccount: metadata.account, metadata: metadata, withWidth: width, andHeight: height, completion: { (account, image, message, errorCode) in
                
                if errorCode == 0 && account == self.appDelegate.activeAccount && !metadata.isInvalidated && CCUtility.fileProviderStorageIconExists(metadata.ocId, fileNameView: metadata.fileName) {
                    
                    if view is UICollectionView && NCMainCommon.sharedInstance.isValidIndexPath(indexPath, view: view) {
                        if let cell = (view as! UICollectionView).cellForItem(at: indexPath) {
                            if cell is NCListCell {
                                (cell as! NCListCell).imageItem.image = image
                            } else if cell is NCGridCell {
                                (cell as! NCGridCell).imageItem.image = image
                            } else if cell is NCGridMediaCell {
                                (cell as! NCGridMediaCell).imageItem.image = image
                            }
                        }
                    }
                    
                    if view is UITableView && CCUtility.fileProviderStorageIconExists(metadata.ocId, fileNameView: metadata.fileName) && NCMainCommon.sharedInstance.isValidIndexPath(indexPath, view: view) {
                        if let cell = (view as! UITableView).cellForRow(at: indexPath) {
                            if cell is CCCellMainTransfer {
                                (cell as! CCCellMainTransfer).file.image = image
                            } else if cell is CCCellMain {
                                (cell as! CCCellMain).file.image = image
                            }
                        }
                    }
                }
                
                return closure()
            })
        }
        
        return closure()
    }
}

//MARK: - Operation Networking Main

class NCOperationNetworkingMain: Operation {
    
    private var _executing : Bool = false
    override var isExecuting : Bool {
        get { return _executing }
        set {
            guard _executing != newValue else { return }
            willChangeValue(forKey: "isExecuting")
            _executing = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _finished : Bool = false
    override var isFinished : Bool {
        get { return _finished }
        set {
            guard _finished != newValue else { return }
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    
    private var metadata: tableMetadata?
    private var view: Any?
    private var indexPath: IndexPath?
    private var networkingFunc: String = ""

    init(metadata: tableMetadata?, view: Any?, indexPath: IndexPath?, networkingFunc: String) {
        super.init()
        
        if metadata != nil { self.metadata = metadata! }
        if view != nil { self.view = view! }
        if indexPath != nil { self.indexPath = indexPath! }
        
        self.networkingFunc = networkingFunc
    }
    
    override func start() {
        if !Thread.isMainThread {
            
            self.performSelector(onMainThread:#selector(start), with: nil, waitUntilDone: false)
            
        } else {
        
            isExecuting = true
        
            if isCancelled {
                finish()
            } else {
                poolNetworking()
            }
        }
    }
    
    func finish() {
        isExecuting = false
        isFinished = true
    }
    
    override func cancel() {
        super.cancel()
        
        if isExecuting {
            complete()
        }
    }
    
    func complete() {
        finish()
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
    func poolNetworking() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        switch networkingFunc {
        case "downloadThumbnail":
            NCNetworkingMain.sharedInstance.downloadThumbnail(with: metadata!, view: view!, indexPath: indexPath!) {
                self.complete()
            }
        default:
            print("error")
        }
    }
}


//MARK: - Function Main

class NCFunctionMain: NSObject {
    
    @objc static let sharedInstance: NCFunctionMain = {
        let instance = NCFunctionMain()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc func synchronizeOffline() {
        
        let directories = NCManageDatabase.sharedInstance.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", appDelegate.activeAccount), sorted: "serverUrl", ascending: true)
        if (directories != nil) {
            for directory: tableDirectory in directories! {
                CCSynchronize.shared()?.readFolder(directory.serverUrl, selector: selectorReadFolderWithDownload, account: appDelegate.activeAccount)
            }
        }
        
        let files = NCManageDatabase.sharedInstance.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", appDelegate.activeAccount), sorted: "fileName", ascending: true)
        if (files != nil) {
            for file: tableLocalFile in files! {
                guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", file.ocId)) else {
                    continue
                }
                CCSynchronize.shared()?.readFile(metadata.ocId, fileName: metadata.fileName, serverUrl: metadata.serverUrl, selector: selectorReadFileWithDownload, account: appDelegate.activeAccount)
            }
        }
    }
}


