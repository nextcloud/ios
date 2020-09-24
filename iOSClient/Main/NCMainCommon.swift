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

class NCMainCommon: NSObject, NCAudioRecorderViewControllerDelegate {
    @objc static let shared: NCMainCommon = {
        let instance = NCMainCommon()
        instance.createImagesThemingColor()
        return instance
    }()
    
    var metadataEditPhoto: tableMetadata?

    //MARK: -
    
    struct NCMainCommonImages {
        static var cellSharedImage = UIImage()
        static var cellCanShareImage = UIImage()
        static var cellShareByLinkImage = UIImage()
        static var cellFavouriteImage = UIImage()
        static var cellMoreImage = UIImage()
        static var cellCommentImage = UIImage()
        static var cellLivePhotoImage = UIImage()

        static var cellFolderEncryptedImage = UIImage()
        static var cellFolderSharedWithMeImage = UIImage()
        static var cellFolderPublicImage = UIImage()
        static var cellFolderGroupImage = UIImage()
        static var cellFolderExternalImage = UIImage()
        static var cellFolderAutomaticUploadImage = UIImage()
        static var cellFolderImage = UIImage()
        
        static var cellPlayImage = UIImage()
    }
    
    @objc func createImagesThemingColor() {
        NCMainCommonImages.cellSharedImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 100, height: 100, color: NCBrandColor.sharedInstance.textView)
        NCMainCommonImages.cellCanShareImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 100, height: 100, color: NCBrandColor.sharedInstance.optionItem)
        NCMainCommonImages.cellShareByLinkImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "sharebylink"), width: 100, height: 100, color: NCBrandColor.sharedInstance.optionItem)
        NCMainCommonImages.cellFavouriteImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 100, height: 100, color: NCBrandColor.sharedInstance.yellowFavorite)
        NCMainCommonImages.cellMoreImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.optionItem)
        NCMainCommonImages.cellCommentImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "comment"), width: 30, height: 30, color: NCBrandColor.sharedInstance.graySoft)
        NCMainCommonImages.cellLivePhotoImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "livePhoto"), width: 100, height: 100, color: NCBrandColor.sharedInstance.textView)
        
        NCMainCommonImages.cellFolderEncryptedImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderEncrypted"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderSharedWithMeImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_shared_with_me"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderPublicImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_public"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderGroupImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_group"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderExternalImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_external"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderAutomaticUploadImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderAutomaticUpload"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCMainCommonImages.cellFolderImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        
        NCMainCommonImages.cellPlayImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "play"), width: 100, height: 100, color: .white)
    }
    
    //MARK: -
    
    @objc func triggerProgressTask(_ notification: Notification, sectionDataSourceocIdIndexPath: NSDictionary, tableView: UITableView, viewController: UIViewController, serverUrlViewController: String?) {

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if viewController.viewIfLoaded?.window == nil {
            return
        }
        
        guard let dic = notification.userInfo else {
            return
        }
        
        let _ = dic["account"] as? NSString ?? ""
        let ocId = dic["ocId"] as? NSString ?? ""
        let serverUrl = dic["serverUrl"] as? String ?? ""
        let status = dic["status"] as? Int ?? Int(k_metadataStatusNormal)
        let progress = dic["progress"] as? CGFloat ?? 0
        let totalBytes = dic["totalBytes"] as? Double ?? 0
        let totalBytesExpected = dic["totalBytesExpected"] as? Double ?? 0
        
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
    
    
    
    //MARK: -
    
    @objc func cellForRowAtIndexPath(_ indexPath: IndexPath, tableView: UITableView ,metadata: tableMetadata, metadataFolder: tableMetadata?, serverUrl: String, autoUploadFileName: String, autoUploadDirectory: String, tableShare: tableShare?, livePhoto: Bool) -> UITableViewCell {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        // Create File System
        if metadata.directory {
            CCUtility.getDirectoryProviderStorageOcId(metadata.ocId)
        } else {
            CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
        }
        
        // CCCell
        if metadata.status == k_metadataStatusNormal || metadata.status == k_metadataStatusDownloadError {
            
            // NORMAL
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "CellMain", for: indexPath) as! CCCellMain
            cell.labelTitle.text = metadata.fileNameView
            cell.filePreviewImageView.image = nil
            cell.filePreviewImageView.backgroundColor = UIColor.lightGray
            
            // Download preview
            if !(metadataFolder?.e2eEncrypted ?? false) {
                NCOperationQueue.shared.downloadThumbnail(metadata: metadata, urlBase: appDelegate.urlBase, view: tableView, indexPath: indexPath)
            }
            
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
                cell.file.backgroundColor = nil
                // File Image & Image Title Segue
                if metadata.e2eEncrypted {
                    cell.file.image = NCMainCommonImages.cellFolderEncryptedImage
                } else if isShare {
                    cell.file.image = NCMainCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType != 3) {
                    cell.file.image = NCMainCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType == 3) {
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
                let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, lockServerUrl))
                // Local image: offline
                if tableDirectory != nil && tableDirectory!.offline {
                    cell.local.image = UIImage.init(named: "offlineFlag")
                }
                
            } else {
                
                let iconFileExists = FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                
                // Lable Info
                cell.labelInfoFile.text = CCUtility.dateDiff(metadata.date as Date) + " · " + CCUtility.transformedSize(metadata.size)
                
                // File Image
                if iconFileExists {
                    cell.file.backgroundColor = nil
                    cell.file.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                } else if(!metadata.hasPreview){
                    cell.file.backgroundColor = nil
                    if metadata.iconName.count > 0 {
                        cell.file.image = UIImage.init(named: metadata.iconName)
                    } else {
                        cell.file.image = UIImage.init(named: "file")
                    }
                }
                
                // Local Image - Offline
                let size = CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView)
                if size > 0 {
                    let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    if tableLocalFile == nil && size == metadata.size {
                        NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                    }
                    if tableLocalFile != nil && tableLocalFile!.offline { cell.local.image = UIImage.init(named: "offlineFlag") }
                    else { cell.local.image = UIImage.init(named: "local") }
                }
                
                // Status image: encrypted
                let tableE2eEncryption = NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND fileNameIdentifier == %@", appDelegate.account, metadata.fileName))
                if tableE2eEncryption != nil &&  NCUtility.shared.isEncryptedMetadata(metadata) {
                    cell.status.image = UIImage.init(named: "encrypted")
                }
                
                // Live Photo
                if metadata.livePhoto && livePhoto {
                    cell.status.image = NCMainCommonImages.cellLivePhotoImage
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
            if !(metadataFolder?.e2eEncrypted ?? false) && !metadata.e2eEncrypted {
                if (isShare) {
                    cell.shared.image = NCMainCommonImages.cellSharedImage
                } else if (tableShare != nil && tableShare!.shareType == 3) {
                    cell.shared.image = NCMainCommonImages.cellShareByLinkImage
                } else if (tableShare != nil && tableShare!.shareType != 3) {
                    cell.shared.image = NCMainCommonImages.cellSharedImage
                } else {
                    cell.shared.image = NCMainCommonImages.cellCanShareImage
                }
                if metadata.ownerId != appDelegate.userID {
                    // Load avatar
                    let fileNameSource = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-" + metadata.ownerId + ".png"
                    let fileNameSourceAvatar = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-avatar-" + metadata.ownerId + ".png"
                    if FileManager.default.fileExists(atPath: fileNameSourceAvatar) {
                        if let avatar = UIImage(contentsOfFile: fileNameSourceAvatar) {
                            cell.shared.image = avatar
                        }
                    } else if FileManager.default.fileExists(atPath: fileNameSource) {
                        if let avatar = NCUtility.shared.createAvatar(fileNameSource: fileNameSource, fileNameSourceAvatar: fileNameSourceAvatar) {
                            cell.shared.image = avatar
                        }
                    } else {
                        NCCommunication.shared.downloadAvatar(userID: metadata.ownerId, fileNameLocalPath: fileNameSource, size: Int(k_avatar_size)) { (account, data, errorCode, errorMessage) in
                            if errorCode == 0 && account == appDelegate.account {
                                cell.shared.image = NCUtility.shared.createAvatar(fileNameSource: fileNameSource, fileNameSourceAvatar: fileNameSourceAvatar)
                            }
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
            
            // downloadFile Error
            if metadata.status == k_metadataStatusDownloadError {
                
                cell.status.image = UIImage.init(named: "statuserror")
                
                if metadata.sessionError.count == 0 {
                    cell.labelInfoFile.text = NSLocalizedString("_error_", comment: "") + ", " + NSLocalizedString("_file_not_downloaded_", comment: "")
                } else {
                    cell.labelInfoFile.text = metadata.sessionError
                }
            }
            
            return cell
            
        } else {
         
            // TRASNFER
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "CellMainTransfer", for: indexPath) as! CCCellMainTransfer
            cell.labelTitle.text = metadata.fileNameView
            var progress: CGFloat = 0.0
            var totalBytes: Double = 0.0
            let progressArray = appDelegate.listProgressMetadata.object(forKey: metadata.ocId) as? NSArray
            if progressArray != nil && progressArray?.count == 3 {
                progress = progressArray?.object(at: 0) as? CGFloat ?? 0
                totalBytes = progressArray?.object(at: 1) as? Double ?? 0
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
            
            let iconFileExists = FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))

            if iconFileExists {
                cell.file.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            } else {
                if metadata.status == k_metadataStatusWaitUpload || metadata.status == k_metadataStatusInUpload || metadata.status == k_metadataStatusUploading || metadata.status == k_metadataStatusUploadError {
                
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "cloudUpload"), width: 100, height: 100, color: NCBrandColor.sharedInstance.brandElement)
                
                } else {
                
                    cell.file.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "cloudDownload"), width: 100, height: 100, color: NCBrandColor.sharedInstance.brandElement)
                }
            }
            
            // uploadFileError
            if metadata.status == k_metadataStatusUploadError {
                
                cell.status.image = UIImage.init(named: "statuserror")
                
                if metadata.sessionError.count == 0 {
                    cell.labelInfoFile.text = NSLocalizedString("_error_", comment: "") + ", " + NSLocalizedString("_file_not_uploaded_", comment: "")
                } else {
                    cell.labelInfoFile.text = metadata.sessionError
                }
            }
            
            // Progress
            cell.transferButton.progress = progress
            
            // User
            if metadata.account != appDelegate.account {
                let tableAccount = NCManageDatabase.sharedInstance.getAccount(predicate: NSPredicate(format: "account == %@", metadata.account))
                if tableAccount != nil {
                    let fileNamePath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-" + appDelegate.user + ".png"
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

    @objc func isValidIndexPath(_ indexPath: IndexPath, view: Any) -> Bool {
        
        if view is UICollectionView {
            return indexPath.section < (view as! UICollectionView).numberOfSections && indexPath.row < (view as! UICollectionView).numberOfItems(inSection: indexPath.section)
        }
        
        if view is UITableView {
            return indexPath.section < (view as! UITableView).numberOfSections && indexPath.row < (view as! UITableView).numberOfRows(inSection: indexPath.section)
        }
        
        return true
    }
    
    //MARK: - download Open Selector
    
    @objc func downloadOpen(metadata: tableMetadata, selector: String) {
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_downloadedFile, userInfo: ["metadata": metadata, "selector": selector, "errorCode": 0, "errorDescription": "" ])
                                    
        } else {
            
            NCNetworking.shared.download(metadata: metadata, selector: selector) { (_) in }
        }
    }

    //MARK: - OpenIn
    
    
    
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
    
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let fileName = CCUtility.createFileNameDate(NSLocalizedString("_voice_memo_filename_", comment: ""), extension: "m4a")!
        let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as! NCAudioRecorderViewController
    
        viewController.delegate = self
        viewController.createRecorder(fileName: fileName)
        viewController.modalTransitionStyle = .crossDissolve
        viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
    
        appDelegate.window.rootViewController?.present(viewController, animated: true, completion: nil)
    }
    
    func didFinishRecording(_ viewController: NCAudioRecorderViewController, fileName: String) {
        
        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadVoiceNote", bundle: nil).instantiateInitialViewController() else { return }
        navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadVoiceNote
        viewController.setup(serverUrl: appDelegate.activeServerUrl, fileNamePath: NSTemporaryDirectory() + fileName, fileName: fileName)
        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
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
