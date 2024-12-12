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
import Alamofire

enum ScreenMode {
    case full, normal
}

var viewerMediaScreenMode: ScreenMode = .normal

class NCViewerMediaPage: UIViewController {
    @IBOutlet weak var progressView: UIProgressView!

    /// Parameters
    var ocIds: [String] = []
    var currentIndex: Int = 0
    var delegateViewController: UIViewController?

    ///
    var modifiedOcId: [String] = []
    var nextIndex: Int?
    var panGestureRecognizer: UIPanGestureRecognizer!
    var singleTapGestureRecognizer: UITapGestureRecognizer!
    var longtapGestureRecognizer: UILongPressGestureRecognizer!
    var textColor: UIColor = NCBrandColor.shared.textColor
    var playCommand: Any?
    var pauseCommand: Any?
    var skipForwardCommand: Any?
    var skipBackwardCommand: Any?
    var nextTrackCommand: Any?
    var previousTrackCommand: Any?
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared

    // This prevents the scroll views to scroll when you drag and drop files/images/subjects (from this or other apps)
    // https://forums.developer.apple.com/forums/thread/89396 and https://forums.developer.apple.com/forums/thread/115736
    var preventScrollOnDragAndDrop = true

    var timerAutoHide: Timer?
    private var timerAutoHideSeconds: Double = 4

    private lazy var moreNavigationItem = UIBarButtonItem(image: NCImageCache.shared.getImageButtonMore(), style: .plain, target: self, action: #selector(openMenuMore))
    private lazy var imageDetailNavigationItem = UIBarButtonItem(image: NCUtility().loadImage(named: "info.circle", colors: [NCBrandColor.shared.iconImageColor]), style: .plain, target: self, action: #selector(toggleDetail))

    // swiftlint:disable force_cast
    var pageViewController: UIPageViewController {
        return self.children[0] as! UIPageViewController
    }

    var currentViewController: NCViewerMedia {
        return self.pageViewController.viewControllers![0] as! NCViewerMedia
    }
    // swiftlint:enable force_cast

    private var hideStatusBar: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    // MARK: - View Life Cycle

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        viewerMediaScreenMode = .normal
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        viewerMediaScreenMode = .normal
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.tintColor = NCBrandColor.shared.iconImageColor
        let metadata = database.getMetadataFromOcId(ocIds[currentIndex])!

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

        progressView.tintColor = NCBrandColor.shared.getElement(account: metadata.account)
        progressView.trackTintColor = .clear
        progressView.progress = 0

        let viewerMedia = getViewerMedia(index: currentIndex, metadata: metadata)
        pageViewController.setViewControllers([viewerMedia], direction: .forward, animated: true, completion: nil)
        changeScreenMode(mode: viewerMediaScreenMode)

        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(pageViewController.enableSwipeGesture), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterEnableSwipeGesture), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pageViewController.disableSwipeGesture), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDisableSwipeGesture), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(uploadStartFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)

        if NCNetworking.shared.isOnline {
            if currentViewController.metadata.isImage {
                navigationItem.rightBarButtonItems = [moreNavigationItem, imageDetailNavigationItem]
            } else {
                navigationItem.rightBarButtonItems = [moreNavigationItem]
            }
        }

        for view in self.pageViewController.view.subviews {
            if let scrollView = view as? UIScrollView {
                scrollView.delegate = self
            }
        }
    }

    deinit {
        timerAutoHide?.invalidate()

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterEnableSwipeGesture), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDisableSwipeGesture), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        startTimerAutoHide()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        currentViewController.ncplayer?.playerStop()
        timerAutoHide?.invalidate()
        clearCommandCenter()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if viewerMediaScreenMode == .normal {
            return .default
        } else {
            return .lightContent
        }
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return viewerMediaScreenMode == .full
    }

    override var prefersStatusBarHidden: Bool {
        return hideStatusBar
    }

    func getViewerMedia(index: Int, metadata: tableMetadata) -> NCViewerMedia {
        // swiftlint:disable force_cast
        let viewerMedia = UIStoryboard(name: "NCViewerMediaPage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerMedia") as! NCViewerMedia
        // swiftlint:enable force_cast

        viewerMedia.index = index
        viewerMedia.metadata = metadata
        viewerMedia.viewerMediaPage = self
        viewerMedia.delegate = self

        singleTapGestureRecognizer.require(toFail: viewerMedia.doubleTapGestureRecognizer)

        return viewerMedia
    }

    @objc func viewUnload() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func openMenuMore() {
        let imageIcon = NCUtility().getImage(ocId: currentViewController.metadata.ocId, etag: currentViewController.metadata.etag, ext: NCGlobal.shared.previewExt512)

        NCViewer().toggleMenu(controller: self.tabBarController as? NCMainTabBarController, metadata: currentViewController.metadata, webView: false, imageIcon: imageIcon)
    }

    @objc private func toggleDetail() {
        currentViewController.toggleDetail()
    }

    func changeScreenMode(mode: ScreenMode) {
        let metadata = currentViewController.metadata
        let fullscreen = currentViewController.playerToolBar?.isFullscreen ?? false

        if mode == .normal {

            if fullscreen {
                navigationController?.setNavigationBarHidden(true, animated: true)
                hideStatusBar = true
                progressView.isHidden = true
            } else {
                navigationController?.setNavigationBarHidden(false, animated: true)
                hideStatusBar = false
                progressView.isHidden = false
            }

            if metadata.isAudioOrVideo {
                colorNavigationController(backgroundColor: .black, titleColor: NCBrandColor.shared.textColor, tintColor: nil, withoutShadow: false)
                currentViewController.playerToolBar?.show()
                view.backgroundColor = .black
                textColor = .white
            } else {
                colorNavigationController(backgroundColor: .systemBackground, titleColor: NCBrandColor.shared.textColor, tintColor: nil, withoutShadow: false)
                view.backgroundColor = .systemGray6
                textColor = NCBrandColor.shared.textColor
            }

        } else if !currentViewController.detailView.isShown {

            navigationController?.setNavigationBarHidden(true, animated: true)
            hideStatusBar = true
            progressView.isHidden = true

            if metadata.isVideo {
                currentViewController.playerToolBar?.hide()
            }

            view.backgroundColor = .black
            textColor = .white
        }

        if fullscreen {
            pageViewController.disableSwipeGesture()
        } else {
            pageViewController.enableSwipeGesture()
        }

        viewerMediaScreenMode = mode
        print("Screen mode: \(viewerMediaScreenMode)")

        startTimerAutoHide()
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        currentViewController.reloadDetail()
    }

    @objc func startTimerAutoHide() {
        timerAutoHide?.invalidate()
        timerAutoHide = Timer.scheduledTimer(timeInterval: timerAutoHideSeconds, target: self, selector: #selector(autoHide), userInfo: nil, repeats: true)
    }

    @objc func autoHide() {
        let metadata = currentViewController.metadata
        if metadata.isVideo, viewerMediaScreenMode == .normal {
            changeScreenMode(mode: .full)
        }
    }

    func colorNavigationController(backgroundColor: UIColor, titleColor: UIColor, tintColor: UIColor?, withoutShadow: Bool) {

        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

        if withoutShadow {
            appearance.shadowColor = .clear
            appearance.shadowImage = UIImage()
        }

        if let tintColor = tintColor {
            navigationController?.navigationBar.tintColor = tintColor
        }

        navigationController?.view.backgroundColor = backgroundColor
        navigationController?.navigationBar.barTintColor = titleColor
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }

    // MARK: - NotificationCenter

    @objc func downloadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String
        else {
            return
        }

        self.progressView.progress = 0
        let metadata = self.currentViewController.metadata
        guard metadata.ocId == ocId, self.utilityFileSystem.fileProviderStorageExists(metadata) else { return }

        if metadata.isAudioOrVideo, let ncplayer = self.currentViewController.ncplayer {
            let url = URL(fileURLWithPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))
            if ncplayer.isPlaying() {
                ncplayer.playerPause()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    ncplayer.openAVPlayer(url: url)
                    ncplayer.playerPlay()
                }
            } else {
                ncplayer.openAVPlayer(url: url)
            }
        } else if metadata.isImage {
            self.currentViewController.loadImage()
        }
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

    @objc func uploadStartFile(_ notification: NSNotification) { }

    @objc func uploadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let error = userInfo["error"] as? NKError,
              error == .success
        else { return }

        if self.currentViewController.metadata.ocId == ocId {
            self.currentViewController.loadImage()
        } else {
            self.modifiedOcId.append(ocId)
        }
    }

    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        if error != .success {
            NCContentPresenter().showError(error: error)
        }

        if let ncplayer = currentViewController.ncplayer, ncplayer.isPlaying() {
            ncplayer.playerPause()
        }

        self.viewUnload()
    }

    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        progressView.progress = 0
        changeScreenMode(mode: .normal)
    }

    // MARK: - Command Center

    func updateCommandCenter(ncplayer: NCPlayer, title: String) {

        var nowPlayingInfo = [String: Any]()

        UIApplication.shared.beginReceivingRemoteControlEvents()

        // Add handler for Play Command
        MPRemoteCommandCenter.shared().playCommand.isEnabled = true
        playCommand = MPRemoteCommandCenter.shared().playCommand.addTarget { _ in

            if !ncplayer.isPlaying() {
                ncplayer.playerPlay()
                return .success
            }
            return .commandFailed
        }

        // Add handler for Pause Command
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = true
        pauseCommand = MPRemoteCommandCenter.shared().pauseCommand.addTarget { _ in

            if ncplayer.isPlaying() {
                ncplayer.playerPause()
                return .success
            }
            return .commandFailed
        }

        // >>
        MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled = true
        skipForwardCommand = MPRemoteCommandCenter.shared().skipForwardCommand.addTarget { event in

            let seconds = Int32((event as? MPSkipIntervalCommandEvent)?.interval ?? 0)
            ncplayer.player.jumpForward(seconds)
            return.success
        }

        // <<
        MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled = true
        skipBackwardCommand = MPRemoteCommandCenter.shared().skipBackwardCommand.addTarget { event in

            let seconds = Int32((event as? MPSkipIntervalCommandEvent)?.interval ?? 0)
            ncplayer.player.jumpBackward(seconds)
            return.success
        }

        nowPlayingInfo[MPMediaItemPropertyTitle] = title
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

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard currentIndex > 0,
              let metadata = database.getMetadataFromOcId(ocIds[currentIndex - 1]) else { return nil }

        let viewerMedia = getViewerMedia(index: currentIndex - 1, metadata: metadata)
        return viewerMedia
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard currentIndex < ocIds.count - 1,
              let metadata = database.getMetadataFromOcId(ocIds[currentIndex + 1]) else { return nil }

        let viewerMedia = getViewerMedia(index: currentIndex + 1, metadata: metadata)
        return viewerMedia
    }

    // START TRANSITION
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {

        guard let nextViewController = pendingViewControllers.first as? NCViewerMedia else { return }
        nextIndex = nextViewController.index

        if nextViewController.metadata.isImage {
            navigationItem.rightBarButtonItems = [moreNavigationItem, imageDetailNavigationItem]
        } else {
            navigationItem.rightBarButtonItems = [moreNavigationItem]
        }

        if nextViewController.detailView.isShown {
            changeScreenMode(mode: .normal)
        }
    }

    // END TRANSITION
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {

        if completed && nextIndex != nil {
            previousViewControllers.forEach { viewController in
                let viewerMedia = viewController as? NCViewerMedia
                viewerMedia?.ncplayer?.playerStop()
                viewerMedia?.closeDetail()
            }
            currentIndex = nextIndex!
        }

        changeScreenMode(mode: viewerMediaScreenMode)
        startTimerAutoHide()

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
        if currentViewController.detailView.isShown { return }

        if viewerMediaScreenMode == .full {
            changeScreenMode(mode: .normal)
        } else {
            changeScreenMode(mode: .full)
        }
    }

    // MARK: - Live Photo
    @objc func didLongpressGestureEvent(gestureRecognizer: UITapGestureRecognizer) {

        if !currentViewController.metadata.isLivePhoto || currentViewController.detailView.isShown { return }

        if gestureRecognizer.state == .began {
            if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: currentViewController.metadata),
               utilityFileSystem.fileProviderStorageExists(metadataLive) {
                AudioServicesPlaySystemSound(1519) // peek feedback
                currentViewController.playLivePhoto(filePath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId, fileNameView: metadataLive.fileName))
            }
        } else if gestureRecognizer.state == .ended {
            currentViewController.stopLivePhoto()
        }
    }
}

extension UIPageViewController {

    @objc func enableSwipeGesture() {
        for view in self.view.subviews {
            if let subView = view as? UIScrollView {
                subView.isScrollEnabled = true
            }
        }
    }

    @objc func disableSwipeGesture() {
        for view in self.view.subviews {
            if let subView = view as? UIScrollView {
                subView.isScrollEnabled = false
            }
        }
    }
}

extension NCViewerMediaPage: NCViewerMediaViewDelegate {
    func didOpenDetail() {
        changeScreenMode(mode: .normal)
        imageDetailNavigationItem.image = NCUtility().loadImage(named: "info.circle.fill")
    }

    func didCloseDetail() {
        imageDetailNavigationItem.image = NCUtility().loadImage(named: "info.circle")
    }
}

extension NCViewerMediaPage: UIScrollViewDelegate {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        preventScrollOnDragAndDrop = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if preventScrollOnDragAndDrop {
            scrollView.setContentOffset(CGPoint(x: view.frame.width + 10, y: 0), animated: false)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            preventScrollOnDragAndDrop = true
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        preventScrollOnDragAndDrop = true
    }
}
