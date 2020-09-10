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
    
    // MARK: -
    
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
    
    // MARK: -
    
    func cellForItemAt(indexPath: IndexPath, collectionView: UICollectionView, cell: UICollectionViewCell, metadata: tableMetadata, metadataFolder: tableMetadata?, serverUrl: String, isEditMode: Bool, selectocId: [String], autoUploadFileName: String, autoUploadDirectory: String, hideButtonMore: Bool, downloadThumbnail: Bool, shares: [tableShare]?, source: UIViewController, dataSource: NCDataSource?) {
        
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
            
            cell.imageItem.image = nil
            cell.imageItem.backgroundColor = nil
            
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
                } else {
                    if metadata.hasPreview {
                        cell.imageItem.backgroundColor = .lightGray
                    } else {
                        if metadata.iconName.count > 0 {
                            cell.imageItem.image = UIImage.init(named: metadata.iconName)
                        } else {
                            cell.imageItem.image = UIImage.init(named: "file")
                        }
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
            if metadata.status == k_metadataStatusInDownload || metadata.status == k_metadataStatusDownloading ||  metadata.status >= k_metadataStatusTypeUpload {
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
            
            cell.imageItem.image = nil
            cell.imageItem.backgroundColor = nil
            
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
                } else {
                    if metadata.hasPreview {
                        cell.imageItem.backgroundColor = .lightGray
                    } else {
                        if metadata.iconName.count > 0 {
                            cell.imageItem.image = UIImage.init(named: metadata.iconName)
                        } else {
                            cell.imageItem.image = UIImage.init(named: "file")
                        }
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
            if metadata.status == k_metadataStatusInDownload || metadata.status == k_metadataStatusDownloading ||  metadata.status >= k_metadataStatusTypeUpload {
                cell.progressView.isHidden = false
                cell.setButtonMore(named: "stop")
            } else {
                cell.progressView.isHidden = true
                cell.progressView.progress = 0.0
                cell.setButtonMore(named: "more")
            }
        }
    }
    
    // MARK: -
    
    func notificationDeleteFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata, errorCode: Int, errorDescription: String ,onlyLocal: Bool) {
        if errorCode == 0 {
            if onlyLocal {
                if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
                    let indexPath = IndexPath(row: row, section: 0)
                    collectionView?.reloadItems(at: [indexPath])
                }
            } else {
                if let row = dataSource?.deleteMetadata(ocId: metadata.ocId) {
                    let indexPath = IndexPath(row: row, section: 0)
                    collectionView?.performBatchUpdates({
                        collectionView?.deleteItems(at: [indexPath])
                    }, completion: { (_) in
                        collectionView?.reloadData()
                    })
                }
            }
        } else {
            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
        }
    }
    
    func notificationMoveFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata, errorCode: Int, errorDescription: String) {
        if errorCode == 0 {
            if let row = dataSource?.deleteMetadata(ocId: metadata.ocId) {
                let indexPath = IndexPath(row: row, section: 0)
                collectionView?.performBatchUpdates({
                    collectionView?.deleteItems(at: [indexPath])
                }, completion: { (_) in
                    collectionView?.reloadData()
                })
            }
        } else {
            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
        }
    }
    
    func notificationRenameFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata, errorCode: Int, errorDescription: String) {
        if errorCode == 0 {
            if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
                let indexPath = IndexPath(row: row, section: 0)
                collectionView?.performBatchUpdates({
                    collectionView?.reloadItems(at: [indexPath])
                }, completion: { (_) in
                    collectionView?.reloadData()
                })
            }
        } else {
            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
        }
    }
    
    func notificationCreateFolder(collectionView: UICollectionView?, dataSource: NCDataSource?, fileName: String, serverUrl: String, errorCode: Int, errorDescription: String) {
        if errorCode == 0 {
        } else {
            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
        }
    }
    
    func notificationFavoriteFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata, favorite: Bool, errorCode: Int, errorDescription: String) {
        if errorCode == 0 {
            if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
                let indexPath = IndexPath(row: row, section: 0)
                collectionView?.reloadItems(at: [indexPath])
            }
            if favorite {
                if CCUtility.getFavoriteOffline() {
                    NCOperationQueue.shared.synchronizationMetadata(metadata, selector: selectorDownloadAllFile)
                } else {
                    NCOperationQueue.shared.synchronizationMetadata(metadata, selector: selectorReadFile)
                }
            }
        } else {
            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
        }
    }
    
    func notificationDownloadStartFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata) {
        if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
            let indexPath = IndexPath(row: row, section: 0)
            collectionView?.reloadItems(at: [indexPath])
        }
    }
    
    func notificationDownloadedFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata) {
        if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
            let indexPath = IndexPath(row: row, section: 0)
            collectionView?.reloadItems(at: [indexPath])
        }
    }
    
    func notificationDownloadCancelFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata) {
        if let row = dataSource?.reloadMetadata(ocId: metadata.ocId) {
            let indexPath = IndexPath(row: row, section: 0)
            collectionView?.reloadItems(at: [indexPath])
        }
    }
    
    func notificationUploadStartFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata) {
        if let row = dataSource?.addMetadata(metadata) {
            let indexPath = IndexPath(row: row, section: 0)
            collectionView?.performBatchUpdates({
                collectionView?.insertItems(at: [indexPath])
            }, completion: { (_) in
                collectionView?.reloadData()
            })
        }
    }
    
    func notificationUploadedFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata, ocIdTemp: String) {
        _ = dataSource?.reloadMetadata(ocId: metadata.ocId, ocIdTemp: ocIdTemp)
        collectionView?.reloadData()
    }
    
    func notificationUploadCancelFile(collectionView: UICollectionView?, dataSource: NCDataSource?, metadata: tableMetadata) -> Bool {
        if let row = dataSource?.deleteMetadata(ocId: metadata.ocId) {
            let indexPath = IndexPath(row: row, section: 0)
            collectionView?.performBatchUpdates({
                collectionView?.deleteItems(at: [indexPath])
            }, completion: { (_) in
                collectionView?.reloadData()
            })
            return true
        }
        return false
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

// MARK: - NCSelect + Delegate

extension NCCollectionCommon: NCSelectDelegate {
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, array: [Any], buttonType: String, overwrite: Bool) {
        if (serverUrl != nil && array.count > 0) {
            var move = true
            if buttonType == "done1" { move = false }
            
            for metadata in array as! [tableMetadata] {
                NCOperationQueue.shared.copyMove(metadata: metadata, serverUrl: serverUrl!, overwrite: overwrite, move: move)
            }
        }
    }

    func openSelectView(viewController: UIViewController, array: [Any]) {
        
        let navigationController = UIStoryboard.init(name: "NCSelect", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let vc = navigationController.topViewController as! NCSelect
        
        vc.delegate = self
        vc.hideButtonCreateFolder = false
        vc.selectFile = false
        vc.includeDirectoryE2EEncryption = false
        vc.includeImages = false
        vc.type = ""
        vc.titleButtonDone = NSLocalizedString("_move_", comment: "")
        vc.titleButtonDone1 = NSLocalizedString("_copy_",comment: "")
        vc.isButtonDone1Hide = false
        vc.isOverwriteHide = false
        vc.keyLayout = k_layout_view_move
        vc.array = array
        
        navigationController.modalPresentationStyle = .fullScreen
        viewController.present(navigationController, animated: true, completion: nil)
    }
}

// MARK: - Nextcloud CollectionView Common

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, NCListCellDelegate, NCGridCellDelegate, NCSectionHeaderMenuDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate  {
        
    @IBOutlet weak var collectionView: UICollectionView!

    @objc var serverUrl = ""
        
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
       
    internal var metadataPush: tableMetadata?
    internal var isEditMode = false
    internal var selectOcId: [String] = []
        
    internal var dataSource: NCDataSource?
        
    internal var layout = ""
    internal var groupBy = ""
    internal var titleButton = ""
    internal var itemForLine = 0

    private var autoUploadFileName = ""
    private var autoUploadDirectory = ""
        
    private var listLayout: NCListLayout!
    private var gridLayout: NCGridLayout!
            
    private let headerMenuHeight: CGFloat = 50
    private let sectionHeaderHeight: CGFloat = 20
    private let footerHeight: CGFloat = 50
        
    internal let refreshControl = UIRefreshControl()
    
    // DECLARE
    internal var layoutKey = ""
    internal var titleCurrentFolder = ""
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Cell
        collectionView.register(UINib.init(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib.init(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        
        // Header
        collectionView.register(UINib.init(nibName: "NCSectionHeaderMenu", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderMenu")
        collectionView.register(UINib.init(nibName: "NCSectionHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeader")
        
        // Footer
        collectionView.register(UINib.init(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        
        collectionView.alwaysBounceVertical = true

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()
        
        // Refresh Control
        collectionView.addSubview(refreshControl)
        refreshControl.tintColor = NCBrandColor.sharedInstance.brandText
        refreshControl.backgroundColor = NCBrandColor.sharedInstance.brandElement
        refreshControl.addTarget(self, action: #selector(reloadDataSourceNetwork), for: .valueChanged)
        
        // empty Data Source
        self.collectionView.emptyDataSetDelegate = self
        self.collectionView.emptyDataSetSource = self
        
        // 3D Touch peek and pop
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: view)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: k_notificationCenter_reloadDataSource), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_copyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(createFolder(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_createFolder), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_favoriteFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadStartFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadCancelFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(uploadStartFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadCancelFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_progressTask), object:nil)

        changeTheming()
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.navigationItem.title = titleCurrentFolder
                
        // get auto upload folder
        autoUploadFileName = NCManageDatabase.sharedInstance.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.sharedInstance.getAccountAutoUploadDirectory(urlBase: appDelegate.urlBase, account: appDelegate.account)
        
        (layout, _, _, groupBy, _, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: layoutKey)
        gridLayout.itemForLine = CGFloat(itemForLine)
        
        if layout == k_layout_list {
            collectionView?.collectionViewLayout = listLayout
        } else {
            collectionView?.collectionViewLayout = gridLayout
        }
        
        reloadDataSource()
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        reloadDataSourceNetwork()
    }
        
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }
    
    // MARK: - Utility
    
    @objc func minCharTextFieldDidChange(sender: UITextField) {
        guard let alertController = self.presentedViewController as? UIAlertController else { return }
        guard let password = alertController.textFields?.first else { return }
        guard let ok = alertController.actions.last else { return }
        ok.isEnabled =  password.text?.count ?? 0 >= 8
    }
    
    // MARK: - NotificationCenter

    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: collectionView, form: false)
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let onlyLocal = userInfo["onlyLocal"] as? Bool, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String {
                NCCollectionCommon.shared.notificationDeleteFile(collectionView: collectionView, dataSource: dataSource, metadata: metadata, errorCode: errorCode, errorDescription: errorDescription, onlyLocal: onlyLocal)
            }
        }
    }
   
    @objc func moveFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let _ = userInfo["metadataNew"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String {
                NCCollectionCommon.shared.notificationMoveFile(collectionView: collectionView, dataSource: dataSource, metadata: metadata, errorCode: errorCode, errorDescription: errorDescription)
            }
        }
    }
    
    @objc func copyFile(_ notification: NSNotification) { }
    
    @objc func renameFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String {
                NCCollectionCommon.shared.notificationRenameFile(collectionView: collectionView, dataSource: dataSource, metadata: metadata, errorCode: errorCode, errorDescription: errorDescription)
            }
        }
    }
    
    @objc func createFolder(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let fileName = userInfo["fileName"] as? String, let serverUrl = userInfo["serverUrl"] as? String,let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String {
                NCCollectionCommon.shared.notificationCreateFolder(collectionView: collectionView, dataSource: dataSource, fileName: fileName, serverUrl: serverUrl, errorCode: errorCode, errorDescription: errorDescription)
            }
        }
    }
    
    @objc func favoriteFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let favorite = userInfo["favorite"] as? Bool, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String {
                NCCollectionCommon.shared.notificationFavoriteFile(collectionView: collectionView, dataSource: dataSource, metadata: metadata, favorite: favorite, errorCode: errorCode, errorDescription: errorDescription)
            }
        }
    }
    
    @objc func downloadStartFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                NCCollectionCommon.shared.notificationDownloadStartFile(collectionView: collectionView, dataSource: dataSource, metadata: metadata)
            }
        }
    }
    
    @objc func downloadedFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let _ = userInfo["errorCode"] as? Int {
                NCCollectionCommon.shared.notificationDownloadedFile(collectionView: collectionView, dataSource: dataSource, metadata: metadata)
            }
        }
    }
        
    @objc func downloadCancelFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                NCCollectionCommon.shared.notificationDownloadCancelFile(collectionView: collectionView, dataSource: dataSource, metadata: metadata)
            }
        }
    }
    
    @objc func uploadStartFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.serverUrl == serverUrl && metadata.account == appDelegate.account {
                    NCCollectionCommon.shared.notificationUploadStartFile(collectionView: collectionView, dataSource: dataSource, metadata: metadata)
                }
            }
        }
    }
        
    @objc func uploadedFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let ocIdTemp = userInfo["ocIdTemp"] as? String, let _ = userInfo["errorCode"] as? Int {
                if metadata.serverUrl == serverUrl && metadata.account == appDelegate.account {
                    NCCollectionCommon.shared.notificationUploadedFile(collectionView: collectionView, dataSource: dataSource, metadata: metadata, ocIdTemp:ocIdTemp)
                }
            }
        }
    }
    
    @objc func uploadCancelFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.serverUrl == serverUrl && metadata.account == appDelegate.account {
                    if !NCCollectionCommon.shared.notificationUploadCancelFile(collectionView: collectionView, dataSource: dataSource, metadata: metadata) {
                        self.reloadDataSource()
                    }
                }
            }
        }
    }
        
    @objc func triggerProgressTask(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String {
                let progressNumber = userInfo["progress"] as? NSNumber ?? 0
                let progress = progressNumber.floatValue
                NCCollectionCommon.shared.notificationTriggerProgressTask(collectionView: collectionView, dataSource: dataSource, ocId: ocId, progress: progress)
            }
        }
    }
        
    // MARK: DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return nil
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        return nil
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return nil
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
        
    // MARK: TAP EVENT
    
    func tapSwitchHeader(sender: Any) {
        
        if collectionView.collectionViewLayout == gridLayout {
            // list layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                    self.collectionView.setContentOffset(CGPoint(x:0,y:0), animated: false)
                })
            })
            layout = k_layout_list
            NCUtility.shared.setLayoutForView(key: layoutKey, layout: layout)
        } else {
            // grid layout
            UIView.animate(withDuration: 0.0, animations: {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: false, completion: { (_) in
                    self.collectionView.reloadData()
                    self.collectionView.setContentOffset(CGPoint(x:0,y:0), animated: false)
                })
            })
            layout = k_layout_grid
            NCUtility.shared.setLayoutForView(key: layoutKey, layout: layout)
        }
    }
    
    func tapOrderHeader(sender: Any) {
        
        let sortMenu = NCSortMenu()
        sortMenu.toggleMenu(viewController: self, key: layoutKey, sortButton: sender as? UIButton, serverUrl: serverUrl)
    }
    
    func tapMoreHeader(sender: Any) {
        
    }
    
    func tapMoreListItem(with objectId: String, namedButtonMore: String, sender: Any) {
        tapMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, sender: sender)
    }
    
    func tapShareListItem(with objectId: String, sender: Any) {
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(objectId) else {
            return
        }
        
        NCMainCommon.shared.openShare(ViewController: self, metadata: metadata, indexPage: 2)
    }
        
    func tapMoreGridItem(with objectId: String, namedButtonMore: String, sender: Any) {
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(objectId) else { return }
        guard let tabBarController = self.tabBarController else { return }

        if namedButtonMore == "more" {
            toggleMoreMenu(viewController: tabBarController, metadata: metadata, selectOcId: selectOcId)
        } else if namedButtonMore == "stop" {
            NCMainCommon.shared.cancelTransferMetadata(metadata, uploadStatusForcedStart: false)
        }
    }
    
    // MARK: SEGUE
    
    @objc func segue(metadata: tableMetadata) {
        self.metadataPush = metadata
        performSegue(withIdentifier: "segueDetail", sender: self)
    }
        
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let photoDataSource: NSMutableArray = []
        
        for metadata in (dataSource?.metadatas ?? [tableMetadata]()) {
            if metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video {
                photoDataSource.add(metadata)
            }
        }
        
        if let segueNavigationController = segue.destination as? UINavigationController {
            if let segueViewController = segueNavigationController.topViewController as? NCDetailViewController {
                segueViewController.metadata = metadataPush
            }
        }
    }
    
    // MARK: - NC API & Algorithm
    
    @objc func reloadDataSource() { }
    @objc func reloadDataSourceNetwork() { }
}

// MARK: - 3D Touch peek and pop

extension NCCollectionViewCommon: UIViewControllerPreviewingDelegate {
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        guard let point = collectionView?.convert(location, from: collectionView?.superview) else { return nil }
        guard let indexPath = collectionView?.indexPathForItem(at: point) else { return nil }
        guard let metadata = dataSource?.cellForItemAt(indexPath: indexPath) else { return nil }
        guard let viewController = UIStoryboard(name: "CCPeekPop", bundle: nil).instantiateViewController(withIdentifier: "PeekPopImagePreview") as? CCPeekPop else { return nil }

        viewController.metadata = metadata

        if layout == k_layout_grid {
            guard let cell = collectionView?.cellForItem(at: indexPath) as? NCGridCell else { return nil }
            previewingContext.sourceRect = cell.frame
            viewController.imageFile = cell.imageItem.image
        } else {
            guard let cell = collectionView?.cellForItem(at: indexPath) as? NCListCell else { return nil }
            previewingContext.sourceRect = cell.frame
            viewController.imageFile = cell.imageItem.image
        }
        
        viewController.showOpenIn = true
        viewController.showOpenQuickLook = NCUtility.shared.isQuickLookDisplayable(metadata: metadata)
        viewController.showShare = false
        
        return viewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        
        guard let indexPath = collectionView?.indexPathForItem(at: previewingContext.sourceRect.origin) else { return }
        
        collectionView(collectionView, didSelectItemAt: indexPath)
    }
}

// MARK: - Collection View
extension NCCollectionViewCommon: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) { }
}

extension NCCollectionViewCommon: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if (indexPath.section == 0) {
            
            if kind == UICollectionView.elementKindSectionHeader {
                
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderMenu", for: indexPath) as! NCSectionHeaderMenu
                
                if collectionView.collectionViewLayout == gridLayout {
                    header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
                } else {
                    header.buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchGrid"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
                }
                
                header.delegate = self
                header.backgroundColor = NCBrandColor.sharedInstance.backgroundView
                header.separator.backgroundColor = NCBrandColor.sharedInstance.separator
                header.setStatusButton(count: dataSource?.metadatas.count ?? 0)
                header.setTitleSorted(datasourceTitleButton: titleButton)
                
                if groupBy == "none" {
                    header.labelSection.isHidden = true
                    header.labelSectionHeightConstraint.constant = 0
                } else {
                    header.labelSection.isHidden = false
                    header.setTitleLabel(title: "")
                    header.labelSectionHeightConstraint.constant = sectionHeaderHeight
                }
                
                return header
                
            } else {
                
                let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
                
                let info = dataSource?.getFilesInformation()
                footer.setTitleLabel(directories: info?.directories ?? 0, files: info?.files ?? 0, size: info?.size ?? 0)
                
                return footer
            }
            
        } else {
            
            if kind == UICollectionView.elementKindSectionHeader {
                
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeader", for: indexPath) as! NCSectionHeader
                
                header.setTitleLabel(title: "")
                
                return header
                
            } else {
                
                let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as! NCSectionFooter
                
                let info = dataSource?.getFilesInformation()
                footer.setTitleLabel(directories: info?.directories ?? 0, files: info?.files ?? 0, size: info?.size ?? 0)
                
                return footer
            }
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource?.numberOfItemsInSection(section: section) ?? 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell: UICollectionViewCell
        
        guard let metadata = dataSource?.cellForItemAt(indexPath: indexPath) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
        }
        
        if layout == k_layout_grid {
            
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as! NCGridCell
           
        } else {
            
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "listCell", for: indexPath) as! NCListCell
        }
        
        let shares = NCManageDatabase.sharedInstance.getTableShares(account: metadata.account, serverUrl: metadata.serverUrl, fileName: metadata.fileName)
        
        NCCollectionCommon.shared.cellForItemAt(indexPath: indexPath, collectionView: collectionView, cell: cell, metadata: metadata, metadataFolder: nil, serverUrl: metadata.serverUrl, isEditMode: isEditMode, selectocId: selectOcId, autoUploadFileName: autoUploadFileName, autoUploadDirectory: autoUploadDirectory, hideButtonMore: false, downloadThumbnail: true, shares: shares, source: self, dataSource: dataSource)
        
        return cell
    }
}

extension NCCollectionViewCommon: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 0 {
            if groupBy == "none" {
                return CGSize(width: collectionView.frame.width, height: headerMenuHeight)
            } else {
                return CGSize(width: collectionView.frame.width, height: headerMenuHeight + sectionHeaderHeight)
            }
        } else {
            return CGSize(width: collectionView.frame.width, height: sectionHeaderHeight)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        let sections = 1
        if (section == sections - 1) {
            return CGSize(width: collectionView.frame.width, height: footerHeight)
        } else {
            return CGSize(width: collectionView.frame.width, height: 0)
        }
    }
}
