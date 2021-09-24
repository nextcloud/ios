//
//  NCViewerImageZoom.swift
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

protocol NCViewerImageZoomDelegate {
    func didAppearImageZoom(viewerImageZoom: NCViewerImageZoom, metadata: tableMetadata)
    func dismissImageZoom()
}

class NCViewerImageZoom: UIViewController {
    
    @IBOutlet weak var detailViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageVideoContainer: imageVideoContainerView!
    @IBOutlet weak var statusViewImage: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var detailView: NCViewerImageDetailView!
    @IBOutlet weak var videoToolBar: NCViewerVideoToolBar!
    
    var delegate: NCViewerImageZoomDelegate?
    var viewerImage: NCViewerImage?
    var image: UIImage?
    var metadata: tableMetadata = tableMetadata()
    var index: Int = 0
    var isShowDetail: Bool = false
    var doubleTapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
    var imageViewConstraint: CGFloat = 0
                
    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapWith(gestureRecognizer:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
    }
    
    deinit {
        print("")
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
            // Show Video Toolbar
            if !metadata.livePhoto {
                videoToolBar.isHidden = false
            }
        } else if metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
            if image == nil {
                image = UIImage.init(named: "noPreviewAudio")!.image(color: .gray, size: view.frame.width)
            }
        } else {
            if image == nil {
                image = UIImage.init(named: "noPreview")!.image(color: .gray, size: view.frame.width)
            }
        }
        imageVideoContainer.image = image
        
        if NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) != nil {
            statusViewImage.image = NCUtility.shared.loadImage(named: "livephoto", color: .gray)
            statusLabel.text = "LIVE"
        }  else {
            statusViewImage.image = nil
            statusLabel.text = ""
        }
        
        var heightMap = (view.bounds.height / 3)
        if view.bounds.width < view.bounds.height {
            heightMap = (view.bounds.width / 3)
        }
        
        detailViewConstraint.constant = 0
        detailView.update(metadata: metadata, image: image, heightMap: heightMap)
        detailView.hide()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        delegate?.didAppearImageZoom(viewerImageZoom: self, metadata: metadata)
        
        if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NCViewerVideo.shared.initVideoPlayer(imageVideoContainer: self.imageVideoContainer, viewerVideoToolBar: self.videoToolBar, metadata: self.metadata)
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
            // back to the original size
            self.scrollView.zoom(to: CGRect(x: 0, y: 0, width: self.scrollView.bounds.width, height: self.scrollView.bounds.height), animated: false)
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: context.transitionDuration) {
                // resize frame video
                //NCViewerVideo.shared.videoLayer?.frame = self.imageView.layer.bounds
                // resize detail
                if self.detailView.isShow() {
                    self.openDetail()
                }
            }
        }) { (_) in }
    }
    
    func reload(image: UIImage, metadata: tableMetadata) {
        imageVideoContainer.image = image
        self.metadata = metadata
    }
        
    //MARK: - Gesture

    @objc func didDoubleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        
        if detailView.isShow() { return }
        
        // NO ZOOM for Audio / Video
        if (metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue) && !videoToolBar.isHidden {
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
            
            print("began")
            
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
                
                delegate?.dismissImageZoom()
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

extension NCViewerImageZoom {
    
    private func openDetail() {
        
        self.detailView.show(textColor: self.viewerImage?.textColor)
        
        if let image = imageVideoContainer.image {
            let ratioW = imageVideoContainer.frame.width / image.size.width
            let ratioH = imageVideoContainer.frame.height / image.size.height
            let ratio = ratioW < ratioH ? ratioW : ratioH
            let imageHeight = image.size.height * ratio
            imageViewConstraint = self.detailView.frame.height - ((self.view.frame.height - imageHeight) / 2) + self.view.safeAreaInsets.bottom
            if imageViewConstraint < 0 { imageViewConstraint = 0 }
        }
        
        UIView.animate(withDuration: 0.3) {
            self.imageViewTopConstraint.constant = -self.imageViewConstraint
            self.imageViewBottomConstraint.constant = self.imageViewConstraint
            self.detailViewConstraint.constant = self.detailView.frame.height
            self.view.layoutIfNeeded()
        } completion: { (_) in
        }
        
        scrollView.pinchGestureRecognizer?.isEnabled = false
        
        videoToolBar.hideToolBar()
    }
    
    private func closeDetail() {
        
        self.detailView.hide()
        imageViewConstraint = 0
        
        UIView.animate(withDuration: 0.3) {
            self.imageViewTopConstraint.constant = 0
            self.imageViewBottomConstraint.constant = 0
            self.detailViewConstraint.constant = 0
            self.view.layoutIfNeeded()
        } completion: { (_) in
        }
        
        scrollView.pinchGestureRecognizer?.isEnabled = true
        
        videoToolBar.showToolBar(metadata: metadata)
    }
}

//MARK: -

extension NCViewerImageZoom: UIScrollViewDelegate {
    
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
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        playerLayer?.frame = self.bounds
    }
}
