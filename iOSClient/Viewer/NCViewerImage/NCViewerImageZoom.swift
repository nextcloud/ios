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
    func willAppearImageZoom(viewerImageZoom: NCViewerImageZoom, metadata: tableMetadata)
    func didAppearImageZoom(viewerImageZoom: NCViewerImageZoom, metadata: tableMetadata)
    func dismiss()
}

class NCViewerImageZoom: UIViewController {
    
    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusViewImage: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    
    var delegate: NCViewerImageZoomDelegate?
    var image: UIImage?
    var metadata: tableMetadata = tableMetadata()
    var index: Int = 0
    var minScale: CGFloat = 0
    
    var doubleTapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
    var startPanLocation = CGPoint.zero
    let panDistanceForPopViewController: CGFloat = 150
    let panDistanceForDetailView: CGFloat = -150
    
    var defaultImageViewTopConstraint: CGFloat = 0
    var defaultImageViewBottomConstraint: CGFloat = 0
    var defaultDetailViewTopConstraint: CGFloat = 0
    
    var openDetailView: Bool = false

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        
        if image == nil {
            image = CCGraphics.changeThemingColorImage(UIImage.init(named: "noPreview"), width: view.frame.width, height: view.frame.width, color: .gray)
        }
        
        if let image = image {
            imageView.image = image
            imageView.frame = CGRect(x: imageView.frame.origin.x, y: imageView.frame.origin.y, width: image.size.width, height: image.size.height)
        }
        
        if NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) != nil {
            statusViewImage.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "livePhoto"), width: 100, height: 100, color: .gray)
            statusLabel.text = "LIVE"
        }  else {
            statusViewImage.image = nil
            statusLabel.text = ""
        }
        
        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapWith(gestureRecognizer:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGestureRecognizer)
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPanWith(gestureRecognizer:))))

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateZoomScale()
        updateConstraints()
        
        delegate?.willAppearImageZoom(viewerImageZoom: self, metadata: metadata)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        delegate?.didAppearImageZoom(viewerImageZoom: self, metadata: metadata)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateZoomScale()
        updateConstraints()
    }
    
    //MARK: - Gesture

    @objc func didDoubleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        
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
            startPanLocation = currentLocation
            scrollView.isScrollEnabled = false
        case .ended:
            if !openDetailView {
                scrollView.isScrollEnabled = true
                imageViewTopConstraint.constant = defaultImageViewTopConstraint
                imageViewBottomConstraint.constant = defaultImageViewBottomConstraint
            }
        case .changed:
            let dy = currentLocation.y - startPanLocation.y
            imageViewTopConstraint.constant = defaultImageViewTopConstraint + dy
            imageViewBottomConstraint.constant = defaultImageViewBottomConstraint - dy
            
            if dy > panDistanceForPopViewController {
                delegate?.dismiss()
            }

            if dy < panDistanceForDetailView {
                detailViewBottomConstraint.constant = 200
                openDetailView = true
            }
            
            if dy > 0 {
                defaultDetailViewConstraint()
                openDetailView = false
            }
            
            print(dy)
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
    
    func updateConstraints() {
        
        let size = view.bounds.size
        let yOffset = max(0, (size.height - imageView.frame.height) / 2)
        imageViewTopConstraint.constant = yOffset
        imageViewBottomConstraint.constant = yOffset
        
        let xOffset = max(0, (size.width - imageView.frame.width) / 2)
        imageViewLeadingConstraint.constant = xOffset
        imageViewTrailingConstraint.constant = xOffset
        
        defaultImageViewTopConstraint = imageViewTopConstraint.constant
        defaultImageViewBottomConstraint = imageViewBottomConstraint.constant
        defaultDetailViewConstraint()
        
        view.layoutIfNeeded()

        let contentHeight = yOffset * 2 + imageView.frame.height
        scrollView.contentSize = CGSize(width: scrollView.contentSize.width, height: contentHeight)
    }
    
    func defaultDetailViewConstraint() {
        detailViewBottomConstraint.constant = -40
        openDetailView = false
    }
}

extension NCViewerImageZoom: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateConstraints()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
}
