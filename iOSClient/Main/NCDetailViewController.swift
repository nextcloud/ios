//
//  NCDetailViewController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/2020.
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
import WebKit
import NCCommunication

class NCDetailViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIImageView!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
   
    @objc var isNavigationBarHidden = false
    @objc var metadata: tableMetadata?
    @objc var selector: String?
    @objc var mediaFilterImage: Bool = false
    
    @objc var viewerImageViewController: NCViewerImageViewController?
    @objc var metadatas: [tableMetadata] = []
    
    private var maxProgress: Float = 0
    private var videoLayer: AVPlayerLayer?
    private var viewerImageViewControllerLongPressInProgress = false
    
    private var viewerQuickLook: NCViewerQuickLook?

    //MARK: -

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        appDelegate.activeDetail = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeDisplayMode), name: NSNotification.Name(rawValue: k_notificationCenter_splitViewChangeDisplayMode), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_progressTask), object:nil)
               
        NotificationCenter.default.addObserver(self, selector: #selector(downloadImage(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_menuDownloadImage), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveLivePhoto(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_menuSaveLivePhoto), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: k_notificationCenter_menuDetailClose), object: nil)
        
        changeTheming()

        if metadata != nil  {
            viewFile(metadata: metadata!, selector: selector)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setProgressBar()
        navigateControllerBarHidden(isNavigationBarHidden)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if appDelegate.player != nil && appDelegate.player.rate != 0 {
            appDelegate.player.pause()
        }
        
        if appDelegate.isMediaObserver {
            appDelegate.isMediaObserver = false
            NCViewerVideo.sharedInstance.removeObserver()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.setProgressBar()
        }
    }
    
    //MARK: - ProgressBar

    @objc func setProgressBar() {
        
        appDelegate.progressViewDetail.removeFromSuperview()

        guard let navigationController = splitViewController?.viewControllers.last as? UINavigationController else { return }
                        
        appDelegate.progressViewDetail.frame = CGRect(x: 0, y: navigationController.navigationBar.frame.height - 2, width: navigationController.navigationBar.frame.width, height: 2)
        progress(0)
        appDelegate.progressViewDetail.tintColor = NCBrandColor.sharedInstance.brandElement
        appDelegate.progressViewDetail.trackTintColor = .clear
        appDelegate.progressViewDetail.transform = CGAffineTransform(scaleX: 1, y: 1)
        
        navigationController.navigationBar.addSubview(appDelegate.progressViewDetail)
    }
    
    @objc func progress(_ progress: Float) {
        DispatchQueue.main.async {
            if progress == 0 {
                self.maxProgress = 0
                self.appDelegate.progressViewDetail.progress = 0
            } else if progress > self.maxProgress {
                self.appDelegate.progressViewDetail.progress = progress
                self.maxProgress = progress
            }
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if isNavigationBarHidden {
            return .lightContent
        } else {
            return .default
        }
    }
    
    //MARK: - Utility

    @objc func navigateControllerBarHidden(_ state: Bool) {
        
        if state  {
            view.backgroundColor = .black
        } else {
            view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        }
        
        navigationController?.setNavigationBarHidden(state, animated: false)
        isNavigationBarHidden = state
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    //MARK: - NotificationCenter

    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: nil, collectionView: nil, form: false)
        
        if backgroundView.image != nil {
            backgroundView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "logo"), multiplier: 2, color: NCBrandColor.sharedInstance.brandElement.withAlphaComponent(0.4))
        }
        
        if navigationController?.isNavigationBarHidden == false {
            view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        }
    }
   
    @objc func changeDisplayMode() {
       if self.view?.window == nil { return }
        
        NCViewerImageCommon.shared.imageChangeSizeView(viewerImageViewController: viewerImageViewController, size: self.backgroundView.frame.size, metadata: metadata)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            self.setProgressBar()
        }
    }
    
    @objc func triggerProgressTask(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        guard let metadata = self.metadata else { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let account = userInfo["account"] as? String, let serverUrl = userInfo["serverUrl"] as? String {
                if account == metadata.account && serverUrl == metadata.serverUrl {
                    let progressNumber = userInfo["progress"] as? NSNumber ?? 0
                    let progress = progressNumber.floatValue
                    self.progress(progress)
                }
            }
        }
    }
    
    @objc func moveFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataNew = userInfo["metadataNew"] as? tableMetadata {
                if metadata.account != self.metadata?.account { return }
                
                // IMAGE
                if (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    
                    viewImage()
                }
                
                // OTHER
                if (metadata.typeFile == k_metadataTypeFile_document || metadata.typeFile == k_metadataTypeFile_unknown) && metadataNew.ocId == self.metadata?.ocId {
                    
                    self.metadata = metadataNew
                    
                    // update subview
                    for view in backgroundView.subviews {
                        if view is NCViewerNextcloudText {
                            (view as! NCViewerNextcloudText).metadata = self.metadata
                        }
                        else if view is NCViewerRichdocument {
                            (view as! NCViewerRichdocument).metadata = self.metadata
                        }
                    }
                }
            }
        }
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.account != self.metadata?.account || metadata.serverUrl != self.metadata?.serverUrl { return }
                                    
                // IMAGE
                if (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                
                    let metadatas = self.metadatas.filter { $0.ocId != metadata.ocId }
                    if metadatas.count > 0 {
                        if self.metadata?.ocId == metadata.ocId {
                            var index = viewerImageViewController!.index - 1
                            if index < 0 { index = 0}
                            self.metadata = metadatas[index]
                        }
                        viewImage()
                    } else {
                        viewUnload()
                    }
                }
                
                // OTHER
                if (metadata.typeFile == k_metadataTypeFile_document || metadata.typeFile == k_metadataTypeFile_unknown) && metadata.ocId == self.metadata?.ocId {
                    viewUnload()
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.account != self.metadata?.account || metadata.serverUrl != self.metadata?.serverUrl { return }
                
                // IMAGE
                if (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) {
                    
                    viewImage()
                }
                
                // OTHER
                if (metadata.typeFile == k_metadataTypeFile_document || metadata.typeFile == k_metadataTypeFile_unknown) && metadata.ocId == self.metadata?.ocId {
                    
                    if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(metadata.ocId) {
                        self.metadata = metadata
                        self.navigationController?.navigationBar.topItem?.title = metadata.fileNameView
                    } else {
                        viewUnload()
                    }
                }
            }
        }
    }
    
    @objc func downloadedFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                if metadata.account != self.metadata?.account || metadata.serverUrl != self.metadata?.serverUrl { return }
                
                // IMAGE
                if metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio && errorCode != 0  {

                    viewerImageViewController?.reloadContentViews()
                }
                
                progress(0)
            }
        }
    }
    
    @objc func uploadedFile(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let _ = userInfo["errorCode"] as? Int {
                if metadata.serverUrl != self.metadata?.serverUrl { return }
                    progress(0)
            }
        }
    }
    
    @objc func downloadImage(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {

                NCNetworking.shared.download(metadata: metadata, selector: "") { (_) in }

                if let index = metadatas.firstIndex(where: { $0.ocId == metadata.ocId }) {
                    metadatas[index] = self.metadata!
                }                
            }
        }
    }
    
    @objc func saveLivePhoto(_ notification: NSNotification) {
        if self.view?.window == nil { return }
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataMov = userInfo["metadataMov"] as? tableMetadata {
                let fileNameImage = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
                let fileNameMov = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadataMov.ocId, fileNameView: metadataMov.fileNameView)!)
                
                NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
                    self.progress(Float(progress))
                }, completion: { livePhoto, resources in
                    self.progress(0)
                    if resources != nil {
                        NCLivePhoto.saveToLibrary(resources!) { (result) in
                            if !result {
                                NCContentPresenter.shared.messageNotification("_error_", description: "_livephoto_save_error_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                            }
                        }
                    } else {
                        NCContentPresenter.shared.messageNotification("_error_", description: "_livephoto_save_error_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                    }
                })
            }
        }
    }
    
    @objc func viewUnload() {
        self.unload(checkWindow: true)
    }
    
    private func unload(checkWindow: Bool) {
        if checkWindow && self.view?.window == nil { return }

        metadata = nil
        selector = nil
        
        if let splitViewController = self.splitViewController as? NCSplitViewController {
            if splitViewController.isCollapsed {
                if let navigationController = splitViewController.viewControllers.last as? UINavigationController {
                    navigationController.popViewController(animated: true)
                }
            } else {
                closeAllSubView()
                self.navigationController?.navigationBar.topItem?.title = ""
            }
        }
        
        self.splitViewController?.preferredDisplayMode = .allVisible
        self.navigationController?.isNavigationBarHidden = false
        view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        
        backgroundView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "logo"), multiplier: 2, color: NCBrandColor.sharedInstance.brandElement.withAlphaComponent(0.4))
    }
    
    private func closeAllSubView() {
        
        if backgroundView != nil {
            for view in backgroundView.subviews {
                view.removeFromSuperview()
            }
        }
        viewerImageViewController?.willMove(toParent: nil)
        viewerImageViewController?.view.removeFromSuperview()
        viewerImageViewController?.removeFromParent()
    }
    
    //MARK: - View File
    
    @objc func viewFile(metadata: tableMetadata, selector: String?) {
                
        self.metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(metadata.ocId)
        self.selector = selector
        self.backgroundView.image = nil
        
        closeAllSubView()

        if appDelegate.isMediaObserver {
            appDelegate.isMediaObserver = false
            NCViewerVideo.sharedInstance.removeObserver()
        }
        
        // IMAGE VIDEO AUDIO
        if metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_audio || metadata.typeFile == k_metadataTypeFile_video {
            
            viewImage()
            
            return
        }
    
        // DOCUMENT
        if metadata.typeFile == k_metadataTypeFile_document {
            
            // PDF
            if metadata.contentType == "application/pdf" {
                    
                let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                let viewerPDF = NCViewerPDF.init(frame: frame)
                    
                let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) == false {
                    
                    return
                }
                    
                viewerPDF.setupPdfView(filePath: URL(fileURLWithPath: filePath), view: backgroundView)

                return
            }
            
            // DirectEditinf: Nextcloud Text - OnlyOffice
            if NCUtility.shared.isDirectEditing(account: metadata.account, contentType: metadata.contentType) != nil &&  NCCommunication.shared.isNetworkReachable() {
                
                guard let editor = NCUtility.shared.isDirectEditing(account: metadata.account, contentType: metadata.contentType) else { return }
                if editor == k_editor_text || editor == k_editor_onlyoffice {
                    
                    NCUtility.shared.startActivityIndicator(view: backgroundView)

                    if metadata.url == "" {
                        
                        var customUserAgent: String?
                        let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!
                        
                        if editor == k_editor_onlyoffice {
                            customUserAgent = NCUtility.shared.getCustomUserAgentOnlyOffice()
                            self.navigationController?.navigationBar.topItem?.title = ""
                        }
                        
                        NCCommunication.shared.NCTextOpenFile(fileNamePath: fileNamePath, editor: editor, customUserAgent: customUserAgent) { (account, url, errorCode, errorMessage) in
                            
                            if errorCode == 0 && account == self.appDelegate.account && url != nil {
                                
                                let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                                let nextcloudText = NCViewerNextcloudText.init(frame: frame, configuration: WKWebViewConfiguration())
                                nextcloudText.viewerAt(url!, metadata: metadata, editor: editor, view: self.backgroundView, viewController: self)
                                
                            } else if errorCode != 0 {
                                
                                NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                self.navigationController?.popViewController(animated: true)
                                
                            } else {
                                
                                self.navigationController?.popViewController(animated: true)
                            }
                        }
                        
                    } else {
                        
                        if editor == k_editor_onlyoffice {
                            self.navigationController?.navigationBar.topItem?.title = ""
                        } 
                            
                        let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                        let nextcloudText = NCViewerNextcloudText.init(frame: frame, configuration: WKWebViewConfiguration())
                        nextcloudText.viewerAt(metadata.url, metadata: metadata, editor: editor, view: backgroundView, viewController: self)
                    }
                } else {
                    NCContentPresenter.shared.messageNotification("_error_", description: "_editor_unknown_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                    unload(checkWindow: false)
                }
                
                return
            }
            
            // RichDocument: Collabora
            if NCUtility.shared.isRichDocument(metadata) &&  NCCommunication.shared.isNetworkReachable() {
                
                NCUtility.shared.startActivityIndicator(view: backgroundView)
                
                if metadata.url == "" {
                    
                    NCCommunication.shared.createUrlRichdocuments(fileID: metadata.fileId) { (account, url, errorCode, errorDescription) in
                        
                        if errorCode == 0 && account == self.appDelegate.account && url != nil {
                            
                            let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                            let richDocument = NCViewerRichdocument.init(frame: frame, configuration: WKWebViewConfiguration())
                            richDocument.viewRichDocumentAt(url!, metadata: metadata, view: self.backgroundView, viewController: self)
                            
                        } else if errorCode != 0 {
                            
                            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            self.navigationController?.popViewController(animated: true)
                            
                        } else {
                            
                            self.navigationController?.popViewController(animated: true)
                        }
                    }
                    
                } else {
                    
                    let richDocument = NCViewerRichdocument.init(frame: backgroundView.frame, configuration: WKWebViewConfiguration())
                    richDocument.viewRichDocumentAt(metadata.url, metadata: metadata, view: backgroundView, viewController: self)
                }
                
                return
            }
        }
        
        // OTHER
        
        let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView

        CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: fileNamePath)

        viewerQuickLook = NCViewerQuickLook.init()
        viewerQuickLook?.quickLook(url: URL(fileURLWithPath: fileNamePath), viewController: self)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.unload(checkWindow: false)
        }
    }
}

//MARK: - viewerImageViewController - Delegate/DataSource

extension NCDetailViewController: NCViewerImageViewControllerDelegate, NCViewerImageViewControllerDataSource {
    
    func viewImage() {
        
        closeAllSubView()
        
        NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, mediaDatasorce: mediaFilterImage) { (metadatas) in
            
            guard let metadatas = metadatas else {
                self.viewUnload()
                return
            }
            var index = 0
            
            if let indexFound = metadatas.firstIndex(where: { $0.ocId == self.metadata?.ocId }) { index = indexFound }
            // Video -> is a Live Photo ?
            if self.metadata?.typeFile == k_metadataTypeFile_video {
                let filename = (self.metadata!.fileNameView as NSString).deletingPathExtension.lowercased()
                if let indexFound = metadatas.firstIndex(where: { (($0.fileNameView as NSString).deletingPathExtension.lowercased() as String) == filename && $0.typeFile == k_metadataTypeFile_image }) { index = indexFound }
            }
            self.metadatas = metadatas

            self.viewerImageViewController = NCViewerImageViewController(index: index, dataSource: self, delegate: self)
            if self.viewerImageViewController != nil {
                           
                self.backgroundView.image = nil
                self.viewerImageViewController!.view.isHidden = true
                self.viewerImageViewController!.enableInteractiveDismissal = true
                self.addChild(self.viewerImageViewController!)
                self.view.addSubview(self.viewerImageViewController!.view)
                self.viewerImageViewController!.view.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
                self.viewerImageViewController!.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                self.viewerImageViewController!.didMove(toParent: self)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    self.viewerImageViewController!.changeInViewSize(to: self.backgroundView.frame.size)
                    self.viewerImageViewController!.view.isHidden = false
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
            self.navigationController?.navigationBar.topItem?.title = self.metadata!.fileNameView
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
                completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
            }
                
        // Automatic download for: Encripted
        } else if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) == 0 && isFolderEncrypted{
            
            if NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@ AND session != ''", metadata.ocId)) == nil {
                
                NCNetworking.shared.download(metadata: metadata, selector: "") { (_) in }
            }
            
            completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
            
        // Automatic download for: HEIC - GIF - SVG
        } else if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) == 0 && ((metadata.contentType == "image/heic" &&  metadata.hasPreview == false) || ext == "GIF" || ext == "SVG") {
            
            let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
                        
            NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { (_) in
                                
            },  progressHandler: { (progress) in
                                
                self.progress(Float(progress.fractionCompleted))
                
            }) { (account, etag, date, length, error, errorCode, errorDescription) in
                
                if errorCode == 0 && account == metadata.account {
                    
                    NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                    
                    if let image = NCViewerImageCommon.shared.getImage(metadata: metadata) {
                        completion(index, image, metadata, ZoomScale.default, nil)
                    } else {
                        completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                    }
                } else if errorCode != 0 {
                    completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                }
                
                self.progress(0)
            }
        
        // Preview
        } else if isPreview {
                
            if let image = NCViewerImageCommon.shared.getThumbnailImage(metadata: metadata) {
                completion(index, image, metadata, ZoomScale.default, nil)
            } else {
                completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
            }
    
        } else if metadata.hasPreview {
                
            let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!
            let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
            let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!
                    
            NCCommunication.shared.downloadPreview(fileNamePathOrFileId: fileNamePath, fileNamePreviewLocalPath: fileNamePreviewLocalPath, widthPreview: Int(k_sizePreview), heightPreview: Int(k_sizePreview), fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: Int(k_sizeIcon)) { (account, imagePreview, imageIcon,  errorCode, errorMessage) in
                if errorCode == 0 && imagePreview != nil {
                    completion(index, imagePreview, metadata, ZoomScale.default, nil)
                } else {
                    completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                }
            }
            
        } else {
            completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: self.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
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
        
        guard let navigationController = self.navigationController else { return }
        
        if metadata.typeFile == k_metadataTypeFile_image {
        
            if navigationController.isNavigationBarHidden {
                navigateControllerBarHidden(false)
                viewerImageViewController.statusView.isHidden = false
            } else {
                navigateControllerBarHidden(true)
                viewerImageViewController.statusView.isHidden = true
            }
            
            NCViewerImageCommon.shared.imageChangeSizeView(viewerImageViewController: viewerImageViewController, size: self.backgroundView.frame.size, metadata: metadata)
            
        } else {
            
            if let viewerImageVideo = UIStoryboard(name: "NCViewerImageVideo", bundle: nil).instantiateInitialViewController() as? NCViewerImageVideo {
                viewerImageVideo.metadata = metadata
                present(viewerImageVideo, animated: false) { }
            }
        }
        
        statusViewImage(metadata: metadata, viewerImageViewController: viewerImageViewController)
    }
    
    func viewerImageViewControllerLongPressBegan(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
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
    }
    
    func viewerImageViewControllerLongPressEnded(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        viewerImageViewControllerLongPressInProgress = false
        
        viewerImageViewController.statusView.isHidden = false
        appDelegate.player?.pause()
        videoLayer?.removeFromSuperlayer()
    }
    
    func viewerImageViewControllerDismiss() {
        viewUnload()
    }
    
    func statusViewImage(metadata: tableMetadata, viewerImageViewController: NCViewerImageViewController) {
        
        var colorStatus: UIColor = UIColor.white.withAlphaComponent(0.8)
        if view.backgroundColor?.isLight() ?? true { colorStatus = UIColor.black.withAlphaComponent(0.8) }
                
        if NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) != nil {
            viewerImageViewController.statusView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "livePhoto"), width: 100, height: 100, color: colorStatus)
        } else if metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio {
            viewerImageViewController.statusView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "play"), width: 100, height: 100, color: colorStatus)
        } else {
            viewerImageViewController.statusView.image = nil
        }
    }
    
    func viewMOV(viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        if !viewerImageViewControllerLongPressInProgress { return }
        
        appDelegate.player = AVPlayer(url: URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!))
        videoLayer = AVPlayerLayer(player: appDelegate.player)
        if  videoLayer != nil {
            videoLayer!.frame = viewerImageViewController.view.frame
            videoLayer!.videoGravity = AVLayerVideoGravity.resizeAspect
            viewerImageViewController.view.layer.addSublayer(videoLayer!)
            appDelegate.player?.play()
        }
    }
}

//MARK: -

extension NCDetailViewController: NCSelectDelegate {
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, array: [Any], buttonType: String, overwrite: Bool) {
        if let metadata = self.metadata, let serverUrl = serverUrl {
            if buttonType == "done" {
                NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite) { (errorCode, errorDescription) in
                    if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                }
            } else {
                NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrl, overwrite: overwrite) { (errorCode, errorDescription) in
                    if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                }
            }
        }
    }
}

