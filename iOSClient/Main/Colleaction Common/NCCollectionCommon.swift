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
import NCCommunication

class NCCollectionCommon: NSObject, NCSelectDelegate {
    @objc static let shared: NCCollectionCommon = {
        let instance = NCCollectionCommon()
        instance.createImagesThemingColor()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    struct images {
        static var cellFileImage = UIImage()

        static var cellSharedImage = UIImage()
        static var cellCanShareImage = UIImage()
        static var cellShareByLinkImage = UIImage()
        
        static var cellFavouriteImage = UIImage()
        static var cellCommentImage = UIImage()
        static var cellLivePhotoImage = UIImage()
        static var cellOfflineFlag = UIImage()
        static var cellLocal = UIImage()

        static var cellFolderEncryptedImage = UIImage()
        static var cellFolderSharedWithMeImage = UIImage()
        static var cellFolderPublicImage = UIImage()
        static var cellFolderGroupImage = UIImage()
        static var cellFolderExternalImage = UIImage()
        static var cellFolderAutomaticUploadImage = UIImage()
        static var cellFolderImage = UIImage()
        
        static var cellCheckedYes = UIImage()
        static var cellCheckedNo = UIImage()
        
        static var cellButtonMore = UIImage()
        static var cellButtonStop = UIImage()
    }
    
    // MARK: -
    
    @objc func createImagesThemingColor() {
        
        images.cellFileImage = UIImage.init(named: "file")!
        
        images.cellSharedImage = UIImage(named: "share")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        images.cellCanShareImage = UIImage(named: "share")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        images.cellShareByLinkImage = UIImage(named: "sharebylink")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        
        images.cellFavouriteImage = UIImage(named: "favorite")!.image(color: NCBrandColor.shared.yellowFavorite, size: 50)
        images.cellCommentImage = UIImage(named: "comment")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        images.cellLivePhotoImage = UIImage(named: "livePhoto")!.image(color: NCBrandColor.shared.textView, size: 50)
        images.cellOfflineFlag = UIImage.init(named: "offlineFlag")!
        images.cellLocal = UIImage.init(named: "local")!
            
        let folderWidth: CGFloat = UIScreen.main.bounds.width / 3
        images.cellFolderEncryptedImage = UIImage(named: "folderEncrypted")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderSharedWithMeImage = UIImage(named: "folder_shared_with_me")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderPublicImage = UIImage(named: "folder_public")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderGroupImage = UIImage(named: "folder_group")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderExternalImage = UIImage(named: "folder_external")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderAutomaticUploadImage = UIImage(named: "folderAutomaticUpload")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        images.cellFolderImage =  UIImage(named: "folder")!.image(color: NCBrandColor.shared.brandElement, size: folderWidth)
        
        images.cellCheckedYes = UIImage(named: "checkedYes")!.image(color: .darkGray, size: 50)
        images.cellCheckedNo = UIImage(named: "checkedNo")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        
        images.cellButtonMore = UIImage(named: "more")!.image(color: NCBrandColor.shared.graySoft, size: 50)
        images.cellButtonStop = UIImage(named: "stop")!.image(color: NCBrandColor.shared.graySoft, size: 50)
    }
    
    // MARK: - NCSelect + Delegate
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], buttonType: String, overwrite: Bool) {
        if (serverUrl != nil && items.count > 0) {
            var move = true
            if buttonType == "done1" { move = false }
            
            for metadata in items as! [tableMetadata] {
                NCOperationQueue.shared.copyMove(metadata: metadata, serverUrl: serverUrl!, overwrite: overwrite, move: move)
            }
        }
    }

    func openSelectView(items: [Any], viewController: UIViewController) {
        
        let navigationController = UIStoryboard.init(name: "NCSelect", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let topViewController = navigationController.topViewController as! NCSelect
        var listViewController = [NCSelect]()
        
        var copyItems: [Any] = []
        for item in items {
            copyItems.append(item)
        }
        
        let homeUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        var serverUrl = (copyItems[0] as! Nextcloud.tableMetadata).serverUrl
        
        // Setup view controllers such that the current view is of the same directory the items to be copied are in
        while true {
            // If not in the topmost directory, create a new view controller and set correct title.
            // If in the topmost directory, use the default view controller as the base.
            var viewController: NCSelect?
            if serverUrl != homeUrl {
                viewController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateViewController(withIdentifier: "NCSelect.storyboard") as? NCSelect
                if viewController == nil {
                    return
                }
                viewController!.titleCurrentFolder = (serverUrl as NSString).lastPathComponent
            } else {
                viewController = topViewController
            }
            guard let vc = viewController else { return }

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
            vc.items = copyItems
            vc.serverUrl = serverUrl
            
            vc.navigationItem.backButtonTitle = vc.titleCurrentFolder
            listViewController.insert(vc, at: 0)
            
            if serverUrl != homeUrl {
                serverUrl = NCUtilityFileSystem.shared.deletingLastPathComponent(serverUrl: serverUrl, urlBase: appDelegate.urlBase, account: appDelegate.account)
            } else {
                break
            }
        }
        
        navigationController.setViewControllers(listViewController, animated: false)
        navigationController.modalPresentationStyle = .formSheet
        
        viewController.present(navigationController, animated: true, completion: nil)
    }
    
    @objc func openFileViewInFolder(serverUrl: String, fileName: String) {
        
        let viewController = UIStoryboard(name: "NCFileViewInFolder", bundle: nil).instantiateInitialViewController() as! NCFileViewInFolder
        let navigationController = UINavigationController.init(rootViewController: viewController)

        let topViewController = viewController
        var listViewController = [NCFileViewInFolder]()
        var serverUrl = serverUrl
        let homeUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        
        while true {
            
            var viewController: NCFileViewInFolder?
            if serverUrl != homeUrl {
                viewController = UIStoryboard(name: "NCFileViewInFolder", bundle: nil).instantiateInitialViewController() as? NCFileViewInFolder
                if viewController == nil {
                    return
                }
                viewController!.titleCurrentFolder = (serverUrl as NSString).lastPathComponent
            } else {
                viewController = topViewController
            }
            guard let vc = viewController else { return }
            
            vc.serverUrl = serverUrl
            vc.fileName = fileName
            
            vc.navigationItem.backButtonTitle = vc.titleCurrentFolder
            listViewController.insert(vc, at: 0)
            
            if serverUrl != homeUrl {
                serverUrl = NCUtilityFileSystem.shared.deletingLastPathComponent(serverUrl: serverUrl, urlBase: appDelegate.urlBase, account: appDelegate.account)
            } else {
                break
            }
        }
        
        navigationController.setViewControllers(listViewController, animated: false)
        navigationController.modalPresentationStyle = .formSheet
        
        appDelegate.window.rootViewController?.present(navigationController, animated: true, completion: nil)
    }
    
    // MARK: - Save Photo - Video - Live Photo
    
    func saveAlbum(metadata: tableMetadata) {
        
        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let status = PHPhotoLibrary.authorizationStatus()

        if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileImage && status == PHAuthorizationStatus.authorized {
            
            if let image = UIImage.init(contentsOfFile: fileNamePath) {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(SaveAlbum(_:didFinishSavingWithError:contextInfo:)), nil)
            } else {
                NCContentPresenter.shared.messageNotification("_save_selected_files_", description: "_file_not_saved_cameraroll_", delay: NCBrandGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCBrandGlobal.shared.ErrorFileNotSaved)
            }
            
        } else if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileVideo && status == PHAuthorizationStatus.authorized {
            
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileNamePath) {
                UISaveVideoAtPathToSavedPhotosAlbum(fileNamePath, self, #selector(SaveAlbum(_:didFinishSavingWithError:contextInfo:)), nil)
            } else {
                NCContentPresenter.shared.messageNotification("_save_selected_files_", description: "_file_not_saved_cameraroll_", delay: NCBrandGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCBrandGlobal.shared.ErrorFileNotSaved)
            }
            
        } else if status != PHAuthorizationStatus.authorized {
            
            NCContentPresenter.shared.messageNotification("_access_photo_not_enabled_", description: "_access_photo_not_enabled_msg_", delay: NCBrandGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCBrandGlobal.shared.ErrorFileNotSaved)
        }
    }
    
    @objc private func SaveAlbum(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        
        if error != nil {
            NCContentPresenter.shared.messageNotification("_save_selected_files_", description: "_file_not_saved_cameraroll_", delay: NCBrandGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCBrandGlobal.shared.ErrorFileNotSaved)
        }
    }
    
    func saveLivePhoto(metadata: tableMetadata, metadataMOV: tableMetadata) {
        
        if !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            NCOperationQueue.shared.download(metadata: metadata, selector: NCBrandGlobal.shared.selectorSaveAlbumLivePhotoIMG)
        }
        
        if !CCUtility.fileProviderStorageExists(metadataMOV.ocId, fileNameView: metadataMOV.fileNameView) {
            NCOperationQueue.shared.download(metadata: metadataMOV, selector: NCBrandGlobal.shared.selectorSaveAlbumLivePhotoMOV)
        }
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && CCUtility.fileProviderStorageExists(metadataMOV.ocId, fileNameView: metadataMOV.fileNameView) {
            saveLivePhotoToDisk(metadata: metadata, metadataMov: metadataMOV, progressView: nil, viewActivity: self.appDelegate.window.rootViewController?.view)
        }
    }
    
    func saveLivePhotoToDisk(metadata: tableMetadata, metadataMov: tableMetadata, progressView: UIProgressView?, viewActivity: UIView?) {
        
        let fileNameImage = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        let fileNameMov = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadataMov.ocId, fileNameView: metadataMov.fileNameView)!)
        
        if let view = viewActivity {
            NCUtility.shared.startActivityIndicator(view: view)
        }
        
        NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
            DispatchQueue.main.async {
                progressView?.progress = Float(progress)
            }
        }, completion: { livePhoto, resources in
            NCUtility.shared.stopActivityIndicator()
            progressView?.progress = 0
            if resources != nil {
                NCLivePhoto.saveToLibrary(resources!) { (result) in
                    if !result {
                        NCContentPresenter.shared.messageNotification("_error_", description: "_livephoto_save_error_", delay: NCBrandGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCBrandGlobal.shared.ErrorInternalError)
                    }
                }
            } else {
                NCContentPresenter.shared.messageNotification("_error_", description: "_livephoto_save_error_", delay: NCBrandGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCBrandGlobal.shared.ErrorInternalError)
            }
        })
    }
    
    // MARK: - Context Menu COnfiguration
    
    @available(iOS 13.0, *)
    func contextMenuConfiguration(metadata: tableMetadata, viewController: UIViewController, enableDeleteLocal: Bool, enableViewInFolder: Bool) -> UIMenu {
        
        var titleDeleteConfirmFile = NSLocalizedString("_delete_file_", comment: "")
        if metadata.directory { titleDeleteConfirmFile = NSLocalizedString("_delete_folder_", comment: "") }
        var titleSave: String = NSLocalizedString("_save_selected_files_", comment: "")
        let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        if metadataMOV != nil {
            titleSave = NSLocalizedString("_livephoto_save_", comment: "")
        }
        
        let copy = UIAction(title: NSLocalizedString("_copy_file_", comment: ""), image: UIImage(systemName: "doc.on.doc") ) { action in
            if metadataMOV != nil {
                NCCollectionCommon.shared.copyFile(ocIds: [metadata.ocId, metadataMOV!.ocId])
            } else {
                NCCollectionCommon.shared.copyFile(ocIds: [metadata.ocId])
            }
        }
        
        let detail = UIAction(title: NSLocalizedString("_details_", comment: ""), image: UIImage(systemName: "info") ) { action in
            NCNetworkingNotificationCenter.shared.openShare(ViewController: viewController, metadata: metadata, indexPage: 0)
        }
        
        let save = UIAction(title: titleSave, image: UIImage(systemName: "square.and.arrow.down")) { action in
            if metadataMOV != nil {
                NCCollectionCommon.shared.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV!)
            } else {
                if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    self.saveAlbum(metadata: metadata)
                } else {
                    NCOperationQueue.shared.download(metadata: metadata, selector: NCBrandGlobal.shared.selectorSaveAlbum)
                }
            }
        }
        
        let viewInFolder = UIAction(title: NSLocalizedString("_view_in_folder_", comment: ""), image: UIImage(systemName: "arrow.forward.square")) { action in
            NCCollectionCommon.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
        }
        
        let openIn = UIAction(title: NSLocalizedString("_open_in_", comment: ""), image: UIImage(systemName: "square.and.arrow.up") ) { action in
            NCNetworkingNotificationCenter.shared.downloadOpen(metadata: metadata, selector: NCBrandGlobal.shared.selectorOpenIn)
        }
        
        let openQuickLook = UIAction(title: NSLocalizedString("_open_quicklook_", comment: ""), image: UIImage(systemName: "eye")) { action in
            NCNetworkingNotificationCenter.shared.downloadOpen(metadata: metadata, selector: NCBrandGlobal.shared.selectorLoadFileQuickLook)
        }
        
        let open = UIMenu(title: NSLocalizedString("_open_", comment: ""), image: UIImage(systemName: "square.and.arrow.up"), children: [openIn, openQuickLook])
        
        let moveCopy = UIAction(title: NSLocalizedString("_move_or_copy_", comment: ""), image: UIImage(systemName: "arrow.up.right.square")) { action in
            NCCollectionCommon.shared.openSelectView(items: [metadata], viewController: viewController)
        }
        
        let deleteConfirmFile = UIAction(title: titleDeleteConfirmFile, image: UIImage(systemName: "trash"), attributes: .destructive) { action in
            NCNetworking.shared.deleteMetadata(metadata, account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, onlyLocal: false) { (errorCode, errorDescription) in
                if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCBrandGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }
        
        let deleteConfirmLocal = UIAction(title: NSLocalizedString("_remove_local_file_", comment: ""), image: UIImage(systemName: "trash"), attributes: .destructive) { action in
            NCNetworking.shared.deleteMetadata(metadata, account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, onlyLocal: true) { (errorCode, errorDescription) in
            }
        }
        
        var delete = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmLocal, deleteConfirmFile])
        
        if !enableDeleteLocal {
            delete = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmFile])
        }
        
        if metadata.directory {
            delete = UIMenu(title: NSLocalizedString("_delete_folder_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmFile])
        }
        
        if metadata.directory {
             return UIMenu(title: "", children: [detail, moveCopy, delete])
        }
        
        var children: [UIMenuElement] = [copy, detail, moveCopy, open, delete]

        if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileImage || metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileVideo {
            children.insert(save, at: 4)
        }
        
        if enableViewInFolder {
            children.insert(viewInFolder, at: 2)
        }
        
        return UIMenu(title: "", image: nil, identifier: nil, children: children)
    }
    
    // MARK: - Copy & Paste

    func copyFile(ocIds: [String]) {
        var metadatas: [tableMetadata] = []
        var items = [[String : Any]]()

        
        for ocId in ocIds {
            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                metadatas.append(metadata)
            }
        }
        
        for metadata in metadatas {
            
            if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                do {
                    // etag
                    let etagPasteboard = try NSKeyedArchiver.archivedData(withRootObject: metadata.ocId, requiringSecureCoding: false)
                    items.append([NCBrandGlobal.shared.metadataKeyedUnarchiver:etagPasteboard])
                    // Get Data
                    let data = try Data.init(contentsOf: URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)))
                    // image
                    if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileImage {
                        if CCUtility.getExtension(metadata.fileNameView) == "GIF" {
                            items.append([kUTTypeGIF as String:data])
                        } else {
                            items.append([kUTTypeJPEG as String:data])
                        }
                    }
                    // video
                    if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileVideo {
                        items.append([kUTTypeMPEG4 as String:data])
                    }
                } catch {
                    print("error")
                }
            } else {
                NCNetworking.shared.download(metadata: metadata, selector: NCBrandGlobal.shared.selectorLoadCopy) { (_) in }
            }
        }
        
        UIPasteboard.general.setItems(items, options: [:])
    }

    func pasteFiles(serverUrl: String) {
        
        var listData: [String] = []
        
        for item in UIPasteboard.general.items {
            for object in item {
                let contentType = object.key
                let data = object.value
                if contentType == NCBrandGlobal.shared.metadataKeyedUnarchiver {
                    do {
                        if let ocId = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data as! Data) as? String{
                            uploadPasteOcId(ocId, serverUrl: serverUrl)
                        }
                    } catch {
                        print("error")
                    }
                    continue
                }
                if data is String {
                    if listData.contains(data as! String) {
                        continue
                    } else {
                        listData.append(data as! String)
                    }
                }
                let type = NCCommunicationCommon.shared.convertUTItoResultType(fileUTI: contentType as CFString)
                if type.resultTypeFile != NCCommunicationCommon.typeFile.unknow.rawValue && type.resultExtension != "" {
                    uploadPasteFile(fileName: type.resultFilename, ext: type.resultExtension, contentType: contentType, serverUrl: serverUrl, data: data)
                }
            }
        }
    }

    private func uploadPasteFile(fileName: String, ext: String, contentType: String, serverUrl: String, data: Any) {
        do {
            let fileNameView = fileName + "_" + CCUtility.getIncrementalNumber() + "." + ext
            let ocId = UUID().uuidString
            let filePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView)!
            
            if data is UIImage {
                try (data as? UIImage)?.jpegData(compressionQuality: 1)?.write(to: URL(fileURLWithPath: filePath))
            } else if data is Data {
                try (data as? Data)?.write(to: URL(fileURLWithPath: filePath))
            } else if data is String {
                try (data as? String)?.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
            } else {
                return
            }
            
            let metadataForUpload = NCManageDatabase.shared.createMetadata(account: appDelegate.account, fileName: fileNameView, ocId: ocId, serverUrl: serverUrl, urlBase: appDelegate.urlBase, url: "", contentType: contentType, livePhoto: false)
            
            metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground
            metadataForUpload.sessionSelector = NCBrandGlobal.shared.selectorUploadFile
            metadataForUpload.size = NCUtilityFileSystem.shared.getFileSize(filePath: filePath)
            metadataForUpload.status = NCBrandGlobal.shared.metadataStatusWaitUpload
            
            NCManageDatabase.shared.addMetadata(metadataForUpload)
            
        } catch { }
    }

    private func uploadPasteOcId(_ ocId: String, serverUrl: String) {
        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
            if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                let fileNameView = NCUtilityFileSystem.shared.createFileName(metadata.fileNameView, serverUrl: serverUrl, account: appDelegate.account)
                let ocId = NSUUID().uuidString
                
                CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView))
                let metadataForUpload = NCManageDatabase.shared.createMetadata(account: appDelegate.account, fileName: fileNameView, ocId: ocId, serverUrl: serverUrl, urlBase: appDelegate.urlBase, url: "", contentType: "", livePhoto: false)
                
                metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground
                metadataForUpload.sessionSelector = NCBrandGlobal.shared.selectorUploadFile
                metadataForUpload.size = metadata.size
                metadataForUpload.status = NCBrandGlobal.shared.metadataStatusWaitUpload
                
                NCManageDatabase.shared.addMetadata(metadataForUpload)
            }
        }
    }

}


// MARK: - List Layout

class NCListLayout: UICollectionViewFlowLayout {
    
    var itemHeight: CGFloat = 60
    
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
    var itemWidthDefault: CGFloat = 120

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
                
                if collectionView.frame.width < 400 {
                    itemForLine = 3
                } else {
                    itemForLine = collectionView.frame.width / itemWidthDefault
                }
                
                let itemWidth: CGFloat = (collectionView.frame.width - marginLeftRight * 2 - marginLeftRight * (itemForLine - 1)) / itemForLine
                let itemHeight: CGFloat = itemWidth + heightLabelPlusButton
                
                return CGSize(width: itemWidth, height: itemHeight)
            }
            
            // Default fallback
            return CGSize(width: itemWidthDefault, height: itemWidthDefault)
        }
        set {
            super.itemSize = newValue
        }
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}
