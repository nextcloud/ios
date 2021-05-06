//
//  NCFunctionCenter.swift
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
import NCCommunication

@objc class NCFunctionCenter: NSObject, UIDocumentInteractionControllerDelegate, NCSelectDelegate {
    @objc public static let shared: NCFunctionCenter = {
        let instance = NCFunctionCenter()
        
        NotificationCenter.default.addObserver(instance, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(instance, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var viewerQuickLook: NCViewerQuickLook?
    var documentController: UIDocumentInteractionController?
    
    //MARK: - Download

    @objc func downloadedFile(_ notification: NSNotification) {
            
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let selector = userInfo["selector"] as? String, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                
                if metadata.account != appDelegate.account { return }
                
                if errorCode == 0 {
                    
                    let fileURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
                    documentController = UIDocumentInteractionController(url: fileURL)
                    documentController?.delegate = self

                    switch selector {
                    case NCGlobal.shared.selectorLoadFileQuickLook:
                        
                        let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
                        CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: fileNamePath)

                        viewerQuickLook = NCViewerQuickLook.init()
                        viewerQuickLook?.quickLook(url: URL(fileURLWithPath: fileNamePath))
                        
                    case NCGlobal.shared.selectorLoadFileView:
                        
                        if UIApplication.shared.applicationState == UIApplication.State.active {
                                                        
                            if metadata.contentType.contains("opendocument") && !NCUtility.shared.isRichDocument(metadata) {
                                
                                if let view = appDelegate.window?.rootViewController?.view {
                                    documentController?.presentOptionsMenu(from: CGRect.zero, in: view, animated: true)
                                }
                                
                            } else if metadata.typeFile == NCGlobal.shared.metadataTypeFileCompress || metadata.typeFile == NCGlobal.shared.metadataTypeFileUnknown {

                                if let view = appDelegate.window?.rootViewController?.view {
                                    documentController?.presentOptionsMenu(from: CGRect.zero, in: view, animated: true)
                                }
                                
                            } else if metadata.typeFile == NCGlobal.shared.metadataTypeFileImagemeter {
                                
                                if let view = appDelegate.window?.rootViewController?.view {
                                    documentController?.presentOptionsMenu(from: CGRect.zero, in: view, animated: true)
                                }
                                
                            } else {
                                
                                if let viewController = self.appDelegate.activeViewController {
                                    NCViewer.shared.view(viewController: viewController, metadata: metadata, metadatas: [metadata])
                                }
                            }
                        }
                        
                    case NCGlobal.shared.selectorOpenIn:
                        
                        if UIApplication.shared.applicationState == UIApplication.State.active {
                            
                            if let view = appDelegate.window?.rootViewController?.view {
                                documentController?.presentOptionsMenu(from: CGRect.zero, in: view, animated: true)
                            }
                        }
                        
                    case NCGlobal.shared.selectorLoadCopy:
                        
                        copyPasteboard()
                        
                    case NCGlobal.shared.selectorLoadOffline:
                        
                        NCManageDatabase.shared.setLocalFile(ocId: metadata.ocId, offline: true)
                       
                    case NCGlobal.shared.selectorPrint:
                        
                        printDocument(metadata: metadata)
                        
                    case NCGlobal.shared.selectorSaveAlbum:
                        
                        saveAlbum(metadata: metadata)
                       
                    case NCGlobal.shared.selectorSaveBackground:
                        
                        saveBackground(metadata: metadata)
                        
                    case NCGlobal.shared.selectorSaveAlbumLivePhotoIMG, NCGlobal.shared.selectorSaveAlbumLivePhotoMOV:
                        
                        var metadata = metadata
                        var metadataMOV = metadata
                        guard let metadataTMP = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) else { break }
                        
                        if selector == NCGlobal.shared.selectorSaveAlbumLivePhotoIMG {
                            metadataMOV = metadataTMP
                        }
                        
                        if selector == NCGlobal.shared.selectorSaveAlbumLivePhotoMOV {
                            metadata = metadataTMP
                        }
                            
                        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && CCUtility.fileProviderStorageExists(metadataMOV.ocId, fileNameView: metadataMOV.fileNameView) {
                            saveLivePhotoToDisk(metadata: metadata, metadataMov: metadataMOV, progressView: nil, viewActivity: self.appDelegate.window?.rootViewController?.view)
                        }
                        
                    default:
                        
                        break
                    }
                            
                } else {
                    
                    // File do not exists on server, remove in local
                    if (errorCode == NCGlobal.shared.errorResourceNotFound || errorCode == NCGlobal.shared.errorBadServerResponse) {
                        
                        do {
                            try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                        } catch { }
                        
                        NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                        NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                        
                    } else {
                        
                        NCContentPresenter.shared.messageNotification("_download_file_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                }
            }
        }
    }
    
    //MARK: - Upload

    @objc func uploadedFile(_ notification: NSNotification) {
    
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let errorCode = userInfo["errorCode"] as? Int, let errorDescription = userInfo["errorDescription"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                
                if metadata.account == appDelegate.account {
                    if errorCode != 0 {
                        if errorCode != -999 && errorCode != 401 && errorDescription != "" {
                            NCContentPresenter.shared.messageNotification("_upload_file_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: -

    func openShare(ViewController: UIViewController, metadata: tableMetadata, indexPage: Int) {
        
        let shareNavigationController = UIStoryboard(name: "NCShare", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let shareViewController = shareNavigationController.topViewController as! NCSharePaging
        
        shareViewController.metadata = metadata
        shareViewController.indexPage = indexPage
        
        shareNavigationController.modalPresentationStyle = .formSheet
        ViewController.present(shareNavigationController, animated: true, completion: nil)
    }
     
    // MARK: -
    
    func openDownload(metadata: tableMetadata, selector: String) {
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": selector, "errorCode": 0, "errorDescription": "" ])
                                    
        } else {
            
            NCNetworking.shared.download(metadata: metadata, selector: selector) { (_) in }
        }
    }
        
    // MARK: - Print
    
    func printDocument(metadata: tableMetadata) {
    
        let fileNameURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        
        if UIPrintInteractionController.canPrint(fileNameURL) {
            
            let printInfo = UIPrintInfo(dictionary: nil)
            printInfo.jobName = fileNameURL.lastPathComponent
            printInfo.outputType = .photo

            let printController = UIPrintInteractionController.shared
            printController.printInfo = printInfo
            printController.showsNumberOfCopies = true
            printController.printingItem = fileNameURL
            printController.present(animated: true, completionHandler: nil)
        }
    }
    
    // MARK: - Save photo
    
    func saveAlbum(metadata: tableMetadata) {
        
        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let status = PHPhotoLibrary.authorizationStatus()

        if metadata.typeFile == NCGlobal.shared.metadataTypeFileImage && status == PHAuthorizationStatus.authorized {
            
            if let image = UIImage.init(contentsOfFile: fileNamePath) {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(SaveAlbum(_:didFinishSavingWithError:contextInfo:)), nil)
            } else {
                NCContentPresenter.shared.messageNotification("_save_selected_files_", description: "_file_not_saved_cameraroll_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorFileNotSaved)
            }
            
        } else if metadata.typeFile == NCGlobal.shared.metadataTypeFileVideo && status == PHAuthorizationStatus.authorized {
            
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileNamePath) {
                UISaveVideoAtPathToSavedPhotosAlbum(fileNamePath, self, #selector(SaveAlbum(_:didFinishSavingWithError:contextInfo:)), nil)
            } else {
                NCContentPresenter.shared.messageNotification("_save_selected_files_", description: "_file_not_saved_cameraroll_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorFileNotSaved)
            }
            
        } else if status != PHAuthorizationStatus.authorized {
            
            NCContentPresenter.shared.messageNotification("_access_photo_not_enabled_", description: "_access_photo_not_enabled_msg_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorFileNotSaved)
        }
    }
    
    @objc private func SaveAlbum(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        
        if error != nil {
            NCContentPresenter.shared.messageNotification("_save_selected_files_", description: "_file_not_saved_cameraroll_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorFileNotSaved)
        }
    }
    
    func saveLivePhoto(metadata: tableMetadata, metadataMOV: tableMetadata) {
        
        if !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbumLivePhotoIMG)
        }
        
        if !CCUtility.fileProviderStorageExists(metadataMOV.ocId, fileNameView: metadataMOV.fileNameView) {
            NCOperationQueue.shared.download(metadata: metadataMOV, selector: NCGlobal.shared.selectorSaveAlbumLivePhotoMOV)
        }
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && CCUtility.fileProviderStorageExists(metadataMOV.ocId, fileNameView: metadataMOV.fileNameView) {
            saveLivePhotoToDisk(metadata: metadata, metadataMov: metadataMOV, progressView: nil, viewActivity: self.appDelegate.window?.rootViewController?.view)
        }
    }
    
    func saveLivePhotoToDisk(metadata: tableMetadata, metadataMov: tableMetadata, progressView: UIProgressView?, viewActivity: UIView?) {
        
        let fileNameImage = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        let fileNameMov = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadataMov.ocId, fileNameView: metadataMov.fileNameView)!)
        
        if let view = viewActivity {
            NCUtility.shared.startActivityIndicator(backgroundView: view, blurEffect: true)
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
                        NCContentPresenter.shared.messageNotification("_error_", description: "_livephoto_save_error_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
                    }
                }
            } else {
                NCContentPresenter.shared.messageNotification("_error_", description: "_livephoto_save_error_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
            }
        })
    }
    
    func saveBackground(metadata: tableMetadata) {
        
        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let destination = CCUtility.getDirectoryGroup().appendingPathComponent(NCGlobal.shared.appBackground).path + "/" + metadata.fileNameView
        
        if NCUtilityFileSystem.shared.copyFile(atPath: fileNamePath, toPath: destination) {
            
            if appDelegate.activeViewController is NCCollectionViewCommon {
                let viewController: NCCollectionViewCommon = appDelegate.activeViewController as! NCCollectionViewCommon
                let layoutKey = viewController.layoutKey
                let serverUrl = viewController.serverUrl
                if serverUrl == metadata.serverUrl {
                    NCUtility.shared.setBackgroundImageForView(key: layoutKey, serverUrl: serverUrl, imageBackgroud: metadata.fileNameView, imageBackgroudContentMode: "")
                    viewController.setLayout()
                }
            }
        }
    }
    
    // MARK: - Copy & Paste
    
    func copyPasteboard() {
        
        var metadatas: [tableMetadata] = []
        var items = [[String : Any]]()
        
        for ocId in appDelegate.pasteboardOcIds {
            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                metadatas.append(metadata)
            }
        }
        
        for metadata in metadatas {
            
            if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                do {
                    // Get Data
                    let data = try Data.init(contentsOf: URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)))
                    // Pasteboard item
                    if let unmanagedFileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (metadata.fileNameView as NSString).pathExtension as CFString, nil) {
                        let fileUTI = unmanagedFileUTI.takeRetainedValue() as String
                        items.append([fileUTI:data])
                    }
                } catch {
                    print("error")
                }
            } else {
                NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadCopy) { (_) in }
            }
        }
        
        UIPasteboard.general.setItems(items, options: [:])
    }

    func pastePasteboard(serverUrl: String) {
                
        for (index, items) in UIPasteboard.general.items.enumerated() {
            for item in items {
                let pasteboardType = item.key
                if let data = UIPasteboard.general.data(forPasteboardType: pasteboardType, inItemSet: IndexSet([index]))?.first {
                    let results = NCCommunicationCommon.shared.getDescriptionFile(inUTI: pasteboardType as CFString)
                    if results.resultTypeFile != NCCommunicationCommon.typeFile.unknow.rawValue {
                        uploadPasteFile(fileName: results.resultFilename, ext: results.resultExtension, contentType: pasteboardType, serverUrl: serverUrl, data: data)
                    }
                }
            }
        }
    }

    private func uploadPasteFile(fileName: String, ext: String, contentType: String, serverUrl: String, data: Data) {
        
        do {
            let fileNameView = fileName + "_" + CCUtility.getIncrementalNumber() + "." + ext
            let ocId = UUID().uuidString
            let filePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView)!
            
            try data.write(to: URL(fileURLWithPath: filePath))
           
            let metadataForUpload = NCManageDatabase.shared.createMetadata(account: appDelegate.account, fileName: fileNameView, fileNameView: fileNameView, ocId: ocId, serverUrl: serverUrl, urlBase: appDelegate.urlBase, url: "", contentType: contentType, livePhoto: false, chunk: false)
            
            metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground
            metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
            metadataForUpload.size = NCUtilityFileSystem.shared.getFileSize(filePath: filePath)
            metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
            
            appDelegate.networkingProcessUpload?.createProcessUploads(metadatas: [metadataForUpload])
            
        } catch { }
    }
    
    // MARK: -
    
    func openFileViewInFolder(serverUrl: String, fileName: String) {
        
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
        
        appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
    }
    
    // MARK: - NCSelect + Delegate
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {
        if (serverUrl != nil && items.count > 0) {
            if copy {
                for metadata in items as! [tableMetadata] {
                    NCOperationQueue.shared.copyMove(metadata: metadata, serverUrl: serverUrl!, overwrite: overwrite, move: false)
                }
            } else if move {
                for metadata in items as! [tableMetadata] {
                    NCOperationQueue.shared.copyMove(metadata: metadata, serverUrl: serverUrl!, overwrite: overwrite, move: true)
                }
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
            vc.typeOfCommandView = .copyMove
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
    
    // MARK: - Context Menu Configuration
    
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
            self.appDelegate.pasteboardOcIds = [metadata.ocId]
            self.copyPasteboard()
        }
        
        let detail = UIAction(title: NSLocalizedString("_details_", comment: ""), image: UIImage(systemName: "info") ) { action in
            self.openShare(ViewController: viewController, metadata: metadata, indexPage: 0)
        }
        
        let save = UIAction(title: titleSave, image: UIImage(systemName: "square.and.arrow.down")) { action in
            if metadataMOV != nil {
                self.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV!)
            } else {
                if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    self.saveAlbum(metadata: metadata)
                } else {
                    NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum)
                }
            }
        }
        
        let saveBackground = UIAction(title: NSLocalizedString("_use_as_background_", comment: ""), image: UIImage(systemName: "text.below.photo")) { action in
            if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                self.saveBackground(metadata: metadata)
            } else {
                NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveBackground)
            }
        }
        
        let viewInFolder = UIAction(title: NSLocalizedString("_view_in_folder_", comment: ""), image: UIImage(systemName: "arrow.forward.square")) { action in
            self.openFileViewInFolder(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
        }
        
        let openIn = UIAction(title: NSLocalizedString("_open_in_", comment: ""), image: UIImage(systemName: "square.and.arrow.up") ) { action in
            self.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorOpenIn)
        }
        
        let print = UIAction(title: NSLocalizedString("_print_", comment: ""), image: UIImage(systemName: "printer") ) { action in
            self.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorPrint)
        }
        
        let openQuickLook = UIAction(title: NSLocalizedString("_open_quicklook_", comment: ""), image: UIImage(systemName: "eye")) { action in
            self.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook)
        }
        
        let open = UIMenu(title: NSLocalizedString("_open_", comment: ""), image: UIImage(systemName: "square.and.arrow.up"), children: [openIn, openQuickLook])
        
        let moveCopy = UIAction(title: NSLocalizedString("_move_or_copy_", comment: ""), image: UIImage(systemName: "arrow.up.right.square")) { action in
            self.openSelectView(items: [metadata], viewController: viewController)
        }
        
        let deleteConfirmFile = UIAction(title: titleDeleteConfirmFile, image: UIImage(systemName: "trash"), attributes: .destructive) { action in
            NCNetworking.shared.deleteMetadata(metadata, account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, onlyLocal: false) { (errorCode, errorDescription) in
                if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
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
        
        // ------ MENU -----
        
        if metadata.directory {
             return UIMenu(title: "", children: [detail, moveCopy, delete])
        }
        
        var children: [UIMenuElement] = [detail, open, moveCopy, copy, delete]

        if metadata.typeFile == NCGlobal.shared.metadataTypeFileImage || metadata.typeFile == NCGlobal.shared.metadataTypeFileVideo {
            children.insert(save, at: 2)
        }
        
        if metadata.typeFile == NCGlobal.shared.metadataTypeFileImage || metadata.contentType == "application/pdf" {
            children.insert(print, at: 2)
        }
        
        if enableViewInFolder {
            children.insert(viewInFolder, at: 5)
        }
        
        if metadata.typeFile == NCGlobal.shared.metadataTypeFileImage && viewController is NCCollectionViewCommon && !NCBrandOptions.shared.disable_background_image {
            let viewController: NCCollectionViewCommon = viewController as! NCCollectionViewCommon
            let layoutKey = viewController.layoutKey
            if layoutKey == NCGlobal.shared.layoutViewFiles {
                children.insert(saveBackground, at: children.count-1)
            }
        }
        
        return UIMenu(title: "", image: nil, identifier: nil, children: children)
    }
}

