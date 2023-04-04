//
//  NCViewerMediaPage.swift
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
import NextcloudKit
import MediaPlayer

class NCViewerMediaPage: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!

    enum ScreenMode {
        case full, normal
    }
    var currentScreenMode: ScreenMode = .normal
    var saveScreenModeImage: ScreenMode = .normal

    var pageViewController: UIPageViewController {
        return self.children[0] as! UIPageViewController
    }

    var currentViewController: NCViewerMedia {
        return self.pageViewController.viewControllers![0] as! NCViewerMedia
    }

    private var hideStatusBar: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    var metadatas: [tableMetadata] = []
    var modifiedOcId: [String] = []
    var currentIndex = 0
    var nextIndex: Int?
    var ncplayerLivePhoto: NCPlayer?
    var panGestureRecognizer: UIPanGestureRecognizer!
    var singleTapGestureRecognizer: UITapGestureRecognizer!
    var longtapGestureRecognizer: UILongPressGestureRecognizer!
    var textColor: UIColor = .label
    var playCommand: Any?
    var pauseCommand: Any?
    var skipForwardCommand: Any?
    var skipBackwardCommand: Any?
    var nextTrackCommand: Any?
    var previousTrackCommand: Any?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "more")!.image(color: .label, size: 25), style: .plain, target: self, action: #selector(self.openMenuMore))

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
        
        let viewerMedia = getViewerMedia(index: currentIndex, metadata: metadatas[currentIndex])
        pageViewController.setViewControllers([viewerMedia], direction: .forward, animated: true, completion: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMenuDetailClose), object: nil)

        progressView.tintColor = NCBrandColor.shared.brandElement
        progressView.trackTintColor = .clear
        progressView.progress = 0

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(uploadStartFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(hidePlayerToolBar(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterHidePlayerToolBar), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showPlayerToolBar(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterShowPlayerToolBar), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadMediaPage(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadMediaPage), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)
    }

    deinit {

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterHidePlayerToolBar), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterShowPlayerToolBar), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadMediaPage), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if let ncplayer = currentViewController.ncplayer, ncplayer.isPlay() {
            ncplayer.playerPause()
            ncplayer.saveCurrentTime()
        }
        currentViewController.playerToolBar?.stopTimerAutoHide()
        clearCommandCenter()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {

        if currentScreenMode == .normal {
            return .default
        } else {
            return .lightContent
        }
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return currentScreenMode == .full
    }

    override var prefersStatusBarHidden: Bool {
        return hideStatusBar
    }

    // MARK: -
    
    func getViewerMedia(index: Int, metadata: tableMetadata) -> NCViewerMedia {
        
        let viewerMedia = UIStoryboard(name: "NCViewerMediaPage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerMedia") as! NCViewerMedia
        viewerMedia.index = index
        viewerMedia.metadata = metadata
        viewerMedia.viewerMediaPage = self

        singleTapGestureRecognizer.require(toFail: viewerMedia.doubleTapGestureRecognizer)

        return viewerMedia
    }

    @objc func viewUnload() {

        navigationController?.popViewController(animated: true)
    }

    @objc func openMenuMore() {

        let imageIcon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(currentViewController.metadata.ocId, etag: currentViewController.metadata.etag))
        NCViewer.shared.toggleMenu(viewController: self, metadata: currentViewController.metadata, webView: false, imageIcon: imageIcon)
    }

    func changeScreenMode(mode: ScreenMode, enableTimerAutoHide: Bool = false) {

        if mode == .normal {

            navigationController?.setNavigationBarHidden(false, animated: true)
            hideStatusBar = false
            progressView.isHidden = false

            if !currentViewController.detailView.isShow() {
                currentViewController.playerToolBar?.show(enableTimerAutoHide: enableTimerAutoHide)
            }

            NCUtility.shared.colorNavigationController(navigationController, backgroundColor: .systemBackground, titleColor: .label, tintColor: nil, withoutShadow: false)
            view.backgroundColor = .systemBackground
            textColor = .label

        } else {

            navigationController?.setNavigationBarHidden(true, animated: true)
            hideStatusBar = true
            progressView.isHidden = true

            currentViewController.playerToolBar?.hide()

            view.backgroundColor = .black
            textColor = .white
        }

        currentScreenMode = mode

        if currentViewController.metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
            saveScreenModeImage = mode
        }

        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        currentViewController.reloadDetail()
    }

    // MARK: - NotificationCenter

    @objc func downloadedFile(_ notification: NSNotification) {

        progressView.progress = 0
    }

    @objc func triggerProgressTask(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let progressNumber = userInfo["progress"] as? NSNumber
        else { return }

        let progress = progressNumber.floatValue
        if progress == 1 {
            self.progressView.progress = 0
        } else {
            self.progressView.progress = progress
        }
    }

    @objc func uploadStartFile(_ notification: NSNotification) {

        /*
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let fileName = userInfo["fileName"] as? String,
              let sessionSelector = userInfo["sessionSelector"] as? String
        else { return }
        */
    }

    @objc func uploadedFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let error = userInfo["error"] as? NKError,
              error == .success,
              let index = metadatas.firstIndex(where: {$0.ocId == ocId}),
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else {
            return
        }

        metadatas[index] = metadata
        if currentViewController.metadata.ocId == ocId {
            currentViewController.reloadImage()
        } else {
            modifiedOcId.append(ocId)
        }
    }

    @objc func deleteFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else { return }

        // Stop media
        if let ncplayer = currentViewController.ncplayer, ncplayer.isPlay() {
            ncplayer.playerPause()
        }
        
        let metadatas = self.metadatas.filter { $0.ocId != ocId }
        if self.metadatas.count == metadatas.count { return }
        self.metadatas = metadatas

        if ocId == currentViewController.metadata.ocId {
            shiftCurrentPage()
        }
    }

    @objc func renameFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let index = metadatas.firstIndex(where: {$0.ocId == ocId}),
              let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId)
        else { return }

        // Stop media
        if let ncplayer = currentViewController.ncplayer, ncplayer.isPlay() {
            ncplayer.playerPause()
        }

        metadatas[index] = metadata
        if index == currentIndex {
            navigationItem.title = metadata.fileNameView
            currentViewController.metadata = metadata
            self.currentViewController.metadata = metadata
        }
    }

    @objc func moveFile(_ notification: NSNotification) {

        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else { return }

        // Stop media
        if let ncplayer = currentViewController.ncplayer, ncplayer.isPlay() {
            ncplayer.playerPause()
        }

        if metadatas.firstIndex(where: {$0.ocId == ocId}) != nil {
            deleteFile(notification)
        }
    }

    @objc func hidePlayerToolBar(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary?, let ocId = userInfo["ocId"] as? String {
            if currentViewController.metadata.ocId == ocId {
                changeScreenMode(mode: .full)
            }
        }
    }

    @objc func showPlayerToolBar(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary?, let ocId = userInfo["ocId"] as? String, let enableTimerAutoHide = userInfo["enableTimerAutoHide"] as? Bool {
            if currentViewController.metadata.ocId == ocId, let playerToolBar = currentViewController.playerToolBar, !playerToolBar.isPictureInPictureActive() {
                changeScreenMode(mode: .normal, enableTimerAutoHide: enableTimerAutoHide)
            }
        }
    }
    
    @objc func reloadMediaPage(_ notification: NSNotification) {
        
        self.reloadCurrentPage()
    }
    
    @objc func applicationDidBecomeActive(_ notification: NSNotification) {

        progressView.progress = 0
    }

    // MARK: - Command Center

    func updateCommandCenter(ncplayer: NCPlayer, metadata: tableMetadata) {

        var nowPlayingInfo = [String: Any]()

        // Clear
        clearCommandCenter()
        UIApplication.shared.beginReceivingRemoteControlEvents()

        // Add handler for Play Command
        MPRemoteCommandCenter.shared().playCommand.isEnabled = true
        playCommand = MPRemoteCommandCenter.shared().playCommand.addTarget { _ in

            if !ncplayer.isPlay() {
                ncplayer.playerPlay()
                return .success
            }
            return .commandFailed
        }

        // Add handler for Pause Command
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = true
        pauseCommand = MPRemoteCommandCenter.shared().pauseCommand.addTarget { _ in

            if ncplayer.isPlay() {
                ncplayer.playerPause()
                return .success
            }
            return .commandFailed
        }

        // VIDEO / AUDIO () ()
        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue || metadata.classFile == NKCommon.TypeClassFile.audio.rawValue {

            MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled = true
            skipForwardCommand = MPRemoteCommandCenter.shared().skipForwardCommand.addTarget { event in

                let seconds = Float64((event as! MPSkipIntervalCommandEvent).interval)
                self.currentViewController.playerToolBar?.skip(seconds: seconds)
                return.success
            }

            MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled = true
            skipBackwardCommand = MPRemoteCommandCenter.shared().skipBackwardCommand.addTarget { event in

                let seconds = Float64((event as! MPSkipIntervalCommandEvent).interval)
                self.currentViewController.playerToolBar?.skip(seconds: -seconds)
                return.success
            }
        }

        nowPlayingInfo[MPMediaItemPropertyTitle] = metadata.fileNameView
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = ncplayer.durationTime.seconds
        if let image = currentViewController.image {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                return image
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func clearCommandCenter() {

        UIApplication.shared.endReceivingRemoteControlEvents()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]

        MPRemoteCommandCenter.shared().playCommand.isEnabled = false
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = false
        MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled = false
        MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled = false
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = false
        MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = false

        if let playCommand = playCommand {
            MPRemoteCommandCenter.shared().playCommand.removeTarget(playCommand)
            self.playCommand = nil
        }
        if let pauseCommand = pauseCommand {
            MPRemoteCommandCenter.shared().pauseCommand.removeTarget(pauseCommand)
            self.pauseCommand = nil
        }
        if let skipForwardCommand = skipForwardCommand {
            MPRemoteCommandCenter.shared().skipForwardCommand.removeTarget(skipForwardCommand)
            self.skipForwardCommand = nil
        }
        if let skipBackwardCommand = skipBackwardCommand {
            MPRemoteCommandCenter.shared().skipBackwardCommand.removeTarget(skipBackwardCommand)
            self.skipBackwardCommand = nil
        }
        if let nextTrackCommand = nextTrackCommand {
            MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(nextTrackCommand)
            self.nextTrackCommand = nil
        }
        if let previousTrackCommand = previousTrackCommand {
            MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(previousTrackCommand)
            self.previousTrackCommand = nil
        }
    }
}

// MARK: - UIPageViewController Delegate Datasource

extension NCViewerMediaPage: UIPageViewControllerDelegate, UIPageViewControllerDataSource {

    func shiftCurrentPage() {

        if metadatas.count == 0 {
            self.viewUnload()
            return
        }

        var direction: UIPageViewController.NavigationDirection = .forward

        if currentIndex == metadatas.count {
            currentIndex -= 1
            direction = .reverse
        }

        let viewerMedia = getViewerMedia(index: currentIndex, metadata: metadatas[currentIndex])
        pageViewController.setViewControllers([viewerMedia], direction: direction, animated: true, completion: nil)
    }
    
    func reloadCurrentPage() {

        let viewerMedia = getViewerMedia(index: currentIndex, metadata: metadatas[currentIndex])
        viewerMedia.autoPlay = false
        pageViewController.setViewControllers([viewerMedia], direction: .forward, animated: false, completion: nil)
    }
    
    func goTo(index: Int, direction: UIPageViewController.NavigationDirection, autoPlay: Bool) {

        currentIndex = index

        let viewerMedia = getViewerMedia(index: currentIndex, metadata: metadatas[currentIndex])
        viewerMedia.autoPlay = autoPlay
        pageViewController.setViewControllers([viewerMedia], direction: direction, animated: true, completion: nil)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {

        if currentIndex == 0 { return nil }

        let viewerMedia = getViewerMedia(index: currentIndex - 1, metadata: metadatas[currentIndex - 1])
        return viewerMedia
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {

        if currentIndex == metadatas.count - 1 { return nil }

        let viewerMedia = getViewerMedia(index: currentIndex + 1, metadata: metadatas[currentIndex + 1])
        return viewerMedia
    }

    // START TRANSITION
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {

        // Save time video
        if let ncplayer = currentViewController.ncplayer, ncplayer.isPlay() {
            ncplayer.saveCurrentTime()
        }

        guard let nextViewController = pendingViewControllers.first as? NCViewerMedia else { return }
        nextIndex = nextViewController.index
    }

    // END TRANSITION
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {

        if completed && nextIndex != nil {
            previousViewControllers.forEach { viewController in
                let viewerMedia = viewController as! NCViewerMedia
                viewerMedia.ncplayer?.deactivateObserver()
            }
            currentIndex = nextIndex!
        }

        self.nextIndex = nil
    }
}

// MARK: - UIGestureRecognizerDelegate

extension NCViewerMediaPage: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        if let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = gestureRecognizer.velocity(in: self.view)

            var velocityCheck: Bool = false

            if UIDevice.current.orientation.isLandscape {
                velocityCheck = velocity.x < 0
            } else {
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

        if let playerToolBar = currentViewController.playerToolBar, playerToolBar.isPictureInPictureActive() {
            playerToolBar.pictureInPictureController?.stopPictureInPicture()
        }

        if currentScreenMode == .full {

            changeScreenMode(mode: .normal, enableTimerAutoHide: true)

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
            if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", currentViewController.metadata.account, currentViewController.metadata.serverUrl, fileName)), CCUtility.fileProviderStorageExists(metadata) {

                AudioServicesPlaySystemSound(1519) // peek feedback

                let urlVideo = NCKTVHTTPCache.shared.getVideoURL(metadata: metadata)
                
                if let url = urlVideo.url {
                    self.ncplayerLivePhoto = NCPlayer.init(url: url, autoPlay: true, isProxy: urlVideo.isProxy, imageVideoContainer: self.currentViewController.imageVideoContainer, playerToolBar: nil, metadata: metadata, detailView: nil, viewController: self)
                    self.ncplayerLivePhoto?.openAVPlayer()
                }
            }

        } else if gestureRecognizer.state == .ended {

            currentViewController.statusViewImage.isHidden = false
            currentViewController.statusLabel.isHidden = false
            currentViewController.imageVideoContainer.image = currentViewController.image
            ncplayerLivePhoto?.videoLayer?.removeFromSuperlayer()
            ncplayerLivePhoto?.deactivateObserver()
        }
    }
}
