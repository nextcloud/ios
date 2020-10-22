//
//  NCViewer.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/10/2020.
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

class NCViewer: NSObject {
    @objc static let shared: NCViewer = {
        let instance = NCViewer()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var viewerQuickLook: NCViewerQuickLook?
    private var metadata = tableMetadata()
    private var metadatas: [tableMetadata] = []
    private var viewerImageViewController: NCViewerImageViewController?

    func view(viewController: UIViewController, metadata: tableMetadata, metadatas: [tableMetadata]? = nil) {

        self.metadata = metadata
        if metadatas != nil {
            self.metadatas = metadatas!
        }
        
        // VIDEO AUDIO
        if metadata.typeFile == k_metadataTypeFile_audio || metadata.typeFile == k_metadataTypeFile_video {
            
            if let navigationController = getPushNavigationController(viewController: viewController, serverUrl: metadata.serverUrl) {
                let viewController:NCViewerVideo = UIStoryboard(name: "NCViewerVideo", bundle: nil).instantiateInitialViewController() as! NCViewerVideo
            
                viewController.metadata = metadata

                navigationController.pushViewController(viewController, animated: true)
            }
            return
        }
        
        // IMAGE
        if metadata.typeFile == k_metadataTypeFile_image {
            viewImage(viewController: viewController)
            return
        }
        
        // DOCUMENTS
        if metadata.typeFile == k_metadataTypeFile_document {
                
            // PDF
            if metadata.contentType == "application/pdf" {
                    
                if let navigationController = getPushNavigationController(viewController: viewController, serverUrl: metadata.serverUrl) {
                    let viewController:NCViewerPDF = UIStoryboard(name: "NCViewerPDF", bundle: nil).instantiateInitialViewController() as! NCViewerPDF
                
                    viewController.metadata = metadata
                
                    navigationController.pushViewController(viewController, animated: true)
                }
                return
            }
            
            // DirectEditinf: Nextcloud Text - OnlyOffice
            if NCUtility.shared.isDirectEditing(account: metadata.account, contentType: metadata.contentType) != nil &&  NCCommunication.shared.isNetworkReachable() {
                
                guard let editor = NCUtility.shared.isDirectEditing(account: metadata.account, contentType: metadata.contentType) else { return }
                if editor == k_editor_text || editor == k_editor_onlyoffice {
                    
                    if metadata.url == "" {
                        
                        var customUserAgent: String?
                        let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!
                        
                        if editor == k_editor_onlyoffice {
                            customUserAgent = NCUtility.shared.getCustomUserAgentOnlyOffice()
                        }
                        
                        NCCommunication.shared.NCTextOpenFile(fileNamePath: fileNamePath, editor: editor, customUserAgent: customUserAgent) { (account, url, errorCode, errorMessage) in
                            
                            if errorCode == 0 && account == self.appDelegate.account && url != nil {
                                
                                if let navigationController = self.getPushNavigationController(viewController: viewController, serverUrl: metadata.serverUrl) {
                                    let viewController:NCViewerNextcloudText = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as! NCViewerNextcloudText
                                
                                    viewController.metadata = metadata
                                    viewController.editor = editor
                                    viewController.link = url!
                                
                                    navigationController.pushViewController(viewController, animated: true)
                                }
                                
                            } else if errorCode != 0 {
                                
                                NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            }
                        }
                        
                    } else {
                        
                        if editor == k_editor_onlyoffice {
                            //self.navigationController?.navigationBar.topItem?.title = ""
                        }
                            
                        if let navigationController = self.getPushNavigationController(viewController: viewController, serverUrl: metadata.serverUrl) {
                            let viewController:NCViewerNextcloudText = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as! NCViewerNextcloudText
                        
                            viewController.metadata = metadata
                            viewController.editor = editor
                            viewController.link = metadata.url
                        
                            navigationController.pushViewController(viewController, animated: true)
                        }
                    }
                } else {
                    NCContentPresenter.shared.messageNotification("_error_", description: "_editor_unknown_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                }
                
                return
            }
            
            // RichDocument: Collabora
            if NCUtility.shared.isRichDocument(metadata) &&  NCCommunication.shared.isNetworkReachable() {
                                
                if metadata.url == "" {
                    
                    NCCommunication.shared.createUrlRichdocuments(fileID: metadata.fileId) { (account, url, errorCode, errorDescription) in
                        
                        if errorCode == 0 && account == self.appDelegate.account && url != nil {
                            
                            if let navigationController = self.getPushNavigationController(viewController: viewController, serverUrl: metadata.serverUrl) {
                                let viewController:NCViewerRichdocument = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as! NCViewerRichdocument
                            
                                viewController.metadata = metadata
                                viewController.link = url!
                            
                                navigationController.pushViewController(viewController, animated: true)
                            }
                            
                        } else if errorCode != 0 {
                            
                            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                    
                } else {
                    
                    if let navigationController = self.getPushNavigationController(viewController: viewController, serverUrl: metadata.serverUrl) {
                        let viewController:NCViewerRichdocument = UIStoryboard(name: "NCViewerRichdocument", bundle: nil).instantiateInitialViewController() as! NCViewerRichdocument
                    
                        viewController.metadata = metadata
                        viewController.link = metadata.url
                    
                        navigationController.pushViewController(viewController, animated: true)
                    }
                }
                
                return
            }
        }
        
        // OTHER
        let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView

        CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: fileNamePath)

        viewerQuickLook = NCViewerQuickLook.init()
        viewerQuickLook?.quickLook(url: URL(fileURLWithPath: fileNamePath))
    }
    
    private func getPushNavigationController(viewController: UIViewController, serverUrl: String) -> UINavigationController? {
        
        if viewController is NCFiles || viewController is NCFavorite || viewController is NCOffline || viewController is NCRecent || viewController is NCFileViewInFolder {
            if serverUrl == appDelegate.activeServerUrl {
                return viewController.navigationController
            }
        }
        return nil
    }
}

//MARK: -

extension NCViewer: NCSelectDelegate {
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], buttonType: String, overwrite: Bool) {
        if let serverUrl = serverUrl {
            if buttonType == "done" {
                NCNetworking.shared.moveMetadata(self.metadata, serverUrlTo: serverUrl, overwrite: overwrite) { (errorCode, errorDescription) in
                    if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                }
            } else {
                NCNetworking.shared.copyMetadata(self.metadata, serverUrlTo: serverUrl, overwrite: overwrite) { (errorCode, errorDescription) in
                    if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                }
            }
        }
    }
}

//MARK: -

extension NCViewer: NCViewerImageViewControllerDelegate, NCViewerImageViewControllerDataSource {

    func viewImage(viewController: UIViewController) {
        NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, mediaDatasorce: true, layoutKey: k_layout_view_media) { (metadatas) in
    
            guard let metadatas = metadatas else { return }
            var index = 0
        
            if let indexFound = metadatas.firstIndex(where: { $0.ocId == self.metadata.ocId }) { index = indexFound }
            // Video -> is a Live Photo ?
            if self.metadata.typeFile == k_metadataTypeFile_video {
                let filename = (self.metadata.fileNameView as NSString).deletingPathExtension.lowercased()
                if let indexFound = metadatas.firstIndex(where: { (($0.fileNameView as NSString).deletingPathExtension.lowercased() as String) == filename && $0.typeFile == k_metadataTypeFile_image }) { index = indexFound }
            }
            self.metadatas = metadatas
            
            self.viewerImageViewController = NCViewerImageViewController(index: index, dataSource: self, delegate: self)
            if self.viewerImageViewController != nil {
                           
                if let navigationController = self.getPushNavigationController(viewController: viewController, serverUrl: self.metadata.serverUrl) {
                    navigationController.pushViewController(self.viewerImageViewController!, animated: true)
                }
            }
        }
    }
    
    func numberOfItems(in viewerImageViewController: NCViewerImageViewController) -> Int {
        return metadatas.count
    }
    
    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, imageAt index: Int, completion: @escaping (_ index: Int, _ image: UIImage?, _ metadata: tableMetadata, _ zoomScale: ZoomScale?, _ error: Error?) -> Void) {
        
        if index >= metadatas.count { return }
        let metadata = metadatas[index]
        let isPreview = CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag)
        let isImage = CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0
        let ext = CCUtility.getExtension(metadata.fileNameView)
        let isFolderEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        
        // Refresh self metadata && title
        if viewerImageViewController.index < metadatas.count {
            self.metadata = metadatas[viewerImageViewController.index]
            //self.navigationController?.navigationBar.topItem?.title = self.metadata.fileNameView
        }
        
        // Status Current
        if index == viewerImageViewController.currentItemIndex {
            statusViewImage(metadata: metadata, viewerImageViewController: viewerImageViewController)
        }
        
        // Preview for Video
        if metadata.typeFile == k_metadataTypeFile_video && !isPreview && isImage {
            
            CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, typeFile: metadata.typeFile)
        }
        
        // Original only for actual
        if metadata.typeFile == k_metadataTypeFile_image && isImage && index == viewerImageViewController.index {
                
            if let image = NCViewerImageCommon.shared.getImage(metadata: metadata) {
                completion(index, image, metadata, ZoomScale.default, nil)
            } else {
                completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: viewerImageViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
            }
                
        // Automatic download for: Encripted
        } else if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) == 0 && isFolderEncrypted{
            
            if NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@ AND session != ''", metadata.ocId)) == nil {
                
                NCNetworking.shared.download(metadata: metadata, selector: "") { (_) in }
            }
            
            completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: viewerImageViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
            
        // Automatic download for: HEIC - GIF - SVG
        } else if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) == 0 && ((metadata.contentType == "image/heic" &&  metadata.hasPreview == false) || ext == "GIF" || ext == "SVG") {
            
            let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
                        
            NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { (_) in
                                
            },  progressHandler: { (progress) in
                                
                //self.progress(Float(progress.fractionCompleted))
                
            }) { (account, etag, date, length, error, errorCode, errorDescription) in
                
                if errorCode == 0 && account == metadata.account {
                    
                    NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                    
                    if let image = NCViewerImageCommon.shared.getImage(metadata: metadata) {
                        completion(index, image, metadata, ZoomScale.default, nil)
                    } else {
                        completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: viewerImageViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                    }
                } else if errorCode != 0 {
                    completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: viewerImageViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                }
                
               // self.progress(0)
            }
        
        // Preview
        } else if isPreview {
                
            if let image = NCViewerImageCommon.shared.getThumbnailImage(metadata: metadata) {
                completion(index, image, metadata, ZoomScale.default, nil)
            } else {
                completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: viewerImageViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
            }
    
        } else if metadata.hasPreview {
                
            let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!
            let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
            let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!
                    
            NCCommunication.shared.downloadPreview(fileNamePathOrFileId: fileNamePath, fileNamePreviewLocalPath: fileNamePreviewLocalPath, widthPreview: Int(k_sizePreview), heightPreview: Int(k_sizePreview), fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: Int(k_sizeIcon)) { (account, imagePreview, imageIcon,  errorCode, errorMessage) in
                if errorCode == 0 && imagePreview != nil {
                    completion(index, imagePreview, metadata, ZoomScale.default, nil)
                } else {
                    completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: viewerImageViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                }
            }
            
        } else {
            completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: viewerImageViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
        }
    }
    
    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, willChangeFocusTo index: Int, view: NCViewerImageContentView, metadata: tableMetadata) {
        
        statusViewImage(metadata: metadata, viewerImageViewController: viewerImageViewController)
    }
    
    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, didChangeFocusTo index: Int, view: NCViewerImageContentView, metadata: tableMetadata) {
        
        let ocId = metadata.ocId
        if metadata.typeFile == k_metadataTypeFile_image && !view.isLoading {
            DispatchQueue.global().async {
                if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
                    if let image = NCViewerImageCommon.shared.getImage(metadata: metadata) {
                        DispatchQueue.main.async {
                            view.image = image
                        }
                    }
                }
            }
        }
    }
    
    func viewerImageViewControllerTap(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        /*
        guard let navigationController = self.navigationController else { return }
        
        if metadata.typeFile == k_metadataTypeFile_image {
        
            if navigationController.isNavigationBarHidden {
                navigateControllerBarHidden(false)
                viewerImageViewController.statusView.isHidden = false
            } else {
                navigateControllerBarHidden(true)
                viewerImageViewController.statusView.isHidden = true
            }
            
            NCViewerImageCommon.shared.imageChangeSizeView(viewerImageViewController: viewerImageViewController, size: self.view.frame.size, metadata: metadata)
            
        } else {
            
            if let viewerImageVideo = UIStoryboard(name: "NCViewerVideo", bundle: nil).instantiateInitialViewController() as? NCViewerVideo {
                viewerImageVideo.metadata = metadata
                present(viewerImageVideo, animated: false) { }
            }
        }
        
        statusViewImage(metadata: metadata, viewerImageViewController: viewerImageViewController)
        */
    }
    
    func viewerImageViewControllerLongPressBegan(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        /*
        viewerImageViewController.statusView.isHidden = true
        viewerImageViewControllerLongPressInProgress = true
        
        let fileName = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
        if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", metadata.account, metadata.serverUrl, fileName)) {
            
            if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0 {
                
                AudioServicesPlaySystemSound(1519) // peek feedback
                viewMOV(viewerImageViewController: viewerImageViewController, metadata: metadata)
                
            } else {
                
                let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileNameView
                let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                                
                NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { (_) in
                    
                }, progressHandler: { (progress) in
                                    
                    self.progress(Float(progress.fractionCompleted))
                    
                }) { (account, etag, date, length, error, errorCode, errorDescription) in
                    
                    self.progress(0)
                    
                    if errorCode == 0 && account == metadata.account {
                        
                        NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                        AudioServicesPlaySystemSound(1519) // peek feedback
                        self.viewMOV(viewerImageViewController: viewerImageViewController, metadata: metadata)
                    }
                }
            }
        }
        */
    }
    
    func viewerImageViewControllerLongPressEnded(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        /*
        viewerImageViewControllerLongPressInProgress = false
        
        viewerImageViewController.statusView.isHidden = false
        appDelegate.player?.pause()
        videoLayer?.removeFromSuperlayer()
        */
    }
    
    func viewerImageViewControllerDismiss() {
        //viewUnload()
    }
    
    func statusViewImage(metadata: tableMetadata, viewerImageViewController: NCViewerImageViewController) {
        
        /*
        var colorStatus: UIColor = UIColor.white.withAlphaComponent(0.8)
        if view.backgroundColor?.isLight() ?? true { colorStatus = UIColor.black.withAlphaComponent(0.8) }
                
        if NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) != nil {
            viewerImageViewController.statusView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "livePhoto"), width: 100, height: 100, color: colorStatus)
        } else if metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio {
            viewerImageViewController.statusView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "play"), width: 100, height: 100, color: colorStatus)
        } else {
            viewerImageViewController.statusView.image = nil
        }
        */
    }
    
    func viewMOV(viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        /*
        if !viewerImageViewControllerLongPressInProgress { return }
        
        appDelegate.player = AVPlayer(url: URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!))
        videoLayer = AVPlayerLayer(player: appDelegate.player)
        if  videoLayer != nil {
            videoLayer!.frame = viewerImageViewController.view.frame
            videoLayer!.videoGravity = AVLayerVideoGravity.resizeAspect
            viewerImageViewController.view.layer.addSublayer(videoLayer!)
            appDelegate.player?.play()
        }
        */
    }
}
