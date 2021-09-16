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
    func photoPageViewController(_ viewerImageZoom: NCViewerImageZoom, scrollViewDidScroll scrollView: UIScrollView)
    func didAppearImageZoom(viewerImageZoom: NCViewerImageZoom, metadata: tableMetadata)
    func willAppearImageZoom(viewerImageZoom: NCViewerImageZoom, metadata: tableMetadata)
    func dismissImageZoom()
}

class NCViewerImageZoom: UIViewController {
    
    @IBOutlet weak var detailViewTopConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusViewImage: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var detailView: NCViewerImageDetailView!
    @IBOutlet weak var videoToolBar: NCViewerVideoToolBar!
    
    var delegate: NCViewerImageZoomDelegate?
    var viewerImage: NCViewerImage?
    var image: UIImage?
    var metadata: tableMetadata = tableMetadata()
    var index: Int = 0
    var minScale: CGFloat = 0
    var noPreview: Bool = false
    
    var doubleTapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
                
    private var startImageViewTopConstraint: CGFloat = 0
    private var startImageViewBottomConstraint: CGFloat = 0
    private var startPoint = CGPoint.zero
    private var topPoint = CGPoint.zero

    // MARK: - View Life Cycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapWith(gestureRecognizer:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.delegate = self
        scrollView.maximumZoomScale = 4
        scrollView.minimumZoomScale = 1
        
        view.addGestureRecognizer(doubleTapGestureRecognizer)
        
        if image == nil {
            var named = "noPreview"
            if metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue { named = "noPreviewAudio" }
            if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue { named = "noPreviewVideo" }
            image = UIImage.init(named: named)!.image(color: .gray, size: view.frame.width)
            self.noPreview = true
        }
        
        if let image = image {
            imageView.image = image
            imageView.frame = CGRect(x: imageView.frame.origin.x, y: imageView.frame.origin.y, width: image.size.width, height: image.size.height)
        }
        
        if NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) != nil {
            statusViewImage.image = NCUtility.shared.loadImage(named: "livephoto", color: .gray)
            statusLabel.text = "LIVE"
        }  else {
            statusViewImage.image = nil
            statusLabel.text = ""
        }
        
//        updateZoom()
//        updateConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !detailView.isShow() {
            
//            updateZoom()
//            updateConstraints()
        }
        
        delegate?.willAppearImageZoom(viewerImageZoom: self, metadata: metadata)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var heightMap = (view.bounds.height / 3)
        if view.bounds.width < view.bounds.height {
            heightMap = (view.bounds.width / 3)
        }
        
        if !detailView.isShow() {
            
            detailView.update(metadata: metadata, image: image, heightMap: heightMap)
            detailViewTopConstraint.constant = 0
            detailView.hide()
            
//            updateZoom()
//            updateConstraints()
        }
        
        delegate?.didAppearImageZoom(viewerImageZoom: self, metadata: metadata)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if detailView.isShow() {
            
            detailView.hide()
//            updateZoom()
//            updateConstraints()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
//        updateZoom()
//        updateConstraints()
    }
    
    //MARK: - Gesture

    @objc func didDoubleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        
        if detailView.isShow() { return }
        
        // NO ZOOM for Audio / Video
        if (metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue) && !videoToolBar.isHidden {
            return
        }
        
        let pointInView = gestureRecognizer.location(in: self.imageView)
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
        
        // NO INFO for Audio / Video
        if viewerImage?.viewerVideo?.player?.rate == 1 { return }
        
        let currentLocation = gestureRecognizer.translation(in: self.view)
        
        switch gestureRecognizer.state {
        case .began:
            
            startPoint = CGPoint(x: currentLocation.x, y: currentLocation.y)
            topPoint = CGPoint(x: currentLocation.x, y: currentLocation.y)
            
            // save start
//            startImageViewTopConstraint = imageViewTopConstraint.constant
//            startImageViewBottomConstraint = imageViewBottomConstraint.constant
             
            // VideoToolBar
            self.videoToolBar.hideToolBar()
            
        case .ended:
            
            if !detailView.isShow() {
                UIView.animate(withDuration: 0.3) {
//                    self.updateConstraints()
                } completion: { (_) in
//                    self.updateZoom()
//                    self.updateConstraints()
                }
            } else if detailView.isSavedContraint() {
                UIView.animate(withDuration: 0.3) {
//                    self.imageViewTopConstraint.constant = self.detailView.imageViewTopConstraintConstant
//                    self.imageViewBottomConstraint.constant = self.detailView.imageViewBottomConstraintConstant
                    self.detailViewTopConstraint.constant = self.detailView.detailViewTopConstraintConstant
                    self.view.layoutIfNeeded()
                } completion: { (_) in
                }
            }
            
            // VideoToolBar
            if metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
                if detailView.isShow() {
                    self.videoToolBar.hideToolBar()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.videoToolBar.showToolBar()
                    }
                }
            }
            
        case .changed:
            
            if currentLocation.y < topPoint.y { topPoint = currentLocation }
            let deltaY = startPoint.y - currentLocation.y
            
//            imageViewTopConstraint.constant = startImageViewTopConstraint + currentLocation.y
//            imageViewBottomConstraint.constant = startImageViewBottomConstraint - currentLocation.y
//            detailViewTopConstraint.constant = -imageViewBottomConstraint.constant
            
            // DISMISS
            if imageView.center.y > view.center.y + 100 {
                
                delegate?.dismissImageZoom()
            }

            // OPEN DETAIL
            if imageView.center.y < view.center.y - 30 {
                  
                if detailView.isHidden {
                    
                    detailView.show(textColor: self.viewerImage?.textColor)
                    gestureRecognizer.state = .ended
                     
                    UIView.animate(withDuration: 0.3) {
//                        self.imageViewTopConstraint.constant = self.startImageViewTopConstraint - self.detailView.frame.height
//                        self.imageViewBottomConstraint.constant = self.startImageViewBottomConstraint + self.detailView.frame.height
//                        self.detailViewTopConstraint.constant = -self.imageViewBottomConstraint.constant
                        self.view.layoutIfNeeded()
                    } completion: { (_) in
                        // Save detail constraints
//                        self.detailView.imageViewTopConstraintConstant = self.imageViewTopConstraint.constant
//                        self.detailView.imageViewBottomConstraintConstant = self.imageViewBottomConstraint.constant
//                        self.detailView.detailViewTopConstraintConstant = self.detailViewTopConstraint.constant
                    }
                }
                
                //detailView.show(textColor: self.viewerImage?.textColor)
            }
            
            // CLOSE DETAIL
            if (imageView.center.y > view.center.y + 30) || (deltaY < -30) || (topPoint.y + 30 < currentLocation.y) {
                
                if detailView.isShow() {
                    detailView.hide()
                    gestureRecognizer.state = .ended
                }
            }
            
        default:
            break
        }
    }
    
    //MARK: - Function

    /*
    private func updateZoom() {
        
        let widthScale = self.view.bounds.size.width / imageView.bounds.width
        let heightScale = self.view.bounds.size.height / imageView.bounds.height
        let minScale = min(widthScale, heightScale)
    
        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale
        scrollView.maximumZoomScale = minScale * 4
    }
    
    func updateConstraints() {
        
        let xOffset = max(0, (self.view.bounds.size.width - imageView.frame.width) / 2)
        let yOffset = max(0, (self.view.bounds.size.height - imageView.frame.height) / 2)

        imageViewTopConstraint.constant = yOffset
        imageViewBottomConstraint.constant = yOffset
            
        imageViewLeadingConstraint.constant = xOffset
        imageViewTrailingConstraint.constant = xOffset

        // reset detail
        detailViewTopConstraint.constant = 0
        detailView.hide()
                
        let contentWidth = xOffset * 2 + imageView.frame.width
        let contentHeight = yOffset * 2 + imageView.frame.height
        view.layoutIfNeeded()
        self.scrollView.contentSize = CGSize(width: contentWidth, height: contentHeight)

        print("x: \(xOffset) - y: \(yOffset) - contentWidth: \(contentWidth) - contentHeight: \(contentHeight)")
    }
    */
}

extension NCViewerImageZoom: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale > 1 {
            if let image = imageView.image {
                let ratioW = imageView.frame.width / image.size.width
                let ratioH = imageView.frame.height / image.size.height
                
                let ratio = ratioW < ratioH ? ratioW : ratioH
                let newWidth = image.size.width * ratio
                let newHeight = image.size.height * ratio
                let conditionLeft = newWidth*scrollView.zoomScale > imageView.frame.width
                let left = 0.5 * (conditionLeft ? newWidth - imageView.frame.width : (scrollView.frame.width - scrollView.contentSize.width))
                let conditioTop = newHeight*scrollView.zoomScale > imageView.frame.height
                
                let top = 0.5 * (conditioTop ? newHeight - imageView.frame.height : (scrollView.frame.height - scrollView.contentSize.height))
                
                scrollView.contentInset = UIEdgeInsets(top: top, left: left, bottom: top, right: left)
                
            }
        } else {
            scrollView.contentInset = .zero
        }    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.delegate?.photoPageViewController(self, scrollViewDidScroll: scrollView)
    }
}
