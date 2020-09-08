//
//  NCCollectionCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/09/2020.
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
import TLPhotoPicker
import ZIPFoundation
import NCCommunication

class NCCollectionCommon: NSObject {
    @objc static let shared: NCCollectionCommon = {
        let instance = NCCollectionCommon()
        instance.createImagesThemingColor()
        return instance
    }()

    struct NCCollectionCommonImages {
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
        NCCollectionCommonImages.cellSharedImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 100, height: 100, color: NCBrandColor.sharedInstance.textView)
        NCCollectionCommonImages.cellCanShareImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "share"), width: 100, height: 100, color: NCBrandColor.sharedInstance.optionItem)
        NCCollectionCommonImages.cellShareByLinkImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "sharebylink"), width: 100, height: 100, color: NCBrandColor.sharedInstance.optionItem)
        NCCollectionCommonImages.cellFavouriteImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 100, height: 100, color: NCBrandColor.sharedInstance.yellowFavorite)
        NCCollectionCommonImages.cellMoreImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.optionItem)
        NCCollectionCommonImages.cellCommentImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "comment"), width: 30, height: 30, color: NCBrandColor.sharedInstance.graySoft)
        NCCollectionCommonImages.cellLivePhotoImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "livePhoto"), width: 100, height: 100, color: NCBrandColor.sharedInstance.textView)
        
        NCCollectionCommonImages.cellFolderEncryptedImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderEncrypted"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCCollectionCommonImages.cellFolderSharedWithMeImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_shared_with_me"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCCollectionCommonImages.cellFolderPublicImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_public"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCCollectionCommonImages.cellFolderGroupImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_group"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCCollectionCommonImages.cellFolderExternalImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder_external"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCCollectionCommonImages.cellFolderAutomaticUploadImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folderAutomaticUpload"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        NCCollectionCommonImages.cellFolderImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), width: 600, height: 600, color: NCBrandColor.sharedInstance.brandElement)
        
        NCCollectionCommonImages.cellPlayImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "play"), width: 100, height: 100, color: .white)
    }
    
    // MARK -
    
    func cellForItemAt(indexPath: IndexPath, collectionView: UICollectionView, cell: UICollectionViewCell, metadata: tableMetadata, metadataFolder: tableMetadata?, serverUrl: String, isEditMode: Bool, selectocId: [String], autoUploadFileName: String, autoUploadDirectory: String, hideButtonMore: Bool, downloadThumbnail: Bool, shares: [tableShare]?, source: UIViewController) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
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
            NCOperationQueue.shared.downloadThumbnail(metadata: metadata, urlBase: appDelegate.urlBase, view: collectionView, indexPath: indexPath)
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
            cell.imageShared.image = nil
            
            if metadata.directory {
                
                if metadata.e2eEncrypted {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderEncryptedImage
                } else if isShare {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType != 3) {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType == 3) {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderPublicImage
                } else if metadata.mountType == "group" {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderGroupImage
                } else if isMounted {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderExternalImage
                } else if metadata.fileName == autoUploadFileName && serverUrl == autoUploadDirectory {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderAutomaticUploadImage
                } else {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderImage
                }
                
                cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date)
                
                let lockServerUrl = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)!
                let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, lockServerUrl))
                
                // Local image: offline
                if tableDirectory != nil && tableDirectory!.offline {
                    cell.imageLocal.image = UIImage.init(named: "offlineFlag")
                }
                
            } else {
                
                if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                    cell.imageItem.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                } else if(!metadata.hasPreview) {
                    if metadata.iconName.count > 0 {
                        cell.imageItem.image = UIImage.init(named: metadata.iconName)
                    } else {
                        cell.imageItem.image = UIImage.init(named: "file")
                    }
                }
                
                cell.labelInfo.text = CCUtility.dateDiff(metadata.date as Date) + " · " + CCUtility.transformedSize(metadata.size)
                
                //  image local
                let size = CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView)
                if size > 0 {
                    let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    if tableLocalFile == nil && size == metadata.size {
                        NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                    }
                    if tableLocalFile?.offline ?? false {
                        cell.imageLocal.image = UIImage.init(named: "offlineFlag")
                    } else{
                        cell.imageLocal.image = UIImage.init(named: "local")
                    }
                }
            }
            
            // image Favorite
            if metadata.favorite {
                cell.imageFavorite.image = NCCollectionCommonImages.cellFavouriteImage
            }
            
            // Share image
            if (isShare) {
                cell.imageShared.image = NCCollectionCommonImages.cellSharedImage
            } else if (tableShare != nil && tableShare!.shareType == 3) {
                cell.imageShared.image = NCCollectionCommonImages.cellShareByLinkImage
            } else if (tableShare != nil && tableShare!.shareType != 3) {
                cell.imageShared.image = NCCollectionCommonImages.cellSharedImage
            } else {
                cell.imageShared.image = NCCollectionCommonImages.cellCanShareImage
            }
            if metadata.ownerId.count > 0 && metadata.ownerId != appDelegate.userID {
                // Load avatar
                let fileNameSource = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-" + metadata.ownerId + ".png"
                let fileNameSourceAvatar = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-avatar-" + metadata.ownerId + ".png"
                if FileManager.default.fileExists(atPath: fileNameSourceAvatar) {
                    cell.imageShared.image = UIImage(contentsOfFile: fileNameSourceAvatar)
                } else if FileManager.default.fileExists(atPath: fileNameSource) {
                    cell.imageShared.image = NCUtility.shared.createAvatar(fileNameSource: fileNameSource, fileNameSourceAvatar: fileNameSourceAvatar)
                } else {
                    NCCommunication.shared.downloadAvatar(userID: metadata.ownerId, fileNameLocalPath: fileNameSource, size: Int(k_avatar_size)) { (account, data, errorCode, errorMessage) in
                        if errorCode == 0 && account == appDelegate.account {
                            cell.imageShared.image = NCUtility.shared.createAvatar(fileNameSource: fileNameSource, fileNameSourceAvatar: fileNameSourceAvatar)
                        }
                    }
                }
            }
            
            if isEditMode {
                cell.imageItemLeftConstraint.constant = 45
                cell.imageSelect.isHidden = false
                
                if selectocId.contains(metadata.ocId) {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = NCUtility.shared.cellBlurEffect(with: cell.bounds)
                } else {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedNo"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = nil
                }
            } else {
                cell.imageItemLeftConstraint.constant = 10
                cell.imageSelect.isHidden = true
                cell.backgroundView = nil
            }
            
            // Transfer
            if metadata.status == k_metadataStatusInDownload  ||  metadata.status >= k_metadataStatusTypeUpload {
                cell.progressView.isHidden = false
                cell.setButtonMore(named: "stop")
            } else {
                cell.progressView.isHidden = true
                cell.progressView.progress = 0.0
                cell.setButtonMore(named: "more")
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
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderEncryptedImage
                } else if isShare {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType != 3) {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderSharedWithMeImage
                } else if (tableShare != nil && tableShare!.shareType == 3) {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderPublicImage
                } else if metadata.mountType == "group" {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderGroupImage
                } else if isMounted {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderExternalImage
                } else if metadata.fileName == autoUploadFileName && serverUrl == autoUploadDirectory {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderAutomaticUploadImage
                } else {
                    cell.imageItem.image = NCCollectionCommonImages.cellFolderImage
                }
                
    
                let lockServerUrl = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)!
                let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, lockServerUrl))
                                
                // Local image: offline
                if tableDirectory != nil && tableDirectory!.offline {
                    cell.imageLocal.image = UIImage.init(named: "offlineFlag")
                }
                
            } else {
                
                if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                    cell.imageItem.image =  UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
                } else if(!metadata.hasPreview) {
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
                cell.imageFavorite.image = NCCollectionCommonImages.cellFavouriteImage
            }
            
            if isEditMode {
                cell.imageSelect.isHidden = false
                if selectocId.contains(metadata.ocId) {
                    cell.imageSelect.image = CCGraphics.scale(UIImage.init(named: "checkedYes"), to: CGSize(width: 50, height: 50), isAspectRation: true)
                    cell.backgroundView = NCUtility.shared.cellBlurEffect(with: cell.bounds)
                } else {
                    cell.imageSelect.isHidden = true
                    cell.backgroundView = nil
                }
            } else {
                cell.imageSelect.isHidden = true
                cell.backgroundView = nil
            }
            
            // Transfer
            if metadata.status == k_metadataStatusInDownload  ||  metadata.status >= k_metadataStatusTypeUpload {
                cell.progressView.isHidden = false
                cell.setButtonMore(named: "stop")
            } else {
                cell.progressView.isHidden = true
                cell.progressView.progress = 0.0
                cell.setButtonMore(named: "more")
            }
        }
    }
    
    // MARK -
    
    func notificationDeleteFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata, errorCode: Int, errorDescription: String ,onlyLocal: Bool) {
        if errorCode == 0 {
            if !onlyLocal {
                dataSource?.deleteMetadata(ocId: metadata.ocId)
            }
            collectionView?.reloadData()
        } else {
            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
        }
    }
    
    func notificationDownloadedFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata) {
        dataSource?.reloadMetadata(ocId: metadata.ocId)
        collectionView?.reloadData()
    }
    
    func notificationUploadedFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata, serverUrl: String, account: String) {
        if metadata.serverUrl == serverUrl && metadata.account == account {
            dataSource?.reloadMetadata(ocId: metadata.ocId)
            collectionView?.reloadData()
        }
    }
    
    func notificationUploadFileStart(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata, serverUrl: String, account: String) {
        if metadata.serverUrl == serverUrl && metadata.account == account {
            dataSource?.addMetadata(metadata)
            collectionView?.reloadData()
        }
    }
    
    func notificationTriggerProgressTask(collectionView: UICollectionView?, dataSource: NCDataSource?, ocId: String, progress: Float) {
        if let index = dataSource?.getIndexMetadata(ocId: ocId) {
            if let cell = collectionView?.cellForItem(at: IndexPath(row: index, section: 0)) {
                if cell is NCListCell {
                    let cell = cell as! NCListCell
                    if progress > 0 {
                        cell.progressView?.isHidden = false
                        cell.progressView?.progress = progress
                        cell.setButtonMore(named: "stop")
                    }
                } else if cell is NCGridCell {
                    let cell = cell as! NCGridCell
                    if progress > 0 {
                        cell.progressView.isHidden = false
                        cell.progressView.progress = progress
                        cell.setButtonMore(named: "stop")
                    }
                }
            }
        }
    }
}

// MARK: - List Layout

class NCListLayout: UICollectionViewFlowLayout {
    
    let itemHeight: CGFloat = 60
    
    override init() {
        super.init()
        
        sectionHeadersPinToVisibleBounds = false
        
        minimumInteritemSpacing = 0
        minimumLineSpacing = 1
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                let itemWidth: CGFloat = collectionView.frame.width
                return CGSize(width: itemWidth, height: self.itemHeight)
            }
            
            // Default fallback
            return CGSize(width: 100, height: 100)
        }
        set {
            super.itemSize = newValue
        }
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}

// MARK: - Grid Layout

class NCGridLayout: UICollectionViewFlowLayout {
    
    var heightLabelPlusButton: CGFloat = 45
    var marginLeftRight: CGFloat = 6
    var itemForLine: CGFloat = 3

    override init() {
        super.init()
        
        sectionHeadersPinToVisibleBounds = false
        
        minimumInteritemSpacing = 1
        minimumLineSpacing = marginLeftRight
        
        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 10, left: marginLeftRight, bottom: 0, right:  marginLeftRight)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                
                let itemWidth: CGFloat = (collectionView.frame.width - marginLeftRight * 2 - marginLeftRight * (itemForLine - 1)) / itemForLine
                let itemHeight: CGFloat = itemWidth + heightLabelPlusButton
                
                return CGSize(width: itemWidth, height: itemHeight)
            }
            
            // Default fallback
            return CGSize(width: 100, height: 100)
        }
        set {
            super.itemSize = newValue
        }
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}
