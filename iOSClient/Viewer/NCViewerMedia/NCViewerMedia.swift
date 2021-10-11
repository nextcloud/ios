//
//  NCViewerMedia.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/10/2020.
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

import UIKit
import SVGKit
import NCCommunication

class NCViewerMedia: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!
    
    enum ScreenMode {
        case full, normal
    }
    var currentScreenMode: ScreenMode = .normal
    var saveScreenModeImage: ScreenMode = .normal

    var pageViewController: UIPageViewController {
        return self.children[0] as! UIPageViewController
    }
    
    var currentViewController: NCViewerMediaZoom {
        return self.pageViewController.viewControllers![0] as! NCViewerMediaZoom
    }
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    var metadatas: [tableMetadata] = []
    var currentIndex = 0
    var nextIndex: Int?
    var ncplayerLivePhoto: NCPlayer?
    var panGestureRecognizer: UIPanGestureRecognizer!
    var singleTapGestureRecognizer: UITapGestureRecognizer!
    var longtapGestureRecognizer: UILongPressGestureRecognizer!
    
    var textColor: UIColor = NCBrandColor.shared.label

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(image: UIImage(named: "more")!.image(color: NCBrandColor.shared.label, size: 25), style: .plain, target: self, action: #selector(self.openMenuMore))
        
        singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPanWith(gestureRecognizer:)))
        longtapGestureRecognizer = UILongPressGestureRecognizer()
        longtapGestureRecognizer.delaysTouchesBegan = true
        longtapGestureRecognizer.minimumPressDuration = 0.3
        longtapGestureRecognizer.delegate = self
        longtapGestureRecognizer.addTarget(self, action: #selector(didLongpressGestureEvent(gestureRecognizer:)))
        
        pageViewController.delegate = self
        pageViewController.dataSource = self
        pageViewController.view.addGestureRecognizer(panGestureRecognizer)
        pageViewController.view.addGestureRecognizer(singleTapGestureRecognizer)
        pageViewController.view.addGestureRecognizer(longtapGestureRecognizer)
        
        let viewerMediaZoom = UIStoryboard(name: "NCViewerMedia", bundle: nil).instantiateViewController(withIdentifier: "NCViewerMediaZoom") as! NCViewerMediaZoom
                
        viewerMediaZoom.index = currentIndex
        viewerMediaZoom.image = getImageMetadata(metadatas[currentIndex])
        viewerMediaZoom.metadata = metadatas[currentIndex]
        viewerMediaZoom.viewerMedia = self
        viewerMediaZoom.isShowDetail = false

        singleTapGestureRecognizer.require(toFail: viewerMediaZoom.doubleTapGestureRecognizer)
        
        pageViewController.setViewControllers([viewerMediaZoom], direction: .forward, animated: true, completion: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuDetailClose), object: nil)
        
        progressView.tintColor = NCBrandColor.shared.brandElement
        progressView.trackTintColor = .clear
        progressView.progress = 0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object:nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedThumbnail(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedThumbnail), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(hidePlayerToolBar(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterHidePlayerToolBar), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let player = appDelegate.player {
            if player.rate == 1 {
                player.pause()
                currentViewController.ncplayer?.saveTime(player.currentTime())
            }
        }
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedThumbnail), object: nil)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        
        if currentScreenMode == .normal {
            return .default
        } else {
            return .lightContent
        }
    }

    @objc func viewUnload() {
        
        navigationController?.popViewController(animated: true)
    }
    
    @objc func openMenuMore() {
        
        let imageIcon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(currentViewController.metadata.ocId, etag: currentViewController.metadata.etag))
        NCViewer.shared.toggleMenu(viewController: self, metadata: currentViewController.metadata, webView: false, imageIcon: imageIcon)
    }
    
    deinit {
        print("deinit NCViewerMedia")        
    }
    
    func changeScreenMode(mode: ScreenMode) {
        
        if mode == .normal {
            
            navigationController?.setNavigationBarHidden(false, animated: true)
            progressView.isHidden = false

            currentViewController.playerToolBar.show(metadata: currentViewController.metadata, detailView: currentViewController.detailView, enableTimerAutoHide: true)
            
            NCUtility.shared.colorNavigationController(navigationController, backgroundColor: NCBrandColor.shared.systemBackground, titleColor: NCBrandColor.shared.label, tintColor: nil, withoutShadow: false)
            view.backgroundColor = NCBrandColor.shared.systemBackground
            textColor = NCBrandColor.shared.label
            
        } else {
            
            navigationController?.setNavigationBarHidden(true, animated: true)
            progressView.isHidden = true
            
            currentViewController.playerToolBar.hide()

            view.backgroundColor = .black
            textColor = .white
        }
        
        currentScreenMode = mode
        
        if currentViewController.metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue {
            saveScreenModeImage = mode
        }
        
        setNeedsStatusBarAppearanceUpdate()
        currentViewController.reloadDetail()
    }
    
    //MARK: - NotificationCenter

    @objc func downloadedFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary?, let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId), let errorCode = userInfo["errorCode"] as? Int {
          
            if errorCode == 0 && currentViewController.metadata.ocId == ocId, let image = getImageMetadata(metadata) {
                currentViewController.reload(image: image, metadata: metadata)
                if self.metadatas.first(where: { $0.ocId == metadata.ocId }) != nil {
                    progressView.progress = 0
                }
            }
        }
    }
    
    @objc func downloadedThumbnail(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary?, let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
            
            if currentViewController.metadata.ocId == ocId, let image = getImageMetadata(metadata) {
                currentViewController.reload(image: image, metadata: metadata)
            }
        }
    }
    
    @objc func uploadedFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId), let errorCode = userInfo["errorCode"] as? Int {
                if errorCode == 0  && metadata.ocId == currentViewController.metadata.ocId {
                    //self.reloadCurrentPage()
                }
            }
        }
    }
    
    @objc func triggerProgressTask(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let serverUrl = userInfo["serverUrl"] as? String, let fileName = userInfo["fileName"] as? String, let progressNumber = userInfo["progress"] as? NSNumber {
                if self.metadatas.first(where: { $0.serverUrl == serverUrl && $0.fileName == fileName}) != nil {
                    let progress = progressNumber.floatValue
                    if progress == 1 {
                        self.progressView.progress = 0
                    } else {
                        self.progressView.progress = progress
                    }
                }
            }
        }
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String {
                
                let metadatas = self.metadatas.filter { $0.ocId != ocId }
                if self.metadatas.count == metadatas.count { return }
                self.metadatas = metadatas
                
                if ocId == currentViewController.metadata.ocId {
                    if !shiftCurrentPage() {
                        self.viewUnload()
                    }
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                
                if let index = metadatas.firstIndex(where: {$0.ocId == metadata.ocId}) {
                    metadatas[index] = metadata
                    if index == currentIndex {
                        navigationItem.title = metadata.fileNameView
                        currentViewController.metadata = metadata
                        self.currentViewController.metadata = metadata
                    }
                }
            }
        }
    }
    
    @objc func moveFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                
                if metadatas.firstIndex(where: {$0.ocId == metadata.ocId}) != nil {
                    deleteFile(notification)
                }
            }
        }
    }
    
    @objc func changeTheming() {
    }
    
    @objc func hidePlayerToolBar(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary?, let ocId = userInfo["ocId"] as? String {
            if currentViewController.metadata.ocId == ocId {
                changeScreenMode(mode: .full)
            }
        }
    }
    
    //MARK: - Image
    
    func getImageMetadata(_ metadata: tableMetadata) -> UIImage? {
                
        if let image = getImage(metadata: metadata) {
            return image
        }
        
        if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue && !metadata.hasPreview {
            NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
        }
        
        if CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
            if let imagePreviewPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag) {
                return UIImage.init(contentsOfFile: imagePreviewPath)
            } 
        }
        
        return nil
    }
    
    private func getImage(metadata: tableMetadata) -> UIImage? {
        
        let ext = CCUtility.getExtension(metadata.fileNameView)
        var image: UIImage?
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue {
           
            let previewPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
            let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            
            if ext == "GIF" {
                if !FileManager().fileExists(atPath: previewPath) {
                    NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                }
                image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: imagePath))
            } else if ext == "SVG" {
                if let svgImage = SVGKImage(contentsOfFile: imagePath) {
                    svgImage.size = CGSize(width: NCGlobal.shared.sizePreview, height: NCGlobal.shared.sizePreview)
                    if let image = svgImage.uiImage {
                        if !FileManager().fileExists(atPath: previewPath) {
                            do {
                                try image.pngData()?.write(to: URL(fileURLWithPath: previewPath), options: .atomic)
                            } catch { }
                        }
                        return image
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            } else {
                NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                image = UIImage.init(contentsOfFile: imagePath)
            }
        }
        
        return image
    }
}

//MARK: - UIPageViewController Delegate Datasource

extension NCViewerMedia: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    func shiftCurrentPage() -> Bool {
        if metadatas.count == 0 { return false }
        
        var direction: UIPageViewController.NavigationDirection = .forward
        if currentIndex == metadatas.count {
            currentIndex -= 1
            direction = .reverse
        }
        
        let viewerMediaZoom = UIStoryboard(name: "NCViewerMedia", bundle: nil).instantiateViewController(withIdentifier: "NCViewerMediaZoom") as! NCViewerMediaZoom
        
        viewerMediaZoom.index = currentIndex
        viewerMediaZoom.image = getImageMetadata(metadatas[currentIndex])
        viewerMediaZoom.metadata = metadatas[currentIndex]
        viewerMediaZoom.viewerMedia = self
        viewerMediaZoom.isShowDetail = false

        singleTapGestureRecognizer.require(toFail: viewerMediaZoom.doubleTapGestureRecognizer)
        
        pageViewController.setViewControllers([viewerMediaZoom], direction: direction, animated: true, completion: nil)
        
        return true
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if currentIndex == 0 { return nil }
        
        let viewerMediaZoom = UIStoryboard(name: "NCViewerMedia", bundle: nil).instantiateViewController(withIdentifier: "NCViewerMediaZoom") as! NCViewerMediaZoom
                
        viewerMediaZoom.index = currentIndex - 1
        viewerMediaZoom.image = getImageMetadata(metadatas[currentIndex - 1])
        viewerMediaZoom.metadata = metadatas[currentIndex - 1]
        viewerMediaZoom.viewerMedia = self
        viewerMediaZoom.isShowDetail = false

        self.singleTapGestureRecognizer.require(toFail: viewerMediaZoom.doubleTapGestureRecognizer)
        
        return viewerMediaZoom
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if currentIndex == metadatas.count - 1 { return nil }
                
        let viewerMediaZoom = UIStoryboard(name: "NCViewerMedia", bundle: nil).instantiateViewController(withIdentifier: "NCViewerMediaZoom") as! NCViewerMediaZoom
        
        viewerMediaZoom.index = currentIndex + 1
        viewerMediaZoom.image = getImageMetadata(metadatas[currentIndex + 1])
        viewerMediaZoom.metadata = metadatas[currentIndex + 1]
        viewerMediaZoom.viewerMedia = self
        viewerMediaZoom.isShowDetail = false

        singleTapGestureRecognizer.require(toFail: viewerMediaZoom.doubleTapGestureRecognizer)

        return viewerMediaZoom
    }
    
    // START TRANSITION
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        
        // Save time video
        if let player = appDelegate.player {
            if player.rate == 1 {
                currentViewController.ncplayer?.saveTime(player.currentTime())
            }
        }
        
        guard let nextViewController = pendingViewControllers.first as? NCViewerMediaZoom else { return }
        nextIndex = nextViewController.index        
    }
    
    // END TRANSITION
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        
        if (completed && nextIndex != nil) {
            previousViewControllers.forEach { viewController in
                let viewerMediaZoom = viewController as! NCViewerMediaZoom
                viewerMediaZoom.scrollView.zoomScale = viewerMediaZoom.scrollView.minimumZoomScale
            }
            currentIndex = nextIndex!
        }
        
        self.nextIndex = nil
    }
}

//MARK: - UIGestureRecognizerDelegate

extension NCViewerMedia: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = gestureRecognizer.velocity(in: self.view)
            
            var velocityCheck : Bool = false
            
            if UIDevice.current.orientation.isLandscape {
                velocityCheck = velocity.x < 0
            }
            else {
                velocityCheck = velocity.y < 0
            }
            if velocityCheck {
                return false
            }
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if otherGestureRecognizer == currentViewController.scrollView.panGestureRecognizer {
            if self.currentViewController.scrollView.contentOffset.y == 0 {
                return true
            }
        }
        
        return false
    }

    @objc func didPanWith(gestureRecognizer: UIPanGestureRecognizer) {
        
        currentViewController.didPanWith(gestureRecognizer: gestureRecognizer)
    }
    
    @objc func didSingleTapWith(gestureRecognizer: UITapGestureRecognizer) {
                
        if currentScreenMode == .full {
            
            changeScreenMode(mode: .normal)
                        
        } else {
            
            changeScreenMode(mode: .full)
        }
    }
    
    //
    // LIVE PHOTO
    //
    @objc func didLongpressGestureEvent(gestureRecognizer: UITapGestureRecognizer) {
        
        if !currentViewController.metadata.livePhoto { return }
        
        if gestureRecognizer.state == .began {
            
            currentViewController.updateViewConstraints()
            currentViewController.statusViewImage.isHidden = true
            currentViewController.statusLabel.isHidden = true
            
            let fileName = (currentViewController.metadata.fileNameView as NSString).deletingPathExtension + ".mov"
            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", currentViewController.metadata.account, currentViewController.metadata.serverUrl, fileName)) {
                
                if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    
                    AudioServicesPlaySystemSound(1519) // peek feedback
                    
                    if let url = NCKTVHTTPCache.shared.getVideoURL(metadata: metadata) {
                        self.ncplayerLivePhoto = NCPlayer.init(url: url, imageVideoContainer: self.currentViewController.imageVideoContainer, playerToolBar: nil, metadata: metadata, detailView: nil)
                        self.ncplayerLivePhoto?.playerPlay()
                    }
                    
                } else {
                    
                    let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileNameView
                    let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                                    
                    NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { (_) in
                        
                    }, taskHandler: { (_) in
                        
                    }, progressHandler: { (progress) in
                                        
                        self.progressView.progress = Float(progress.fractionCompleted)
                        
                    }) { (account, etag, date, length, allHeaderFields, error, errorCode, errorDescription) in
                        
                        self.progressView.progress = 0
                        
                        if errorCode == 0 && account == metadata.account {
                            
                            NCManageDatabase.shared.addLocalFile(metadata: metadata)
                            
                            if gestureRecognizer.state == .changed || gestureRecognizer.state == .began {
                                AudioServicesPlaySystemSound(1519) // peek feedback
                                
                                if let url = NCKTVHTTPCache.shared.getVideoURL(metadata: metadata) {
                                    self.ncplayerLivePhoto = NCPlayer.init(url: url, imageVideoContainer: self.currentViewController.imageVideoContainer, playerToolBar: nil, metadata: metadata, detailView: nil)
                                    self.ncplayerLivePhoto?.playerPlay()
                                }
                            }
                        }
                    }
                }
            }
            
        } else if gestureRecognizer.state == .ended {
            
            currentViewController.statusViewImage.isHidden = false
            currentViewController.statusLabel.isHidden = false
            self.ncplayerLivePhoto?.videoRemoved()
        }
    }
}
