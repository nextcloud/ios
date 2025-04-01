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
import NextcloudKit
import EasyTipView
import SwiftUI
import MobileVLCKit
import Alamofire

public protocol NCViewerMediaViewDelegate: AnyObject {
    func didOpenDetail()
    func didCloseDetail()
}

class NCViewerMedia: UIViewController {
    @IBOutlet weak var detailViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageVideoContainer: UIImageView!
    @IBOutlet weak var statusViewImage: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var detailView: NCViewerMediaDetailView!

    private let player = VLCMediaPlayer()
    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    weak var viewerMediaPage: NCViewerMediaPage?
    var playerToolBar: NCPlayerToolBar?
    var ncplayer: NCPlayer?
    var image: UIImage? {
        didSet {
            if #available(iOS 17.0, *), metadata.isImage {
                analyzeCurrentImage()
            }
        }
    }
    var metadata: tableMetadata = tableMetadata()
    var index: Int = 0
    var doubleTapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
    var imageViewConstraint: CGFloat = 0
    var isDetailViewInitializze: Bool = false
    weak var delegate: NCViewerMediaViewDelegate?

    private var allowOpeningDetails = true
    private var tipView: EasyTipView?

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapWith(gestureRecognizer:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
    }

    deinit {
        print("deinit NCViewerMedia")
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterOpenMediaDetail), object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.delegate = self
        scrollView.maximumZoomScale = 4
        scrollView.minimumZoomScale = 1

        view.addGestureRecognizer(doubleTapGestureRecognizer)

        if self.database.getMetadataLivePhoto(metadata: metadata) != nil {
            statusViewImage.image = utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor2])
            statusLabel.text = "LIVE"
        } else {
            statusViewImage.image = nil
            statusLabel.text = ""
        }

        if metadata.isAudioOrVideo {
            playerToolBar = Bundle.main.loadNibNamed("NCPlayerToolBar", owner: self, options: nil)?.first as? NCPlayerToolBar
            if let playerToolBar = playerToolBar {
                view.addSubview(playerToolBar)
                playerToolBar.translatesAutoresizingMaskIntoConstraints = false
                playerToolBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
                playerToolBar.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
                playerToolBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
                playerToolBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            }

            self.ncplayer = NCPlayer(imageVideoContainer: self.imageVideoContainer, playerToolBar: self.playerToolBar, metadata: self.metadata, viewerMediaPage: self.viewerMediaPage)
        }

        detailViewTopConstraint.constant = 0
        detailView.hide()

        self.image = nil
        self.imageVideoContainer.image = nil

        loadImage()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewerMediaPage?.navigationController?.navigationBar.prefersLargeTitles = false
        viewerMediaPage?.navigationItem.title = (metadata.fileNameView as NSString).deletingPathExtension

        if metadata.isImage, let viewerMediaPage = self.viewerMediaPage {
            if viewerMediaPage.modifiedOcId.contains(metadata.ocId) {
                viewerMediaPage.modifiedOcId.removeAll(where: { $0 == metadata.ocId })
                loadImage()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Set Last Opening Date
        self.database.setLastOpeningDate(metadata: metadata)

        viewerMediaPage?.clearCommandCenter()

        if metadata.isAudioOrVideo {
            if let ncplayer = self.ncplayer {
                if ncplayer.url == nil {
                    NCActivityIndicator.shared.startActivity(backgroundView: self.view, style: .medium)
                    NCNetworking.shared.getVideoUrl(metadata: metadata) { url, autoplay, error in
                        NCActivityIndicator.shared.stop()
                        if error == .success, let url = url {
                            ncplayer.openAVPlayer(url: url, autoplay: autoplay)
                        } else {
                            guard let metadata = self.database.setMetadatasSessionInWaitDownload(metadatas: [self.metadata],
                                                                                                 session: NCNetworking.shared.sessionDownload,
                                                                                                 selector: "") else { return }
                            var downloadRequest: DownloadRequest?
                            let hud = NCHud(self.tabBarController?.view)
                            hud.initHudRing(text: NSLocalizedString("_downloading_", comment: ""),
                                            tapToCancelDetailText: true) {
                                if let request = downloadRequest {
                                    request.cancel()
                                }
                            }

                            NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: false) {
                            } requestHandler: { request in
                                downloadRequest = request
                            } progressHandler: { progress in
                                hud.progress(progress.fractionCompleted)
                            } completion: { _, error in
                                DispatchQueue.main.async {
                                    if error == .success {
                                        hud.success()
                                        if self.utilityFileSystem.fileProviderStorageExists(self.metadata) {
                                            let url = URL(fileURLWithPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(self.metadata.ocId, fileNameView: self.metadata.fileNameView))
                                            ncplayer.openAVPlayer(url: url, autoplay: autoplay)
                                        }
                                    } else {
                                        hud.error(text: error.errorDescription)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    var position: Float = 0
                    if let result = self.database.getVideo(metadata: metadata), let resultPosition = result.position {
                        position = resultPosition
                    }
                    ncplayer.restartAVPlayer(position: position, pauseAfterPlay: true)
                }
            }
        } else if metadata.isImage {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showTip()
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(openDetail(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterOpenMediaDetail), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closeDetail(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile), object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissTip()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if let ncplayer = ncplayer, ncplayer.isPlaying() {
            ncplayer.playerPause()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        let wasShown = detailView.isShown

        if UIDevice.current.orientation.isValidInterfaceOrientation {

            if wasShown { closeDetail(animate: false) }
            dismissTip()
            if metadata.isVideo {
                self.imageVideoContainer.isHidden = true
            }

            coordinator.animate(alongsideTransition: { _ in
                // back to the original size
                self.scrollView.zoom(to: CGRect(x: 0, y: 0, width: self.scrollView.bounds.width, height: self.scrollView.bounds.height), animated: false)
                self.view.layoutIfNeeded()
            }, completion: { _ in
                if self.metadata.isVideo {
                    self.imageVideoContainer.isHidden = false
                } else if self.metadata.isImage {
                    self.showTip()
                }
                if wasShown {
                    self.openDetail(animate: true)
                }
            })
        }
    }

    // MARK: - Image

    func loadImage() {
        guard let metadata = self.database.getMetadataFromOcId(metadata.ocId) else { return }
        self.metadata = metadata
        let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
        let fileNameExtension = (metadata.fileNameView as NSString).pathExtension.uppercased()

        if metadata.isLivePhoto,
           NCNetworking.shared.isOnline,
           let metadata = self.database.getMetadataLivePhoto(metadata: metadata),
           !utilityFileSystem.fileProviderStorageExists(metadata),
           let metadata = self.database.setMetadatasSessionInWaitDownload(metadatas: [metadata], session: NCNetworking.shared.sessionDownload, selector: "") {
            NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
        }

        if metadata.isImage, fileNameExtension == "GIF" || fileNameExtension == "SVG", !utilityFileSystem.fileProviderStorageExists(metadata) {
            downloadImage()
        }

        if metadata.isVideo && !metadata.hasPreview {
            utility.createImageFileFrom(metadata: metadata)
            let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024)
            self.image = image
            self.imageVideoContainer.image = self.image
            return
        } else if metadata.isAudio {
            let image = utility.loadImage(named: "waveform", colors: [NCBrandColor.shared.iconImageColor2])
            self.image = image
            self.imageVideoContainer.image = self.image
            return
        } else if metadata.isImage {
            if fileNameExtension == "GIF" {
                if !NCUtility().existsImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024) {
                    utility.createImageFileFrom(metadata: metadata)
                }
                if let image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: fileNamePath)) {
                    self.image = image
                    self.imageVideoContainer.image = self.image
                } else {
                    self.image = self.utility.loadImage(named: "photo.badge.arrow.down", colors: [NCBrandColor.shared.iconImageColor2])
                    self.imageVideoContainer.image = self.image
                }
                return
            } else if fileNameExtension == "SVG" {
                if let svgImage = SVGKImage(contentsOfFile: fileNamePath) {
                    svgImage.size = NCGlobal.shared.size1024
                    if let image = svgImage.uiImage {
                        if !NCUtility().existsImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024), let data = image.jpegData(compressionQuality: 1.0) {
                            utility.createImageFileFrom(data: data, metadata: metadata)
                        }
                        self.image = image
                        self.imageVideoContainer.image = self.image
                        return
                    }
                }
                self.image = self.utility.loadImage(named: "photo", colors: [NCBrandColor.shared.iconImageColor2])
                self.imageVideoContainer.image = self.image
                return
            } else if let image = UIImage(contentsOfFile: fileNamePath) {
                self.image = image
                self.imageVideoContainer.image = self.image
                return
            }
        }

        if let image = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStorageImageOcId(metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024)) {
            self.image = image
            self.imageVideoContainer.image = self.image
        } else {
            NextcloudKit.shared.downloadPreview(fileId: metadata.fileId, account: metadata.account, options: NKRequestOptions(queue: .main)) { _, _, _, etag, responseData, error in
                if error == .success, let data = responseData?.data {
                    self.database.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)
                    let image = UIImage(data: data)
                    self.image = image
                    self.imageVideoContainer.image = self.image
                } else {
                    self.image = self.utility.loadImage(named: "photo", colors: [NCBrandColor.shared.iconImageColor2])
                    self.imageVideoContainer.image = self.image
                }
            }
        }
    }

    private func downloadImage(withSelector selector: String = "") {
        guard let metadata = self.database.setMetadatasSessionInWaitDownload(metadatas: [metadata], session: NCNetworking.shared.sessionDownload, selector: selector) else { return }
        NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true) {
        } requestHandler: { _ in
            self.allowOpeningDetails = false
        } completion: { _, _ in
            self.allowOpeningDetails = true
        }
    }

    // MARK: - Live Photo

    func playLivePhoto(filePath: String) {
        updateViewConstraints()
        statusViewImage.isHidden = true
        statusLabel.isHidden = true

        player.media = VLCMedia(url: URL(fileURLWithPath: filePath))
        player.drawable = imageVideoContainer
        player.play()
    }

    func stopLivePhoto() {
        player.stop()

        statusViewImage.isHidden = false
        statusLabel.isHidden = false
    }

    // MARK: - Gesture

    @objc func didDoubleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        guard metadata.isImage, !detailView.isShown else { return }
        let pointInView = gestureRecognizer.location(in: self.imageVideoContainer)
        var newZoomScale = self.scrollView.maximumZoomScale

        if self.scrollView.zoomScale >= newZoomScale || abs(self.scrollView.zoomScale - newZoomScale) <= 0.01 {
            newZoomScale = self.scrollView.minimumZoomScale
        }

        let width = self.scrollView.bounds.width / newZoomScale
        let height = self.scrollView.bounds.height / newZoomScale
        let originX = pointInView.x - (width / 2.0)
        let originY = pointInView.y - (height / 2.0)
        let rectToZoomTo = CGRect(x: originX, y: originY, width: width, height: height)
        self.scrollView.zoom(to: rectToZoomTo, animated: true)
    }

    @objc func didPanWith(gestureRecognizer: UIPanGestureRecognizer) {
        guard metadata.isImage else { return }
        let currentLocation = gestureRecognizer.translation(in: self.view)

        switch gestureRecognizer.state {
        case .ended:
            if detailView.isShown {
                self.imageViewTopConstraint.constant = -imageViewConstraint
                self.imageViewBottomConstraint.constant = imageViewConstraint
            } else {
                self.imageViewTopConstraint.constant = 0
                self.imageViewBottomConstraint.constant = 0
            }

        case .changed:
            imageViewTopConstraint.constant = (currentLocation.y - imageViewConstraint)
            imageViewBottomConstraint.constant = -(currentLocation.y - imageViewConstraint)

            // DISMISS VIEW
            if detailView.isHidden && (currentLocation.y > 20) {

                viewerMediaPage?.navigationController?.popViewController(animated: true)
                gestureRecognizer.state = .ended
            }

            // CLOSE DETAIL
            if !detailView.isHidden && (currentLocation.y > 20) {

                self.closeDetail()
                gestureRecognizer.state = .ended
            }

            // OPEN DETAIL
            if detailView.isHidden && (currentLocation.y < -20) {

                self.openDetail()
                gestureRecognizer.state = .ended
            }

        default:
            break
        }
    }
}

extension NCViewerMedia {
    @objc func openDetail(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary?, let ocId = userInfo["ocId"] as? String, ocId == metadata.ocId {
            allowOpeningDetails = true
            openDetail()
        }
    }

    @objc func closeDetail(_ notification: NSNotification) {
        DispatchQueue.main.async {
            self.closeDetail()
        }
    }

    func toggleDetail () {
        detailView.isShown ? closeDetail() : openDetail()
    }

    private func openDetail(animate: Bool = true) {
        if !allowOpeningDetails { return }

        delegate?.didOpenDetail()
        self.dismissTip()

        UIView.animate(withDuration: 0.3) {
            self.scrollView.setZoomScale(1.0, animated: false)

            self.statusLabel.isHidden = true
            self.statusViewImage.isHidden = true
        }

        self.utility.getExif(metadata: self.metadata) { exif in
            self.view.layoutIfNeeded()

            self.showDetailView(exif: exif)

            if let image = self.imageVideoContainer.image {
                let ratioW = self.imageVideoContainer.frame.width / image.size.width
                let ratioH = self.imageVideoContainer.frame.height / image.size.height
                let ratio = min(ratioW, ratioH)
                let imageHeight = image.size.height * ratio
                var imageContainerHeight = self.imageVideoContainer.frame.height * ratio
                let height = max(imageHeight, imageContainerHeight)
                self.imageViewConstraint = self.detailView.frame.height - ((self.view.frame.height - height) / 2) + self.view.safeAreaInsets.bottom

                if self.imageViewConstraint < 0 { self.imageViewConstraint = 0 }

                self.imageViewConstraint = min(self.imageViewConstraint, self.detailView.frame.height + 30)
                imageContainerHeight = self.imageViewConstraint.truncatingRemainder(dividingBy: 1000)
            }

            UIView.animate(withDuration: animate ? 0.3 : 0) {
                self.imageViewTopConstraint.constant = -self.imageViewConstraint
                self.imageViewBottomConstraint.constant = self.imageViewConstraint
                self.detailViewTopConstraint.constant = self.detailView.frame.height
                self.view.layoutIfNeeded()
            }

            self.scrollView.pinchGestureRecognizer?.isEnabled = false
        }
    }

    func closeDetail(animate: Bool = true) {
        delegate?.didCloseDetail()
        self.detailView.hide()
        imageViewConstraint = 0

        statusLabel.isHidden = false
        statusViewImage.isHidden = false

        UIView.animate(withDuration: animate ? 0.3 : 0) {
            self.imageViewTopConstraint.constant = 0
            self.imageViewBottomConstraint.constant = 0
            self.detailViewTopConstraint.constant = 0
            self.view.layoutIfNeeded()
        }

        scrollView.pinchGestureRecognizer?.isEnabled = true
    }

    private func showDetailView(exif: ExifData) {
        self.detailView.show(
            metadata: self.metadata,
            image: self.image,
            textColor: self.viewerMediaPage?.textColor,
            exif: exif,
            ncplayer: self.ncplayer,
            delegate: self)
    }

    func reloadDetail() {
        if self.detailView.isShown {
            utility.getExif(metadata: metadata) { exif in
                self.showDetailView(exif: exif)
            }
        }
    }
}

extension NCViewerMedia: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageVideoContainer
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale > 1 {
            if let image = imageVideoContainer.image {
                let ratioW = imageVideoContainer.frame.width / image.size.width
                let ratioH = imageVideoContainer.frame.height / image.size.height
                let ratio = ratioW < ratioH ? ratioW : ratioH
                let newWidth = image.size.width * ratio
                let newHeight = image.size.height * ratio
                let conditionLeft = newWidth * scrollView.zoomScale > imageVideoContainer.frame.width
                let left = 0.5 * (conditionLeft ? newWidth - imageVideoContainer.frame.width : (scrollView.frame.width - scrollView.contentSize.width))
                let conditioTop = newHeight * scrollView.zoomScale > imageVideoContainer.frame.height

                let top = 0.5 * (conditioTop ? newHeight - imageVideoContainer.frame.height : (scrollView.frame.height - scrollView.contentSize.height))

                scrollView.contentInset = UIEdgeInsets(top: top, left: left, bottom: top, right: left)
            }
        } else {
            scrollView.contentInset = .zero
        }
    }
}

extension NCViewerMedia: NCViewerMediaDetailViewDelegate {
    func downloadFullResolution() {
        downloadImage(withSelector: NCGlobal.shared.selectorOpenDetail)
    }
}

extension NCViewerMedia: EasyTipViewDelegate {
    func showTip() {
        if !self.database.tipExists(NCGlobal.shared.tipMediaDetailView) {
            var preferences = EasyTipView.Preferences()
            preferences.drawing.foregroundColor = .white
            preferences.drawing.backgroundColor = .lightGray
            preferences.drawing.textAlignment = .left
            preferences.drawing.arrowPosition = .bottom
            preferences.drawing.cornerRadius = 10

            preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: -15)
            preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -15)
            preferences.animating.showInitialAlpha = 0
            preferences.animating.showDuration = 0.5
            preferences.animating.dismissDuration = 0

            if tipView == nil {
                tipView = EasyTipView(text: NSLocalizedString("_tip_open_mediadetail_", comment: ""), preferences: preferences, delegate: self)
                tipView?.show(forView: detailView)
            }
        }
    }

    func easyTipViewDidTap(_ tipView: EasyTipView) {
        self.database.addTip(NCGlobal.shared.tipMediaDetailView)
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) { }

    func dismissTip() {
        if !self.database.tipExists(NCGlobal.shared.tipMediaDetailView) {
            self.database.addTip(NCGlobal.shared.tipMediaDetailView)
        }
        tipView?.dismiss()
        tipView = nil
    }
}
