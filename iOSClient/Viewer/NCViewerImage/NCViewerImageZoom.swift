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

protocol NCViewerImageZoomDelegate {
    func didAppearImageZoom(viewerImageZoom: NCViewerImageZoom, metadata: tableMetadata)
    func willAppearImageZoom(viewerImageZoom: NCViewerImageZoom, metadata: tableMetadata)
    func dismissImageZoom()
}

class NCViewerImageZoom: UIViewController {
    
    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
        
    @IBOutlet weak var detailViewTopConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusViewImage: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var detailView: NCViewerImageDetailView!
    
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

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapWith(gestureRecognizer:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        
        view.addGestureRecognizer(doubleTapGestureRecognizer)
        
        if image == nil {
            var named = "noPreview"
            if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileAudio { named = "noPreviewAudio" }
            if metadata.typeFile == NCBrandGlobal.shared.metadataTypeFileVideo { named = "noPreviewVideo" }
            image = CCGraphics.changeThemingColorImage(UIImage.init(named: named), width: view.frame.width, height: view.frame.width, color: .gray)
            self.noPreview = true
        }
        
        if let image = image {
            imageView.image = image
            imageView.frame = CGRect(x: imageView.frame.origin.x, y: imageView.frame.origin.y, width: image.size.width, height: image.size.height)
        }
        
        if NCManageDatabase.shared.isLivePhoto(metadata: metadata) != nil {
            statusViewImage.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "livePhoto"), width: 100, height: 100, color: .gray)
            statusLabel.text = "LIVE"
        }  else {
            statusViewImage.image = nil
            statusLabel.text = ""
        }
        
        updateZoomScale()
        centreConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !detailView.isShow() {
            
            updateZoomScale()
            centreConstraints()
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
            
            updateZoomScale()
            centreConstraints()
        }
        
        delegate?.didAppearImageZoom(viewerImageZoom: self, metadata: metadata)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if detailView.isShow() {
            
            detailView.hide()
            updateZoomScale()
            centreConstraints()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateZoomScale()
        centreConstraints()
    }
    
    //MARK: - Gesture

    @objc func didDoubleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        
        if detailView.isShow() { return }
        
        let pointInView = gestureRecognizer.location(in: imageView)
        var newZoomScale = scrollView.maximumZoomScale
        
        if scrollView.zoomScale >= newZoomScale || abs(scrollView.zoomScale - newZoomScale) <= 0.01 {
            newZoomScale = scrollView.minimumZoomScale
        }
        if newZoomScale > scrollView.maximumZoomScale {
            return
        }
        
        let width = scrollView.bounds.width / newZoomScale
        let height = scrollView.bounds.height / newZoomScale
        let originX = pointInView.x - (width / 2.0)
        let originY = pointInView.y - (height / 2.0)
        
        let rectToZoomTo = CGRect(x: originX, y: originY, width: width, height: height)
        scrollView.zoom(to: rectToZoomTo, animated: true)
    }
    
    @objc func didPanWith(gestureRecognizer: UIPanGestureRecognizer) {
        
        let currentLocation = gestureRecognizer.translation(in: self.view)
        
        switch gestureRecognizer.state {
        case .began:
            
            startPoint = CGPoint(x: currentLocation.x, y: currentLocation.y)
            topPoint = CGPoint(x: currentLocation.x, y: currentLocation.y)
            
            // save start
            startImageViewTopConstraint = imageViewTopConstraint.constant
            startImageViewBottomConstraint = imageViewBottomConstraint.constant
            
        case .ended:
            
            if !detailView.isShow() {
                UIView.animate(withDuration: 0.3) {
                    self.centreConstraints()
                } completion: { (_) in
                    self.updateZoomScale()
                    self.centreConstraints()
                }
            }
            
        case .changed:
            
            if currentLocation.y < topPoint.y { topPoint = currentLocation }
            let deltaY = startPoint.y - currentLocation.y
            
            imageViewTopConstraint.constant = startImageViewTopConstraint + currentLocation.y
            imageViewBottomConstraint.constant = startImageViewBottomConstraint - currentLocation.y
            detailViewTopConstraint.constant = -imageViewBottomConstraint.constant
            
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
                        self.imageViewTopConstraint.constant = self.startImageViewTopConstraint - self.detailView.frame.height
                        self.imageViewBottomConstraint.constant = self.startImageViewBottomConstraint + self.detailView.frame.height
                        self.detailViewTopConstraint.constant = -self.imageViewBottomConstraint.constant
                        self.view.layoutIfNeeded()
                    } completion: { (_) in
                        //end.
                    }
                }
                
                detailView.show(textColor: self.viewerImage?.textColor)
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

    func updateZoomScale() {
        
        let size = view.bounds.size
        let widthScale = size.width / imageView.bounds.width
        let heightScale = size.height / imageView.bounds.height
        minScale = min(widthScale, heightScale)
        
        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale
        scrollView.maximumZoomScale = 1
    }
    
    func centreConstraints() {
        
        let size = view.bounds.size
        let yOffset = max(0, (size.height - imageView.frame.height) / 2)
        imageViewTopConstraint.constant = yOffset
        imageViewBottomConstraint.constant = yOffset
        
        let xOffset = max(0, (size.width - imageView.frame.width) / 2)
        imageViewLeadingConstraint.constant = xOffset
        imageViewTrailingConstraint.constant = xOffset
        
        // reset detail
        detailViewTopConstraint.constant = 0
        detailView.hide()
        
        view.layoutIfNeeded()

        let contentHeight = yOffset * 2 + imageView.frame.height
        scrollView.contentSize = CGSize(width: scrollView.contentSize.width, height: contentHeight)
    }
}

extension NCViewerImageZoom: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centreConstraints()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
}
