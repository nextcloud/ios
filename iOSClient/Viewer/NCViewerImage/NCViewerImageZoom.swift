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

class NCViewerImageZoom: UIViewController {
    
    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusViewImage: UIImageView!
        
    weak var delegate: NCViewerImagePageContainer?
    
    var image: UIImage = UIImage()
    var metadata: tableMetadata = tableMetadata()
    var index: Int = 0
    var doubleTapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapWith(gestureRecognizer:)))
        self.doubleTapGestureRecognizer.numberOfTapsRequired = 2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        
        imageView.image = image
        imageView.frame = CGRect(x: imageView.frame.origin.x, y: imageView.frame.origin.y, width: image.size.width, height: image.size.height)
        
        if NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) != nil {
            statusViewImage.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "livePhoto"), width: 100, height: 100, color: .gray)
        } else if metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio {
            statusViewImage.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "play"), width: 100, height: 100, color: .gray)
        } else {
            statusViewImage.image = nil
        }
        
        view.addGestureRecognizer(doubleTapGestureRecognizer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        delegate?.navigationItem.title = metadata.fileNameView
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        updateZoomScaleForSize(view.bounds.size)
        updateConstraintsForSize(view.bounds.size)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateZoomScaleForSize(view.bounds.size)
        updateConstraintsForSize(view.bounds.size)
    }
    
    //MARK: - Gesture

    @objc func didDoubleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        
        let pointInView = gestureRecognizer.location(in: imageView)
        var newZoomScale = scrollView.maximumZoomScale
        
        if scrollView.zoomScale >= newZoomScale || abs(scrollView.zoomScale - newZoomScale) <= 0.01 {
            newZoomScale = scrollView.minimumZoomScale
        }
        
        let width = scrollView.bounds.width / newZoomScale
        let height = scrollView.bounds.height / newZoomScale
        let originX = pointInView.x - (width / 2.0)
        let originY = pointInView.y - (height / 2.0)
        
        let rectToZoomTo = CGRect(x: originX, y: originY, width: width, height: height)
        scrollView.zoom(to: rectToZoomTo, animated: true)
    }
    
    //MARK: - Function

    fileprivate func updateZoomScaleForSize(_ size: CGSize) {
        
        let widthScale = size.width / imageView.bounds.width
        let heightScale = size.height / imageView.bounds.height
        let minScale = min(widthScale, heightScale)
        scrollView.minimumZoomScale = minScale
        
        scrollView.zoomScale = minScale
        scrollView.maximumZoomScale = minScale * 4
    }
    
    fileprivate func updateConstraintsForSize(_ size: CGSize) {
        
        let yOffset = max(0, (size.height - imageView.frame.height) / 2)
        imageViewTopConstraint.constant = yOffset
        imageViewBottomConstraint.constant = yOffset
        
        let xOffset = max(0, (size.width - imageView.frame.width) / 2)
        imageViewLeadingConstraint.constant = xOffset
        imageViewTrailingConstraint.constant = xOffset

        let contentHeight = yOffset * 2 + imageView.frame.height
        view.layoutIfNeeded()
        scrollView.contentSize = CGSize(width: scrollView.contentSize.width, height: contentHeight)
    }
}

extension NCViewerImageZoom: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateConstraintsForSize(view.bounds.size)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
}
