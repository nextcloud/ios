//
//  NCViewerImage.swift
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

class NCViewerImage: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var toolBar: UIToolbar!

    enum ScreenMode {
        case full, normal
    }
    var currentMode: ScreenMode = .normal
        
    var pageViewController: UIPageViewController {
        return self.children[0] as! UIPageViewController
    }
    
    var currentViewController: NCViewerImageZoom {
        return self.pageViewController.viewControllers![0] as! NCViewerImageZoom
    }
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    var metadatas: [tableMetadata] = []
    var currentMetadata: tableMetadata = tableMetadata()
    var currentIndex = 0
    var nextIndex: Int?
       
    var currentViewerImageZoom: NCViewerImageZoom?
    var panGestureRecognizer: UIPanGestureRecognizer!
    var singleTapGestureRecognizer: UITapGestureRecognizer!
    var longtapGestureRecognizer: UILongPressGestureRecognizer!
    
    private var player: AVPlayer?
    private var videoLayer: AVPlayerLayer?
    private var timeObserver: Any?
    private var rateObserver: Any?
    var pictureInPictureOcId: String = ""
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
        
        let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
                
        viewerImageZoom.index = currentIndex
        viewerImageZoom.image = getImageMetadata(metadatas[currentIndex])
        viewerImageZoom.metadata = metadatas[currentIndex]
        viewerImageZoom.delegate = self
        viewerImageZoom.viewerImage = self

        singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)
        
        pageViewController.setViewControllers([viewerImageZoom], direction: .forward, animated: true, completion: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuDetailClose), object: nil)
        
        progressView.tintColor = NCBrandColor.shared.brandElement
        progressView.trackTintColor = .clear
        progressView.progress = 0
        
        setToolBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        navigationController?.navigationBar.prefersLargeTitles = false

        if currentMode == .full {
            
            navigationController?.setNavigationBarHidden(true, animated: false)
            view.backgroundColor = .black
            textColor = .white
            progressView.isHidden = true
            
        } else {
            
            navigationController?.setNavigationBarHidden(false, animated: false)
            view.backgroundColor = NCBrandColor.shared.systemBackground
            textColor = NCBrandColor.shared.label
            progressView.isHidden = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object:nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let navigationController = self.navigationController {
            if !navigationController.viewControllers.contains(self) {
                videoStop()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
    }
    
    @objc func viewUnload() {
        
        navigationController?.popViewController(animated: true)
    }
    
    @objc func openMenuMore() {
        
        let imageIcon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(currentMetadata.ocId, etag: currentMetadata.etag))
        NCViewer.shared.toggleMenu(viewController: self, metadata: currentMetadata, webView: false, imageIcon: imageIcon)
    }
    
    //MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {
        
        if currentMetadata.typeFile == NCGlobal.shared.metadataTypeFileVideo {
            player?.pause()
        }
    }
    
    @objc func downloadedFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId), let errorCode = userInfo["errorCode"] as? Int {
                if errorCode == 0  && metadata.ocId == currentMetadata.ocId {
                    self.reloadCurrentPage()
                }
                if self.metadatas.first(where: { $0.ocId == metadata.ocId }) != nil {
                    progressView.progress = 0
                }
            }
        }
    }
    
    @objc func uploadedFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId), let errorCode = userInfo["errorCode"] as? Int {
                if errorCode == 0  && metadata.ocId == currentMetadata.ocId {
                    self.reloadCurrentPage()
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
                
                if ocId == currentViewerImageZoom?.metadata.ocId {
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
                        currentViewerImageZoom?.metadata = metadata
                        self.currentMetadata = metadata
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
        toolBar.tintColor = NCBrandColor.shared.brandElement
    }
    
    //
    // Detect for LIVE
    //
    @objc func didLongpressGestureEvent(gestureRecognizer: UITapGestureRecognizer) {
          
        if !currentMetadata.livePhoto { return }
        
        if gestureRecognizer.state == .began {
            
            currentViewerImageZoom?.centreConstraints()
            currentViewerImageZoom?.statusViewImage.isHidden = true
            currentViewerImageZoom?.statusLabel.isHidden = true
            
            let fileName = (currentMetadata.fileNameView as NSString).deletingPathExtension + ".mov"
            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", currentMetadata.account, currentMetadata.serverUrl, fileName)) {
                
                if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    
                    AudioServicesPlaySystemSound(1519) // peek feedback
                    self.videoPlay(metadata: metadata)
                    
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
                                self.videoPlay(metadata: metadata)
                            }
                        }
                    }
                }
            }
            
        } else if gestureRecognizer.state == .ended {
            
            currentViewerImageZoom?.statusViewImage.isHidden = false
            currentViewerImageZoom?.statusLabel.isHidden = false
            videoStop()
        }
    }
    
    //MARK: - Image
    
    func getImageMetadata(_ metadata: tableMetadata) -> UIImage? {
                
        if let image = getImage(metadata: metadata) {
            return image
        }
        
        if metadata.typeFile == NCGlobal.shared.metadataTypeFileVideo && !metadata.hasPreview {
            NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, typeFile: metadata.typeFile)
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
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && metadata.typeFile == NCGlobal.shared.metadataTypeFileImage {
           
            let previewPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
            let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            
            if ext == "GIF" {
                if !FileManager().fileExists(atPath: previewPath) {
                    NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, typeFile: metadata.typeFile)
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
                NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, typeFile: metadata.typeFile)
                image = UIImage.init(contentsOfFile: imagePath)
            }
        }
        
        return image
    }
        
    //MARK: - Video
    
    func videoPlay(metadata: tableMetadata) {
           
        NCKTVHTTPCache.shared.startProxy(user: appDelegate.user, password: appDelegate.password, metadata: metadata)
        
        func play(url: URL) {
            
            self.player = AVPlayer(url: url)
            self.player?.isMuted = CCUtility.getAudioMute()
            self.videoLayer = AVPlayerLayer(player: self.player)
            
            if self.videoLayer != nil && self.currentViewerImageZoom != nil {
            
                self.videoLayer!.frame = self.currentViewerImageZoom!.imageView.bounds
                self.videoLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
                
                self.currentViewerImageZoom!.imageView.layer.addSublayer(self.videoLayer!)
                
                // At end go back to start
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem, queue: .main) { (notification) in
                    if let item = notification.object as? AVPlayerItem, let currentItem = self.player?.currentItem, item == currentItem {
                        self.player?.seek(to: .zero)
                        if !self.currentMetadata.livePhoto {
                            NCManageDatabase.shared.deleteVideoTime(metadata: self.currentMetadata)
                        }
                    }
                }
                            
                self.rateObserver = self.player?.addObserver(self, forKeyPath: "rate", options: [], context: nil)
                
                if self.pictureInPictureOcId != metadata.ocId {
                    self.player?.play()
                }
            }
        }
        
        //NCNetworking.shared.getVideoUrl(metadata: metadata) { url in
        //            if let url = url {

        if let url = NCKTVHTTPCache.shared.getVideoURL(metadata: metadata) {
            play(url: url)
        }
    }
    
    func videoStop() {
        
        player?.pause()
        player?.seek(to: CMTime.zero)
        progressView.progress = 0
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        if rateObserver != nil {
            player?.removeObserver(self, forKeyPath: "rate")
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
            NCKTVHTTPCache.shared.stopProxy(metadata: currentMetadata)
            self.rateObserver = nil
        }
               
        videoLayer?.removeFromSuperlayer()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath != nil && keyPath == "rate" {
            
            setToolBar()
            
            if ((player?.rate) == 1) {
                
                if let time = NCManageDatabase.shared.getVideoTime(metadata: self.currentMetadata) {
                    player?.seek(to: time)
                    player?.isMuted = CCUtility.getAudioMute()
                }
                
                if rateObserver != nil && !currentMetadata.livePhoto {
                    self.progressView.progress = 0
                    if let duration = self.player?.currentItem?.asset.duration {
                        let durationSeconds = Double(CMTimeGetSeconds(duration))
                        if durationSeconds > 0 {
                            let width = Double(self.progressView.bounds.width)
                            let interval = (0.5 * durationSeconds) / width
                            let time = CMTime(seconds: interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                            if CMTIME_IS_VALID(time) && CMTimeCompare(time, .zero) != 0 {
                                self.timeObserver = self.player?.addPeriodicTimeObserver(forInterval: time, queue: .main, using: { [weak self] time in
                                    let durationSeconds = Float(CMTimeGetSeconds(duration))
                                    if durationSeconds > 0 {
                                        let currentTimeSeconds = Float(CMTimeGetSeconds(time))
                                        self?.progressView.progress = currentTimeSeconds / durationSeconds
                                    } else {
                                        self?.progressView.progress = 0
                                    }
                                })
                            }
                        }
                    }
                }
                
            } else if !self.currentMetadata.livePhoto {
                
                if let time = player?.currentTime(), let duration = self.player?.currentItem?.asset.duration {
                    let timeSecond = Double(CMTimeGetSeconds(time))
                    let durationSeconds = Double(CMTimeGetSeconds(duration))
                    if timeSecond < durationSeconds {
                        NCManageDatabase.shared.addVideoTime(metadata: self.currentMetadata, time: player?.currentTime())
                    }
                }
            }
        }
    }
    
    //MARK: - Tool Bar

    func setToolBar() {
        
        let mute = CCUtility.getAudioMute()
        
        var itemPlay = toolBar.items![0]
        let itemFlexibleSpace = toolBar.items![1]
        var itemMute = toolBar.items![2]
        
        if player?.rate == 1 {
            itemPlay = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.pause, target: self, action: #selector(playerPause))
        } else {
            itemPlay = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.play, target: self, action: #selector(playerPlay))
        }
        if mute {
            itemMute = UIBarButtonItem(image: UIImage(named: "audioOff"), style: UIBarButtonItem.Style.plain, target: self, action: #selector(SetMute))
        } else {
            itemMute = UIBarButtonItem(image: UIImage(named: "audioOn"), style: UIBarButtonItem.Style.plain, target: self, action: #selector(SetMute))
        }
        
        toolBar.setItems([itemPlay, itemFlexibleSpace, itemMute], animated: true)
        toolBar.tintColor = NCBrandColor.shared.brandElement
        toolBar.barTintColor = view.backgroundColor
    }

    @objc func playerPause() {
        player?.pause()
    }
    
    @objc func playerPlay() {
        player?.play()
    }
    
    @objc func SetMute() {
        let mute = CCUtility.getAudioMute()
        CCUtility.setAudioMute(!mute)
        player?.isMuted = !mute
        setToolBar()
    }
}


//MARK: - UIPageViewController Delegate Datasource

extension NCViewerImage: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    func shiftCurrentPage() -> Bool {
        if metadatas.count == 0 { return false }
        
        var direction: UIPageViewController.NavigationDirection = .forward
        if currentIndex == metadatas.count {
            currentIndex -= 1
            direction = .reverse
        }
        
        let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
        
        viewerImageZoom.index = currentIndex
        viewerImageZoom.image = getImageMetadata(metadatas[currentIndex])
        viewerImageZoom.metadata = metadatas[currentIndex]
        viewerImageZoom.delegate = self
        viewerImageZoom.viewerImage = self
        
        singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)
        
        pageViewController.setViewControllers([viewerImageZoom], direction: direction, animated: true, completion: nil)
        
        return true
    }
    
    func reloadCurrentPage() {
        
        if currentViewerImageZoom?.metadata.ocId == currentMetadata.ocId {
            // Disable pan gesture for strange gui results
            panGestureRecognizer.isEnabled = false
            let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
            
            viewerImageZoom.index = currentIndex
            viewerImageZoom.image = getImageMetadata(metadatas[currentIndex])
            viewerImageZoom.metadata = metadatas[currentIndex]
            viewerImageZoom.delegate = self
            viewerImageZoom.viewerImage = self
            
            singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)
            
            pageViewController.setViewControllers([viewerImageZoom], direction: .forward, animated: false, completion: nil)
            panGestureRecognizer.isEnabled = true
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if currentIndex == 0 { return nil }
        
        let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
                
        viewerImageZoom.index = currentIndex - 1
        viewerImageZoom.image = getImageMetadata(metadatas[currentIndex - 1])
        viewerImageZoom.metadata = metadatas[currentIndex - 1]
        viewerImageZoom.delegate = self
        viewerImageZoom.viewerImage = self
        
        self.singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)
        
        return viewerImageZoom
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if currentIndex == metadatas.count - 1 { return nil }
                
        let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
        
        viewerImageZoom.index = currentIndex + 1
        viewerImageZoom.image = getImageMetadata(metadatas[currentIndex + 1])
        viewerImageZoom.metadata = metadatas[currentIndex + 1]
        viewerImageZoom.delegate = self
        viewerImageZoom.viewerImage = self
        
        singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)

        return viewerImageZoom
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        
        guard let nextViewController = pendingViewControllers.first as? NCViewerImageZoom else { return }
        nextIndex = nextViewController.index
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        
        if (completed && nextIndex != nil) {
            previousViewControllers.forEach { viewController in
                let viewerImageZoom = viewController as! NCViewerImageZoom
                viewerImageZoom.scrollView.zoomScale = viewerImageZoom.scrollView.minimumZoomScale
            }
            currentIndex = nextIndex!
        }
        
        self.nextIndex = nil
    }
}

//MARK: - UIGestureRecognizerDelegate

extension NCViewerImage: UIGestureRecognizerDelegate {

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
        
        currentViewerImageZoom?.didPanWith(gestureRecognizer: gestureRecognizer)
    }
    
    @objc func didSingleTapWith(gestureRecognizer: UITapGestureRecognizer) {
             
        if currentViewerImageZoom?.detailView.isShow() ?? false {
            
            UIView.animate(withDuration: 0.2) {
                self.currentViewerImageZoom?.centreConstraints()
            }
            return
        }
        
        if currentMetadata.typeFile == NCGlobal.shared.metadataTypeFileVideo || currentMetadata.typeFile == NCGlobal.shared.metadataTypeFileAudio {
            
            if pictureInPictureOcId != currentMetadata.ocId {
                                
                // Kill PIP
                appDelegate.activeViewerVideo?.player?.replaceCurrentItem(with: nil)
                // --------
                
                appDelegate.activeViewerVideo = NCViewerVideo()
                appDelegate.activeViewerVideo?.metadata = currentMetadata
                appDelegate.activeViewerVideo?.imageBackground = UIImage(named: "file_audio")
                appDelegate.activeViewerVideo?.delegateViewerVideo = self
                if let currentViewerVideo = appDelegate.activeViewerVideo {
                    present(currentViewerVideo, animated: false) { }
                    self.videoStop()
                }
            }
            
            currentMode = .full
        }
                    
        if currentMode == .full {
            
            navigationController?.setNavigationBarHidden(false, animated: false)
            view.backgroundColor = NCBrandColor.shared.systemBackground
            textColor = NCBrandColor.shared.label
            progressView.isHidden = false
            
            currentMode = .normal
            
        } else {
            
            navigationController?.setNavigationBarHidden(true, animated: false)
            view.backgroundColor = .black
            textColor = .white
            progressView.isHidden = true
            
            currentMode = .full
        }
    }
}

//MARK: - NCViewerImageZoomDelegate

extension NCViewerImage: NCViewerImageZoomDelegate {
   
    func dismissImageZoom() {
        self.navigationController?.popViewController(animated: true)
    }
    
    func willAppearImageZoom(viewerImageZoom: NCViewerImageZoom, metadata: tableMetadata) {
        videoStop()
    }
    
    func didAppearImageZoom(viewerImageZoom: NCViewerImageZoom, metadata: tableMetadata) {
                
        navigationItem.title = metadata.fileNameView
        currentMetadata = metadata
        currentViewerImageZoom = viewerImageZoom
        toolBar.isHidden = true
        
        if (currentMetadata.typeFile == NCGlobal.shared.metadataTypeFileVideo || currentMetadata.typeFile == NCGlobal.shared.metadataTypeFileAudio) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.videoPlay(metadata: metadata)
            }
            toolBar.isHidden = false
        }
            
        if !NCOperationQueue.shared.downloadExists(metadata: metadata) {
            self.progressView.progress = 0
        }
        
        let isFolderEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        let ext = CCUtility.getExtension(metadata.fileNameView)
        
        // NO PREVIEW [RETRAY]
        if viewerImageZoom.noPreview {
            if let image = getImageMetadata(metadata) {
                viewerImageZoom.image = image
            }
        }
        
        // DOWNLOAD FILE
        if ((metadata.typeFile == NCGlobal.shared.metadataTypeFileImage && CCUtility.getAutomaticDownloadImage()) || (metadata.contentType == "image/heic" &&  metadata.hasPreview == false) || ext == "GIF" || ext == "SVG" || isFolderEncrypted) && metadata.session == "" && !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            NCOperationQueue.shared.download(metadata: metadata, selector: "")
        }
        
        // DOWNLOAD FILE LIVE PHOTO
        if let metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            if CCUtility.getAutomaticDownloadImage() && !CCUtility.fileProviderStorageExists(metadataLivePhoto.ocId, fileNameView: metadataLivePhoto.fileNameView) {
                NCOperationQueue.shared.download(metadata: metadataLivePhoto, selector: "")
            }
        }
        
        // DOWNLOAD preview
        if !CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) && metadata.hasPreview {
            
            let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!
            let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
            let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!
            
            NCCommunication.shared.downloadPreview(fileNamePathOrFileId: fileNamePath, fileNamePreviewLocalPath: fileNamePreviewLocalPath, widthPreview: NCGlobal.shared.sizePreview, heightPreview: NCGlobal.shared.sizePreview, fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: NCGlobal.shared.sizeIcon) { (account, imagePreview, imageIcon,  errorCode, errorMessage) in
                if errorCode == 0 && metadata.ocId == self.currentMetadata.ocId {
                    self.reloadCurrentPage()
                }
            }
        }
    }
}

//MARK: - NCViewerVideoDelegate

extension NCViewerImage: NCViewerVideoDelegate {
    
    func startPictureInPicture(metadata: tableMetadata) {
        pictureInPictureOcId = metadata.ocId
    }
    
    func stopPictureInPicture(metadata: tableMetadata, playing: Bool) {
        pictureInPictureOcId = ""
        if playing && currentMetadata.ocId == metadata.ocId {
            playerPlay()
        }
    }
}
