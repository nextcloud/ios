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
    @objc var favoriteFilterImage: Bool = false
    @objc var mediaFilterImage: Bool = false
    @objc var offlineFilterImage: Bool = false
    
    @objc  var viewerImageViewController: NCViewerImageViewController?
    private var metadatas = [tableMetadata]()
        
    //MARK: -

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        appDelegate.activeDetail = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeDisplayMode), name: NSNotification.Name(rawValue: k_notificationCenter_splitViewChangeDisplayMode), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.downloadFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.uploadFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        
        changeTheming()
        
        if metadata != nil  {
            viewFile(metadata: metadata!, selector: selector)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigateControllerBarHidden(isNavigationBarHidden)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if appDelegate.player != nil && appDelegate.player.rate != 0 {
            appDelegate.player.pause()
        }
        
        if appDelegate.isMediaObserver {
            appDelegate.isMediaObserver = false
            NCViewerMedia.sharedInstance.removeObserver()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
        }
    }
    
    //MARK: - Utility

    func subViewActive() -> UIView? {
        return backgroundView.subviews.first
    }
    
    @objc func viewUnload() {
        
        metadata = nil
        selector = nil
        
        if let splitViewController = self.splitViewController as? NCSplitViewController {
            if splitViewController.isCollapsed {
                if let navigationController = splitViewController.viewControllers.last as? UINavigationController {
                    navigationController.popToRootViewController(animated: true)
                }
            } else {
                if backgroundView != nil {
                    for view in backgroundView.subviews {
                        view.removeFromSuperview()
                    }
                }
                self.navigationController?.navigationBar.topItem?.title = ""
            }
        }
        
        self.splitViewController?.preferredDisplayMode = .allVisible
        self.navigationController?.isNavigationBarHidden = false
        view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        
        backgroundView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "logo"), multiplier: 2, color: NCBrandColor.sharedInstance.brand.withAlphaComponent(0.4))
    }
    
    @objc func navigateControllerBarHidden(_ state: Bool) {
        if state  {
            view.backgroundColor = .black
        } else {
            view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        }
        
        navigationController?.setNavigationBarHidden(state, animated: false)
        isNavigationBarHidden = state
    }
    
    //MARK: - NotificationCenter

    @objc func changeTheming() {
        if backgroundView.image != nil {
            backgroundView.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "logo"), multiplier: 2, color: NCBrandColor.sharedInstance.brand.withAlphaComponent(0.4))
        }
        
        if navigationController?.isNavigationBarHidden == false {
            view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        }
    }
   
    @objc func changeDisplayMode() {
       
        NCViewerImageCommon.shared.imageChangeSizeView(viewerImageViewController: viewerImageViewController, size: self.backgroundView.frame.size, metadata: metadata)
    }
    
    @objc func downloadFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode == 0 && metadata.account == self.metadata?.account && metadata.serverUrl == self.metadata?.serverUrl && metadata.typeFile == k_metadataTypeFile_image && viewerImageViewController != nil {
                    
                    viewerImageViewController?.reloadContentViews()
                }
            }
        }
    }
    
    @objc func moveFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode == 0 && metadata.account == self.metadata?.account && metadata.serverUrl == self.metadata?.serverUrl {
                
                    self.deleteFile(notification)
                }
            }
        }
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode != 0 { return }
                
                // IMAGE
                if viewerImageViewController != nil && metadata.account == self.metadata?.account && metadata.serverUrl == self.metadata?.serverUrl && metadata.typeFile == k_metadataTypeFile_image {
                        
                    if let metadatas = NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, favoriteDatasorce: favoriteFilterImage, mediaDatasorce: mediaFilterImage, offLineDatasource: offlineFilterImage) {
                                
                        var index = viewerImageViewController!.index - 1
                        if index < 0 { index = 0}
                        self.metadata = metadatas[index]
                        
                        viewImage()
                                                
                    } else {
                     
                        viewUnload()
                    }
                    
                // OTHER SINGLE FILE TYPE
                } else if metadata.ocId == self.metadata?.ocId {
                    
                    viewUnload()
                }
            }
        }
    }
    
    @objc func uploadFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode != 0 { return }
                
                // IMAGE
                if viewerImageViewController != nil && metadata.account == self.metadata?.account && metadata.serverUrl == self.metadata?.serverUrl && metadata.typeFile == k_metadataTypeFile_image {
                    
                    if NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, favoriteDatasorce: favoriteFilterImage, mediaDatasorce: mediaFilterImage, offLineDatasource: offlineFilterImage) != nil {
                        viewImage()
                    } else {
                        viewUnload()
                    }
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                
                if errorCode != 0 { return }
                
                // IMAGE
                if viewerImageViewController != nil && metadata.account == self.metadata?.account && metadata.serverUrl == self.metadata?.serverUrl && metadata.typeFile == k_metadataTypeFile_image {
                    
                    if NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, favoriteDatasorce: favoriteFilterImage, mediaDatasorce: mediaFilterImage, offLineDatasource: offlineFilterImage) != nil {
                        viewImage()
                    } else {
                        viewUnload()
                    }
                    
                // OTHER SINGLE FILE TYPE
                } else if metadata.ocId == self.metadata?.ocId {
                    
                    self.navigationController?.navigationBar.topItem?.title = metadata.fileNameView
                }
            }
        }
    }
    
    //MARK: -
    
    @objc func viewFile(metadata: tableMetadata, selector: String?) {
                
        self.metadata = metadata
        self.selector = selector
        self.backgroundView.image = nil
        for view in backgroundView.subviews { view.removeFromSuperview() }

        self.navigationController?.navigationBar.topItem?.title = metadata.fileNameView
        
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)) == false {
            CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, extension: (metadata.fileNameView as NSString).pathExtension, filterGrayScale: false, typeFile: metadata.typeFile, writeImage: true)
        }
        
        if appDelegate.isMediaObserver {
            appDelegate.isMediaObserver = false
            NCViewerMedia.sharedInstance.removeObserver()
        }
        
        // IMAGE
        if metadata.typeFile == k_metadataTypeFile_image {
            
            viewImage()
            return
        }
        
        // AUDIO VIDEO
        if metadata.typeFile == k_metadataTypeFile_audio || metadata.typeFile == k_metadataTypeFile_video {
            
            let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
            NCViewerMedia.sharedInstance.viewMedia(metadata, view: backgroundView, frame: frame)
            return
        }
        
        // DOCUMENT - INTERNAL VIEWER
        if metadata.typeFile == k_metadataTypeFile_document && selector != nil && selector == selectorLoadFileInternalView {
            
            let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
            NCViewerDocumentWeb.sharedInstance.viewDocumentWebAt(metadata, view: backgroundView, frame: frame)
            return
        }
        
        // DOCUMENT
        if metadata.typeFile == k_metadataTypeFile_document {
            
            // PDF
            if metadata.contentType == "application/pdf" {
                if #available(iOS 11.0, *) {
                    
                    let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                    let viewerPDF = NCViewerPDF.init(frame: frame)
                    
                    let filePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) == false {
                        return
                    }
                    
                    viewerPDF.setupPdfView(filePath: URL(fileURLWithPath: filePath), view: backgroundView)
                }
                
                return
            }
            
            // DirectEditinf: Nextcloud Text - OnlyOffice
            if NCUtility.sharedInstance.isDirectEditing(metadata) != nil && appDelegate.reachability.isReachable() {
                
                let editor = NCUtility.sharedInstance.isDirectEditing(metadata)!
                if editor == k_editor_text || editor == k_editor_onlyoffice {
                    
                    NCUtility.sharedInstance.startActivityIndicator(view: backgroundView, bottom: 0)

                    if metadata.url == "" {
                        
                        var customUserAgent: String?
                        let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: appDelegate.activeUrl)!
                        
                        if editor == k_editor_onlyoffice {
                            customUserAgent = NCUtility.sharedInstance.getCustomUserAgentOnlyOffice()
                        }
                        
                        NCCommunication.sharedInstance.NCTextOpenFile(urlString: appDelegate.activeUrl, fileNamePath: fileNamePath, editor: editor, customUserAgent: customUserAgent, account: appDelegate.activeAccount) { (account, url, errorCode, errorMessage) in
                            
                            if errorCode == 0 && account == self.appDelegate.activeAccount && url != nil {
                                
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
                        
                        let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                        let nextcloudText = NCViewerNextcloudText.init(frame: frame, configuration: WKWebViewConfiguration())
                        nextcloudText.viewerAt(metadata.url, metadata: metadata, editor: editor, view: backgroundView, viewController: self)
                    }
                }
                
                return
            }
            
            // RichDocument: Collabora
            if NCUtility.sharedInstance.isRichDocument(metadata) && appDelegate.reachability.isReachable() {
                
                NCUtility.sharedInstance.startActivityIndicator(view: backgroundView, bottom: 0)
                
                if metadata.url == "" {
                    
                    OCNetworking.sharedManager()?.createLinkRichdocuments(withAccount: appDelegate.activeAccount, fileId: metadata.fileId, completion: { (account, url, errorMessage, errorCode) in
                        
                        if errorCode == 0 && account == self.appDelegate.activeAccount && url != nil {
                            
                            let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
                            let richDocument = NCViewerRichdocument.init(frame: frame, configuration: WKWebViewConfiguration())
                            richDocument.viewRichDocumentAt(url!, metadata: metadata, view: self.backgroundView, viewController: self)
                            
                        } else if errorCode != 0 {
                            
                            NCContentPresenter.shared.messageNotification("_error_", description: errorMessage, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            self.navigationController?.popViewController(animated: true)
                            
                        } else {
                            
                            self.navigationController?.popViewController(animated: true)
                        }
                    })
                    
                } else {
                    
                    let richDocument = NCViewerRichdocument.init(frame: backgroundView.frame, configuration: WKWebViewConfiguration())
                    richDocument.viewRichDocumentAt(metadata.url, metadata: metadata, view: backgroundView, viewController: self)
                }
            }
        }
        
        // OTHER
        let frame = CGRect(x: 0, y: 0, width: self.backgroundView.frame.width, height: self.backgroundView.frame.height)
        NCViewerDocumentWeb.sharedInstance.viewDocumentWebAt(metadata, view: backgroundView, frame: frame)
    }
}

//MARK: - viewerImageViewController - Delegate/DataSource

extension NCDetailViewController: NCViewerImageViewControllerDelegate, NCViewerImageViewControllerDataSource {
    
    func viewImage() {
        
        for view in backgroundView.subviews { view.removeFromSuperview() }
        
        if let metadatas = NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, favoriteDatasorce: favoriteFilterImage, mediaDatasorce: mediaFilterImage, offLineDatasource: offlineFilterImage) {
                            
            var counter = 0, index = 0
            for metadata in metadatas {
                if metadata.ocId == self.metadata!.ocId { index = counter }
                counter += 1
            }
            self.metadatas = metadatas
            
            viewerImageViewController = NCViewerImageViewController(index: index, dataSource: self, delegate: self)
            if viewerImageViewController != nil {
                           
                self.backgroundView.image = nil

                viewerImageViewController!.view.isHidden = true
                
                viewerImageViewController!.enableInteractiveDismissal = true
                
                addChild(viewerImageViewController!)
                backgroundView.addSubview(viewerImageViewController!.view)
                
                viewerImageViewController!.view.frame = CGRect(x: 0, y: 0, width: backgroundView.frame.width, height: backgroundView.frame.height)
                viewerImageViewController!.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                
                viewerImageViewController!.didMove(toParent: self)
                
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

    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, imageAt index: Int, completion: @escaping NCViewerImageViewControllerDataSource.CompletionBlock) {
        
        if index >= metadatas.count { return }
        let metadata = metadatas[index]
        
        // Refresh self metadata && title
        if viewerImageViewController.index < metadatas.count {
            self.metadata = metadatas[viewerImageViewController.index]
            self.navigationController?.navigationBar.topItem?.title = self.metadata!.fileNameView
        }
        
        // Original only for actual
        if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0 && index == viewerImageViewController.index {
                
            if let image = NCViewerImageCommon.shared.getImage(metadata: metadata) {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    completion(index, image, ZoomScale.default, nil)
                }
            } else {
                completion(index, self.getImageOffOutline(), ZoomScale.default, nil)
            }
                
        // Preview
        } else if CCUtility.fileProviderStorageIconExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                
            if let image = NCViewerImageCommon.shared.getThumbnailImage(metadata: metadata) {
                completion(index, image, ZoomScale.default, nil)
            } else {
                completion(index, self.getImageOffOutline(), ZoomScale.default, nil)
            }
    
        } else {
                
            let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: appDelegate.activeUrl)!
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    
            NCCommunication.sharedInstance.downloadPreview(serverUrl: appDelegate.activeUrl, fileNamePath: fileNamePath, fileNameLocalPath: fileNameLocalPath, width: NCUtility.sharedInstance.getScreenWidthForPreview(), height: NCUtility.sharedInstance.getScreenHeightForPreview(), account: metadata.account) { (account, data, errorCode, errorMessage) in
                if errorCode == 0 && data != nil {
                    do {
                        let url = URL.init(fileURLWithPath: fileNameLocalPath)
                        try data!.write(to: url, options: .atomic)
                        completion(index, UIImage.init(data: data!), ZoomScale.default, nil)
                    } catch {
                        completion(index, self.getImageOffOutline(), ZoomScale.default, nil)
                    }
                } else {
                    completion(index, self.getImageOffOutline(), ZoomScale.default, nil)
                }
            }
        }
    }
    
    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, didChangeFocusTo index: Int, view: NCViewerImageContentView) {
        
        if index >= metadatas.count { return }
        let metadata = metadatas[index]
        
        DispatchQueue.global().async {
            if let image = NCViewerImageCommon.shared.getImage(metadata: metadata) {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400)) {
                    view.image = image
                }
            }
        }
    }
    
    func viewerImageViewControllerTap(_ viewerImageViewController: NCViewerImageViewController) {
        guard let navigationController = self.navigationController else { return }
        
        if navigationController.isNavigationBarHidden {
            navigateControllerBarHidden(false)
        } else {
            navigateControllerBarHidden(true)
        }
        
        NCViewerImageCommon.shared.imageChangeSizeView(viewerImageViewController: viewerImageViewController, size: self.backgroundView.frame.size, metadata: metadata)
    }
    
    func viewerImageViewControllerDismiss() {
        viewUnload()
    }
    
    func getImageOffOutline() -> UIImage {
        
        let image = CCGraphics.changeThemingColorImage(UIImage.init(named: "imageOffOutline"), width: self.view.frame.width, height: self.view.frame.width, color: NCBrandColor.sharedInstance.brand)

        return image!
    }
    
    @objc func downloadImage() {
        
    }
}
