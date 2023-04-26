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

class NCViewerMedia: UIViewController {

    @IBOutlet weak var detailViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailViewHeighConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageVideoContainer: imageVideoContainerView!
    @IBOutlet weak var statusViewImage: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var detailView: NCViewerMediaDetailView!

    private var _autoPlay: Bool = false
    private var tipView: EasyTipView?

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    weak var viewerMediaPage: NCViewerMediaPage?
    var playerToolBar: NCPlayerToolBar?
    var ncplayer: NCPlayer?
    var image: UIImage?
    var metadata: tableMetadata = tableMetadata()
    var index: Int = 0
    var doubleTapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
    var imageViewConstraint: CGFloat = 0
    var isDetailViewInitializze: Bool = false

    var autoPlay: Bool {
        get {
            let temp = _autoPlay
            _autoPlay = false
            return temp
        }
        set(newVal) {
            _autoPlay = newVal
        }
    }

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapWith(gestureRecognizer:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
    }

    deinit {
        print("deinit NCViewerMedia")

        self.tipView?.dismiss()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterOpenMediaDetail), object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.delegate = self
        scrollView.maximumZoomScale = 4
        scrollView.minimumZoomScale = 1

        view.addGestureRecognizer(doubleTapGestureRecognizer)

        if NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) != nil {
            statusViewImage.image = NCUtility.shared.loadImage(named: "livephoto", color: .gray)
            statusLabel.text = "LIVE"
        } else {
            statusViewImage.image = nil
            statusLabel.text = ""
        }
        
        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue || metadata.classFile == NKCommon.TypeClassFile.audio.rawValue {

            playerToolBar = Bundle.main.loadNibNamed("NCPlayerToolBar", owner: self, options: nil)?.first as? NCPlayerToolBar
            if let playerToolBar = playerToolBar {
                view.addSubview(playerToolBar)
                playerToolBar.translatesAutoresizingMaskIntoConstraints = false
                playerToolBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
                playerToolBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0).isActive = true
                playerToolBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
                playerToolBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0).isActive = true
                playerToolBar.viewerMediaPage = viewerMediaPage
            }

            let urlVideo = NCKTVHTTPCache.shared.getVideoURL(metadata: metadata)
            if let url = urlVideo.url {
                self.ncplayer = NCPlayer.init(url: url, autoPlay: self.autoPlay, isProxy: urlVideo.isProxy, imageVideoContainer: self.imageVideoContainer, playerToolBar: self.playerToolBar, metadata: self.metadata, detailView: self.detailView, viewController: self)
            }
        }

        // TIP
        var preferences = EasyTipView.Preferences()
        preferences.drawing.foregroundColor = .white
        preferences.drawing.backgroundColor = NCBrandColor.shared.nextcloud
        preferences.drawing.textAlignment = .left
        preferences.drawing.arrowPosition = .top
        preferences.drawing.cornerRadius = 10

        preferences.animating.dismissTransform = CGAffineTransform(translationX: 0, y: 100)
        preferences.animating.showInitialTransform = CGAffineTransform(translationX: 0, y: -100)
        preferences.animating.showInitialAlpha = 0
        preferences.animating.showDuration = 0.5
        preferences.animating.dismissDuration = 0

        tipView = EasyTipView(text: NSLocalizedString("_tip_open_mediadetail_", comment: ""), preferences: preferences, delegate: self)

        detailViewTopConstraint.constant = 0
        detailView.hide()

        self.image = nil
        self.imageVideoContainer.image = nil

        reloadImage()
        NotificationCenter.default.addObserver(self, selector: #selector(rotateImage), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationImagePreviewRotateImage), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewerMediaPage?.navigationController?.navigationBar.prefersLargeTitles = false
        viewerMediaPage?.navigationItem.title = metadata.fileNameView

        if metadata.classFile == NKCommon.TypeClassFile.image.rawValue, let viewerMediaPage = self.viewerMediaPage {
            viewerMediaPage.currentScreenMode = viewerMediaPage.saveScreenModeImage
            if viewerMediaPage.modifiedOcId.contains(metadata.ocId) {
                viewerMediaPage.modifiedOcId.removeAll(where: { $0 == metadata.ocId })
                reloadImage()
            }
        }

        if viewerMediaPage?.currentScreenMode == .full {

            viewerMediaPage?.navigationController?.setNavigationBarHidden(true, animated: true)

            NCUtility.shared.colorNavigationController(viewerMediaPage?.navigationController, backgroundColor: .black, titleColor: .white, tintColor: nil, withoutShadow: false)

            viewerMediaPage?.view.backgroundColor = .black
            viewerMediaPage?.textColor = .white
            viewerMediaPage?.progressView.isHidden = true

        } else {

            viewerMediaPage?.navigationController?.setNavigationBarHidden(false, animated: true)

            NCUtility.shared.colorNavigationController(viewerMediaPage?.navigationController, backgroundColor: .systemBackground, titleColor: .label, tintColor: nil, withoutShadow: false)

            viewerMediaPage?.view.backgroundColor = .systemBackground
            viewerMediaPage?.textColor = .label
            viewerMediaPage?.progressView.isHidden = false
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue || metadata.classFile == NKCommon.TypeClassFile.audio.rawValue {

            if let ncplayer = self.ncplayer {
                ncplayer.openAVPlayer()
                self.viewerMediaPage?.updateCommandCenter(ncplayer: ncplayer, metadata: self.metadata)
            }
            
        } else if metadata.classFile == NKCommon.TypeClassFile.image.rawValue {

            viewerMediaPage?.clearCommandCenter()
        }

        showTip()

        NotificationCenter.default.addObserver(self, selector: #selector(openDetail(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterOpenMediaDetail), object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationImagePreviewRotateImage), object: nil)
        super.viewWillDisappear(animated)

        self.tipView?.dismiss()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        self.tipView?.dismiss()
        coordinator.animate(alongsideTransition: { context in
            // back to the original size
            self.scrollView.zoom(to: CGRect(x: 0, y: 0, width: self.scrollView.bounds.width, height: self.scrollView.bounds.height), animated: false)
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: context.transitionDuration) {
                if self.detailView.isShow() {
                    self.openDetail()
                }
            }
        }, completion: { context in
            self.showTip()
        })
    }

    // MARK: - Tip

    func showTip() {

        if !NCManageDatabase.shared.tipExists(NCGlobal.shared.tipNCViewerMediaDetailView), let view = self.navigationController?.navigationBar {
            self.tipView?.show(forView: view)
        }
    }

    // MARK: - Image

    func reloadImage() {
        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) {
            self.metadata = metadata
            loadImage(metadata: metadata)
        }
    }

    func loadImage(metadata: tableMetadata) {

        // Download image
        if !CCUtility.fileProviderStorageExists(metadata) && metadata.classFile == NKCommon.TypeClassFile.image.rawValue && metadata.session == "" {

            if metadata.livePhoto {
                let fileName = (metadata.fileNameView as NSString).deletingPathExtension + ".mov"
                if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", metadata.account, metadata.serverUrl, fileName)), !CCUtility.fileProviderStorageExists(metadata) {
                    NCNetworking.shared.download(metadata: metadata, selector: "") { _, _ in }
                }
            }

            NCNetworking.shared.download(metadata: metadata, selector: "") { _, _ in
                let image = getImageMetadata(metadata)
                if self.metadata.ocId == metadata.ocId && self.imageVideoContainer.layer.sublayers?.count == nil {
                    self.image = image
                    self.imageVideoContainer.image = image
                }
            }
        }

        // Get image
        let image = getImageMetadata(metadata)
        if self.metadata.ocId == metadata.ocId && self.imageVideoContainer.layer.sublayers?.count == nil {
            self.image = image
            self.imageVideoContainer.image = image
        }

        func getImageMetadata(_ metadata: tableMetadata) -> UIImage? {

            if let image = getImage(metadata: metadata) {
                return image
            }

            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue && !metadata.hasPreview {
                NCUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
            }

            if CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
                if let imagePreviewPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag) {
                    return UIImage(contentsOfFile: imagePreviewPath)
                }
            }

            if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                return UIImage(named: "noPreviewVideo")!.image(color: .gray, size: view.frame.width)
            } else if metadata.classFile == NKCommon.TypeClassFile.audio.rawValue {
                return UIImage(named: "noPreviewAudio")!.image(color: .gray, size: view.frame.width)
            } else {
                return UIImage(named: "noPreview")!.image(color: .gray, size: view.frame.width)
            }
        }

        func getImage(metadata: tableMetadata) -> UIImage? {

            let ext = CCUtility.getExtension(metadata.fileNameView)
            var image: UIImage?

            if CCUtility.fileProviderStorageExists(metadata) && metadata.classFile == NKCommon.TypeClassFile.image.rawValue {

                let previewPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
                let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

                if ext == "GIF" {
                    if !FileManager().fileExists(atPath: previewPath) {
                        NCUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
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
                    NCUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
                    image = UIImage(contentsOfFile: imagePath)
                }
            }

            return image
        }
    }

    // MARK: - Gesture

    @objc func didDoubleTapWith(gestureRecognizer: UITapGestureRecognizer) {

        if detailView.isShow() { return }
        // NO ZOOM for Audio
        if metadata.classFile == NKCommon.TypeClassFile.audio.rawValue { return }

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

        let currentLocation = gestureRecognizer.translation(in: self.view)

        switch gestureRecognizer.state {

        case .began:

//        let velocity = gestureRecognizer.velocity(in: self.view)

//            gesture moving Up
//            if velocity.y < 0 {

//            }
            break

        case .ended:

            if detailView.isShow() {
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

// MARK: -

extension NCViewerMedia {

    @objc func openDetail(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary?, let ocId = userInfo["ocId"] as? String, ocId == metadata.ocId {
            openDetail()
        }
    }

    private func openDetail() {

        self.dismissTip()
        
        CCUtility.setExif(metadata) { latitude, longitude, location, date, lensModel in

            if latitude != -1 && latitude != 0 && longitude != -1 && longitude != 0 {
                self.detailViewHeighConstraint.constant = self.view.bounds.height / 2
            } else {
                self.detailViewHeighConstraint.constant = 170
            }
            self.view.layoutIfNeeded()
            self.detailView.show(
                metadata: self.metadata,
                image: self.image,
                textColor: self.viewerMediaPage?.textColor,
                mediaMetadata: (latitude: latitude, longitude: longitude, location: location, date: date, lensModel: lensModel),
                ncplayer: self.ncplayer,
                delegate: self)
                
            if let image = self.imageVideoContainer.image {
                let ratioW = self.imageVideoContainer.frame.width / image.size.width
                let ratioH = self.imageVideoContainer.frame.height / image.size.height
                let ratio = ratioW < ratioH ? ratioW : ratioH
                let imageHeight = image.size.height * ratio
                let VideoContainerHeight = self.imageVideoContainer.frame.height * ratio
                let height = max(imageHeight, VideoContainerHeight)
                self.imageViewConstraint = self.detailView.frame.height - ((self.view.frame.height - height) / 2) + self.view.safeAreaInsets.bottom
                if self.imageViewConstraint < 0 { self.imageViewConstraint = 0 }
            }

            UIView.animate(withDuration: 0.3) {
                self.imageViewTopConstraint.constant = -self.imageViewConstraint
                self.imageViewBottomConstraint.constant = self.imageViewConstraint
                self.detailViewTopConstraint.constant = self.detailViewHeighConstraint.constant
                self.view.layoutIfNeeded()
            } completion: { _ in
            }

            self.scrollView.pinchGestureRecognizer?.isEnabled = false
            self.playerToolBar?.hide()
        }
    }

    private func closeDetail() {

        self.detailView.hide()
        imageViewConstraint = 0

        UIView.animate(withDuration: 0.3) {
            self.imageViewTopConstraint.constant = 0
            self.imageViewBottomConstraint.constant = 0
            self.detailViewTopConstraint.constant = 0
            self.view.layoutIfNeeded()
        } completion: { _ in
        }

        scrollView.pinchGestureRecognizer?.isEnabled = true
        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue && !metadata.livePhoto && ncplayer?.player?.timeControlStatus == .paused {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId": metadata.ocId, "enableTimerAutoHide": false])
        }
    }

    func reloadDetail() {

        if self.detailView.isShow() {
            CCUtility.setExif(metadata) { (latitude, longitude, location, date, lensModel) in
                self.detailView.show(
                    metadata: self.metadata,
                    image: self.image,
                    textColor: self.viewerMediaPage?.textColor,
                    mediaMetadata: (latitude: latitude, longitude: longitude, location: location, date: date, lensModel: lensModel),
                    ncplayer: self.ncplayer,
                    delegate: self)
            }
        }
    }
}

// MARK: -

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
                let conditionLeft = newWidth*scrollView.zoomScale > imageVideoContainer.frame.width
                let left = 0.5 * (conditionLeft ? newWidth - imageVideoContainer.frame.width : (scrollView.frame.width - scrollView.contentSize.width))
                let conditioTop = newHeight*scrollView.zoomScale > imageVideoContainer.frame.height

                let top = 0.5 * (conditioTop ? newHeight - imageVideoContainer.frame.height : (scrollView.frame.height - scrollView.contentSize.height))

                scrollView.contentInset = UIEdgeInsets(top: top, left: left, bottom: top, right: left)
            }
        } else {
            scrollView.contentInset = .zero
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
}

extension NCViewerMedia: NCViewerMediaDetailViewDelegate {

    func downloadFullResolution() {
        closeDetail()
        NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorOpenDetail) { _, _ in }
    }
}

extension NCViewerMedia: EasyTipViewDelegate {

    // TIP
    func easyTipViewDidTap(_ tipView: EasyTipView) {
        NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCViewerMediaDetailView)
    }

    func easyTipViewDidDismiss(_ tipView: EasyTipView) { }

    func dismissTip() {
        NCManageDatabase.shared.addTip(NCGlobal.shared.tipNCViewerMediaDetailView)
        self.tipView?.dismiss()
    }
}

//MARK: Rotate Image
extension NCViewerMedia {
    @objc func rotateImage() {
        if viewerMediaPage?.navigationItem.leftBarButtonItem == nil {
            let leftButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneRotate(sender:)))
            viewerMediaPage?.navigationItem.leftBarButtonItem = leftButton

            let rightButton = UIBarButtonItem(title: NSLocalizedString("_rotate_button_", comment: ""), style: .plain, target: self, action: #selector(rotateImage))
            viewerMediaPage?.navigationItem.rightBarButtonItem = rightButton
            viewerMediaPage?.pageViewController.dataSource = nil
        }
        
        let originalImage = imageVideoContainer.image
        let rotatedImage = originalImage?.rotateExif(orientation: .right)
        imageVideoContainer.image = rotatedImage
        scrollView.layoutIfNeeded()
    }
    
    @objc func doneRotate(sender: Any) {
        let message = NSLocalizedString("_save_changes_message_", comment: "")
        let alertController = UIAlertController(title: NSLocalizedString("_save_", comment: ""), message: message, preferredStyle: .alert)
            
        let discard = NSLocalizedString("_discard_", comment: "")
        alertController.addAction(UIAlertAction(title: discard, style: .cancel, handler: { [weak self] action in
            self?.discardRotatedImage()
        }))
        
        let save = NSLocalizedString("_save_", comment: "")
        alertController.addAction(UIAlertAction(title: save, style: .default, handler: { [weak self] action in
            self?.saveRotatedImage()
        }))
        
        self.present(alertController, animated: true)
    }
    func saveRotatedImage() {
        viewerMediaPage?.navigationItem.leftBarButtonItem = nil
        if let image = imageVideoContainer.image {
            uploadRotatedImage(image: image)
        }
        navigationController?.popViewController(animated: true)
    }
    
    func discardRotatedImage() {
        viewerMediaPage?.navigationItem.leftBarButtonItem = nil
        imageVideoContainer.image = image
        scrollView.layoutIfNeeded()
        viewerMediaPage?.pageViewController.dataSource = viewerMediaPage
        viewerMediaPage?.navigationItem.rightBarButtonItem = UIBarButtonItem.init(image: UIImage(named: "more")!.image(color: .label, size: 25), style: .plain, target: viewerMediaPage, action: #selector(viewerMediaPage?.openMenuMore))
    }
    
    func uploadRotatedImage(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let url = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!)
        
        do {
            try data.write(to: url)
        } catch {
            print("Unable to save file: ", error.localizedDescription)
            return
        }
        
        let ocId = NSUUID().uuidString
        let size = NCUtilityFileSystem.shared.getFileSize(filePath: url.path)
        
        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: metadata.fileNameView)!
        
        if NCUtilityFileSystem.shared.copyFile(atPath: url.path, toPath: fileNamePath) {
            
            let metadataForUpload = NCManageDatabase.shared.createMetadata(account: metadata.account, user: metadata.user, userId: metadata.userId, fileName: metadata.fileName, fileNameView: metadata.fileNameView, ocId: ocId, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, url: url.path, contentType: "", isLivePhoto: false)
            
            metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground
            metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
            metadataForUpload.size = size
            metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
            
            NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: [metadataForUpload]) { _ in}
        }
    }
}

// MARK: -

class imageVideoContainerView: UIImageView {
    var playerLayer: CALayer?
    var metadata: tableMetadata?
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        playerLayer?.frame = self.bounds
    }
}
