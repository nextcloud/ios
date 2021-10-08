//
//  NCViewerMediaZoom.swift
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
import NCCommunication

class NCViewerMediaZoom: UIViewController {
    
    @IBOutlet weak var detailViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailViewHeighConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageVideoContainer: imageVideoContainerView!
    @IBOutlet weak var statusViewImage: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var detailView: NCViewerMediaDetailView!
    @IBOutlet weak var playerToolBar: NCPlayerToolBar!
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var viewerMedia: NCViewerMedia?
    var ncplayer: NCPlayer?
    var image: UIImage?
    var metadata: tableMetadata = tableMetadata()
    var index: Int = 0
    var isShowDetail: Bool = false
    var doubleTapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
    var imageViewConstraint: CGFloat = 0
    var isDetailViewInitializze: Bool = false
                
    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapWith(gestureRecognizer:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
    }
    
    deinit {
        print("deinit NCViewerMediaZoom")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.delegate = self
        scrollView.maximumZoomScale = 4
        scrollView.minimumZoomScale = 1
        
        view.addGestureRecognizer(doubleTapGestureRecognizer)
        
        if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            if image == nil {
                image = UIImage.init(named: "noPreviewVideo")!.image(color: .gray, size: view.frame.width)
            }
            imageVideoContainer.image = image
            imageVideoContainer.sourceImage = image
            
        } else if metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
            if image == nil {
                image = UIImage.init(named: "noPreviewAudio")!.image(color: .gray, size: view.frame.width)
            }
            imageVideoContainer.image = image
            imageVideoContainer.sourceImage = image

        } else {
            if image == nil {
                image = UIImage.init(named: "noPreview")!.image(color: .gray, size: view.frame.width)
            }
            imageVideoContainer.image = image
            imageVideoContainer.sourceImage = image
        }
        
        if NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) != nil {
            statusViewImage.image = NCUtility.shared.loadImage(named: "livephoto", color: .gray)
            statusLabel.text = "LIVE"
        }  else {
            statusViewImage.image = nil
            statusLabel.text = ""
        }
        
        detailView.hide()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        imageVideoContainer.image = image

        viewerMedia?.navigationController?.navigationBar.prefersLargeTitles = false
        viewerMedia?.navigationItem.title = metadata.fileNameView
        
        if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue, let viewerMedia = self.viewerMedia {
            viewerMedia.currentScreenMode = viewerMedia.saveScreenModeImage
        }
                
        if viewerMedia?.currentScreenMode == .full {
            
            viewerMedia?.navigationController?.setNavigationBarHidden(true, animated: true)
            
            NCUtility.shared.colorNavigationController(viewerMedia?.navigationController, backgroundColor: .black, titleColor: .white, tintColor: nil)
            
            viewerMedia?.view.backgroundColor = .black
            viewerMedia?.textColor = .white
            viewerMedia?.progressView.isHidden = true
            
        } else {
            
            viewerMedia?.navigationController?.setNavigationBarHidden(false, animated: true)
                
            NCUtility.shared.colorNavigationController(viewerMedia?.navigationController, backgroundColor: NCBrandColor.shared.systemBackground, titleColor: NCBrandColor.shared.label, tintColor: nil)
            
            viewerMedia?.view.backgroundColor = NCBrandColor.shared.systemBackground
            viewerMedia?.textColor = NCBrandColor.shared.label
            viewerMedia?.progressView.isHidden = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if (metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue) {
            if let url = NCKTVHTTPCache.shared.getVideoURL(metadata: metadata) {
                self.ncplayer = NCPlayer.init(url: url, imageVideoContainer: self.imageVideoContainer, playerToolBar: self.playerToolBar, metadata: self.metadata, detailView: self.detailView)
            }
        }
        
        // DOWNLOAD
        downloadFile()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.ncplayer?.videoRemoved()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
            // back to the original size
            self.scrollView.zoom(to: CGRect(x: 0, y: 0, width: self.scrollView.bounds.width, height: self.scrollView.bounds.height), animated: false)
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: context.transitionDuration) {
                if self.detailView.isShow() {
                    self.openDetail()
                }
            }
        }) { (_) in }
    }
    
    func reload(image: UIImage, metadata: tableMetadata) {
        
        self.image = image

        imageVideoContainer.image = image
        imageVideoContainer.sourceImage = image
        
        self.metadata = metadata
    }
        
    //MARK: - Gesture

    @objc func didDoubleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        
        if detailView.isShow() { return }
        
        // NO ZOOM for Audio / Video
        if (metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue) && !playerToolBar.isHidden {
            return
        }
        
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
                
                viewerMedia?.navigationController?.popViewController(animated: true)
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

//MARK: -

extension NCViewerMediaZoom {
    
    private func openDetail() {
        
        CCUtility.setExif(metadata) { (latitude, longitude, location, date, lensModel) in
            
            if (latitude != -1 && latitude != 0 && longitude != -1 && longitude != 0) {
                self.detailViewHeighConstraint.constant = self.view.bounds.height / 2
            } else {
                self.detailViewHeighConstraint.constant = 200
            }
            self.view.layoutIfNeeded()
            
           self.detailView.show(metadata:self.metadata, image: self.image, textColor: self.viewerMedia?.textColor, latitude: latitude, longitude: longitude, location: location, date: date, lensModel: lensModel)
                
            if let image = self.imageVideoContainer.image {
                let ratioW = self.imageVideoContainer.frame.width / image.size.width
                let ratioH = self.imageVideoContainer.frame.height / image.size.height
                let ratio = ratioW < ratioH ? ratioW : ratioH
                let imageHeight = image.size.height * ratio
                self.imageViewConstraint = self.detailView.frame.height - ((self.view.frame.height - imageHeight) / 2) + self.view.safeAreaInsets.bottom
                if self.imageViewConstraint < 0 { self.imageViewConstraint = 0 }
            }
                
            UIView.animate(withDuration: 0.3) {
                self.imageViewTopConstraint.constant = -self.imageViewConstraint
                self.imageViewBottomConstraint.constant = self.imageViewConstraint
                self.detailViewTopConstraint.constant = self.detailViewHeighConstraint.constant
                self.view.layoutIfNeeded()
            } completion: { (_) in
            }
                
            self.scrollView.pinchGestureRecognizer?.isEnabled = false
            self.playerToolBar.hideToolBar()
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
        } completion: { (_) in
        }
        
        scrollView.pinchGestureRecognizer?.isEnabled = true        
    }
    
    func reloadDetail() {
        
        if self.detailView.isShow() {
            CCUtility.setExif(metadata) { (latitude, longitude, location, date, lensModel) in
                self.detailView.show(metadata:self.metadata, image: self.image, textColor: self.viewerMedia?.textColor, latitude: latitude, longitude: longitude, location: location, date: date, lensModel: lensModel)
            }
        }
    }
    
    func downloadFile() {
        
        let isFolderEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        let ext = CCUtility.getExtension(metadata.fileNameView)
        
        if !NCOperationQueue.shared.downloadExists(metadata: metadata) {
            viewerMedia?.progressView.progress = 0
        }
        
        // DOWNLOAD FILE
        if ((metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue && CCUtility.getAutomaticDownloadImage()) || (metadata.contentType == "image/heic" &&  metadata.hasPreview == false) || ext == "GIF" || ext == "SVG" || isFolderEncrypted) && metadata.session == "" && !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            NCOperationQueue.shared.download(metadata: metadata, selector: "")
        }
        
        // DOWNLOAD FILE LIVE PHOTO
        if let metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            if CCUtility.getAutomaticDownloadImage() && !CCUtility.fileProviderStorageExists(metadataLivePhoto.ocId, fileNameView: metadataLivePhoto.fileNameView) {
                NCOperationQueue.shared.download(metadata: metadataLivePhoto, selector: "")
            }
        }
        
        // DOWNLOAD preview for image
        if !CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) && metadata.hasPreview && metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue {
            
            NCOperationQueue.shared.downloadThumbnail(metadata: metadata, placeholder: false, cell: nil, view: nil)
        }
    }
}

//MARK: -

extension NCViewerMediaZoom: UIScrollViewDelegate {
    
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

//MARK: -

class imageVideoContainerView: UIImageView {
    var playerLayer: CALayer?
    var metadata: tableMetadata?
    var sourceImage: UIImage?
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        playerLayer?.frame = self.bounds
    }
}
