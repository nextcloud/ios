//
//  NCViewerImage.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/02/20.
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

class NCViewerImage: NSObject {

    private weak var metadata: tableMetadata?
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    private var viewerImageViewController: NCViewerImageViewController?
    private var metadatas = [tableMetadata]()
      
    private var favoriteFilterImage: Bool = false
    private var mediaFilterImage: Bool = false
    private var offlineFilterImage: Bool = false

    private weak var detailViewController: NCDetailViewController?
    
    private var videoLayer: AVPlayerLayer?
    private var viewerImageViewControllerLongPressInProgress = false

    init(_ metadata: tableMetadata, metadatas: [tableMetadata], detailViewController: NCDetailViewController, favoriteFilterImage: Bool, mediaFilterImage: Bool, offlineFilterImage: Bool) {
        
        self.metadata = metadata
        self.metadatas = metadatas
        self.detailViewController = detailViewController
        self.favoriteFilterImage = favoriteFilterImage
        self.mediaFilterImage = mediaFilterImage
        self.offlineFilterImage = offlineFilterImage
    }
        
    func viewImage() {
        guard let detailViewController = detailViewController else { return }
        viewerImageViewController = NCViewerImageViewController(index: 0, dataSource: self, delegate: self)
                
        for view in detailViewController.backgroundView.subviews { view.removeFromSuperview() }
        
        if let metadatas = NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, metadatas: self.metadatas, favoriteDatasorce: favoriteFilterImage, mediaDatasorce: mediaFilterImage, offLineDatasource: offlineFilterImage) {
                            
            var index = 0
            if let indexFound = metadatas.firstIndex(where: { $0.ocId == self.metadata?.ocId }) { index = indexFound }
            self.metadatas = metadatas
            
            self.viewerImageViewController = NCViewerImageViewController(index: index, dataSource: self, delegate: self)
            if viewerImageViewController != nil {
                           
                detailViewController.backgroundView.image = nil

                viewerImageViewController!.view.isHidden = true
                
                viewerImageViewController!.enableInteractiveDismissal = true
                
                detailViewController.addChild(viewerImageViewController!)
                detailViewController.backgroundView.addSubview(viewerImageViewController!.view)
                
                viewerImageViewController!.view.frame = CGRect(x: 0, y: 0, width: detailViewController.backgroundView.frame.width, height: detailViewController.backgroundView.frame.height)
                viewerImageViewController!.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                
                viewerImageViewController!.didMove(toParent: detailViewController)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    self.viewerImageViewController!.changeInViewSize(to: detailViewController.backgroundView.frame.size)
                    self.viewerImageViewController!.view.isHidden = false
                }
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.synchronizationMedia(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_synchronizationMedia), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeDisplayMode), name: NSNotification.Name(rawValue: k_notificationCenter_splitViewChangeDisplayMode), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.downloadFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_downloadFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
    }
    
    //MARK: - NotificationCenter

    @objc func changeDisplayMode() {
        guard let detailViewController = detailViewController else { return }
        NCViewerImageCommon.shared.imageChangeSizeView(viewerImageViewController: viewerImageViewController, size: detailViewController.backgroundView.frame.size, metadata: metadata)
    }
    
    @objc func synchronizationMedia(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let type = userInfo["type"] as? String {
                
                if self.mediaFilterImage {
                    
                    if let metadatas = appDelegate.activeMedia.sectionDatasource.metadatas as? [tableMetadata] {
                        self.metadatas = metadatas
                    }
                    
                    if type == "delete" {
                        if metadatas.count > 0 {
                            var index = viewerImageViewController!.index - 1
                            if index < 0 { index = 0}
                            self.metadata = metadatas[index]
                            viewImage()
                            
                        } else {
                            
                            detailViewController?.viewUnload()
                        }
                    }
                    
                    if type == "rename" || type == "move"   {
                        viewerImageViewController?.reloadContentViews()
                    }
                }
            }
        }
    }

    @objc func moveFile(_ notification: NSNotification) {
        deleteFile(notification)
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                if errorCode != 0 || metadata.account != self.metadata?.account || metadata.serverUrl != self.metadata?.serverUrl { return }
                
                if !mediaFilterImage {
                    if let metadatas = NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, metadatas: self.metadatas, favoriteDatasorce: favoriteFilterImage, mediaDatasorce: mediaFilterImage, offLineDatasource: offlineFilterImage) {
                        var index = viewerImageViewController!.index - 1
                        if index < 0 { index = 0}
                        self.metadata = metadatas[index]
                        viewImage()
                    } else {
                        detailViewController?.viewUnload()
                    }
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                if errorCode != 0 || metadata.account != self.metadata?.account || metadata.serverUrl != self.metadata?.serverUrl { return }
                
                if !mediaFilterImage {
                    
                    if NCViewerImageCommon.shared.getMetadatasDatasource(metadata: self.metadata, metadatas: self.metadatas, favoriteDatasorce: favoriteFilterImage, mediaDatasorce: mediaFilterImage, offLineDatasource: offlineFilterImage) != nil {
                        viewImage()
                    } else {
                        detailViewController?.viewUnload()
                    }
                }
            }
        }
    }
    
    @objc func downloadFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let errorCode = userInfo["errorCode"] as? Int {
                if metadata.account != self.metadata?.account || metadata.serverUrl != self.metadata?.serverUrl { return }
                                
                if  errorCode == 0  {
                    viewerImageViewController?.reloadContentViews()
                }
            }
        }
    }
}

//MARK: - viewerImageViewController - Delegate/DataSource

extension NCViewerImage: NCViewerImageViewControllerDelegate, NCViewerImageViewControllerDataSource {
    
    func numberOfItems(in viewerImageViewController: NCViewerImageViewController) -> Int {
        return metadatas.count
    }

    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, imageAt index: Int, completion: @escaping (_ index: Int, _ image: UIImage?, _ metadata: tableMetadata, _ zoomScale: ZoomScale?, _ error: Error?) -> Void) {
        
        if index >= metadatas.count { return }
        guard let detailViewController = detailViewController else { return }

        let metadata = metadatas[index]
        let isPreview = CCUtility.fileProviderStorageIconExists(metadata.ocId, fileNameView: metadata.fileNameView)
        let isImage = CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0
        
        // Refresh self metadata && title
        if viewerImageViewController.index < metadatas.count {
            self.metadata = metadatas[viewerImageViewController.index]
            detailViewController.metadata = self.metadata
            detailViewController.navigationController?.navigationBar.topItem?.title = self.metadata!.fileNameView
            
        }
        
        // Status Current
        if index == viewerImageViewController.currentItemIndex {
            statusViewImage(metadata: metadata, viewerImageViewController: viewerImageViewController)
        }
        
        // Preview for Video
        if metadata.typeFile == k_metadataTypeFile_video && !isPreview && isImage {
            
            CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, filterGrayScale: false, typeFile: metadata.typeFile, writeImage: true)
        }
        
        // Original only for actual
        if metadata.typeFile == k_metadataTypeFile_image && isImage && index == viewerImageViewController.index {
                
            if let image = NCViewerImageCommon.shared.getImage(metadata: metadata) {
                completion(index, image, metadata, ZoomScale.default, nil)
            } else {
                completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: detailViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
            }
                
        // HEIC
        } else if metadata.contentType == "image/heic" && CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) == 0 && metadata.hasPreview == false {
            
            let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
            
            _ = NCCommunication.sharedInstance.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: metadata.account, progressHandler: { (progress) in }) { (account, etag, date, length, errorCode, errorDescription) in
                                
                if errorCode == 0 && account == metadata.account {
                    
                    _ = NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                    
                    if let image = UIImage.init(contentsOfFile: fileNameLocalPath) {
                        
                        CCGraphics.createNewImage(from: metadata.fileNameView, ocId: metadata.ocId, filterGrayScale: false, typeFile: metadata.typeFile, writeImage: true)
                        
                        completion(index, image, metadata, ZoomScale.default, nil)
                    } else {
                        completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: detailViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                    }
                } else if errorCode != 0 {
                    completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: detailViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                }
            }
        
        // Preview
        } else if isPreview {
                
            if let image = NCViewerImageCommon.shared.getThumbnailImage(metadata: metadata) {
                completion(index, image, metadata, ZoomScale.default, nil)
            } else {
                completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: detailViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
            }
    
        } else if metadata.hasPreview {
                
            let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: appDelegate.activeUrl)!
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    
            NCCommunication.sharedInstance.downloadPreview(serverUrl: appDelegate.activeUrl, fileNamePath: fileNamePath, fileNameLocalPath: fileNameLocalPath, width: CGFloat(k_sizePreview), height: CGFloat(k_sizePreview), account: metadata.account) { (account, data, errorCode, errorMessage) in
                if errorCode == 0 && data != nil {
                    completion(index, UIImage.init(data: data!), metadata, ZoomScale.default, nil)
                } else {
                    completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: detailViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
                }
            }
        } else {
            completion(index, NCViewerImageCommon.shared.getImageOffOutline(frame: detailViewController.view.frame, type: metadata.typeFile), metadata, ZoomScale.default, nil)
        }
    }
    
    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, didChangeFocusTo index: Int, view: NCViewerImageContentView, metadata: tableMetadata) {
                
        if metadata.typeFile == k_metadataTypeFile_image {
            DispatchQueue.global().async {
                if let image = NCViewerImageCommon.shared.getImage(metadata: metadata) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400)) {
                        view.image = image
                    }
                }
            }
        }
        
        statusViewImage(metadata: metadata, viewerImageViewController: viewerImageViewController)
    }
    
    func viewerImageViewControllerTap(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        guard let detailViewController = detailViewController else { return }
        guard let navigationController = detailViewController.navigationController else { return }
        
        if metadata.typeFile == k_metadataTypeFile_image {
        
            if navigationController.isNavigationBarHidden {
                detailViewController.navigateControllerBarHidden(false)
                viewerImageViewController.statusView.isHidden = false
            } else {
                detailViewController.navigateControllerBarHidden(true)
                viewerImageViewController.statusView.isHidden = true
            }
            
            NCViewerImageCommon.shared.imageChangeSizeView(viewerImageViewController: viewerImageViewController, size: detailViewController.backgroundView.frame.size, metadata: metadata)
            
        } else {
            
            if let viewerImageVideo = UIStoryboard(name: "NCViewerImageVideo", bundle: nil).instantiateInitialViewController() as? NCViewerImageVideo {
                viewerImageVideo.metadata = metadata
                detailViewController.present(viewerImageVideo, animated: false) { }
            }
        }
        
        statusViewImage(metadata: metadata, viewerImageViewController: viewerImageViewController)
    }
    
    func viewerImageViewControllerLongPressBegan(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        viewerImageViewControllerLongPressInProgress = true
        
        let fileName = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
        if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", metadata.account, metadata.serverUrl, fileName)) {
            
            if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0 {
                
                viewMOV(viewerImageViewController: viewerImageViewController, metadata: metadata)
                
            } else {
                
                let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
                let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
                                
                _ = NCCommunication.sharedInstance.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: metadata.account, progressHandler: { (progress) in
                                                        
                }) { (account, etag, date, length, errorCode, errorDescription) in
                                        
                    if errorCode == 0 && account == metadata.account {
                        
                        _ = NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                        self.viewMOV(viewerImageViewController: viewerImageViewController, metadata: metadata)
                    }
                }
            }
        }
    }
    
    func viewerImageViewControllerLongPressEnded(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata) {
        
        viewerImageViewControllerLongPressInProgress = false
        
        appDelegate.player?.pause()
        videoLayer?.removeFromSuperlayer()
    }
    
    func viewerImageViewControllerDismiss() {
        detailViewController?.viewUnload()
    }
    
    @objc func downloadImage() {
        
        guard let metadata = self.metadata else {return }
        
        metadata.session = k_download_session
        metadata.sessionError = ""
        metadata.sessionSelector = ""
        metadata.status = Int(k_metadataStatusWaitDownload)
        
        self.metadata = NCManageDatabase.sharedInstance.addMetadata(metadata)
        
        if let index = metadatas.firstIndex(where: { $0.ocId == metadata.ocId }) {
            metadatas[index] = self.metadata!
        }
        
        appDelegate.startLoadAutoDownloadUpload()
    }
    
    func saveLivePhoto(metadata: tableMetadata, metadataMov: tableMetadata) {
        
        let fileNameImage = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!)
        let fileNameMov = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadataMov.ocId, fileNameView: metadataMov.fileNameView)!)
        
        NCLivePhoto.generate(from: fileNameImage, videoURL: fileNameMov, progress: { progress in
            self.detailViewController?.progress(Float(progress))
        }, completion: { livePhoto, resources in
            self.detailViewController?.progress(0)
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
    
    func statusViewImage(metadata: tableMetadata, viewerImageViewController: NCViewerImageViewController) {
        
        var colorStatus: UIColor = UIColor.white.withAlphaComponent(0.8)
        if detailViewController?.view.backgroundColor?.isLight() ?? true { colorStatus = UIColor.black.withAlphaComponent(0.8) }
        
        if NCUtility.sharedInstance.hasMOV(metadata: metadata) != nil {
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
