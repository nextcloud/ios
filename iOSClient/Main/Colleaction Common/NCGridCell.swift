//
//  NCGridCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

import Foundation
import UIKit

class NCGridCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCImageCellProtocol {
    
    @IBOutlet weak var imageItem: UIImageView!
    
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    @IBOutlet weak var imageLocal: UIImageView!

    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var buttonMore: UIButton!

    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!
    @IBOutlet weak var progressView: UIProgressView!

    var filePreviewImageView : UIImageView {
        get{
         return imageItem
        }
    }
    
    var delegate: NCGridCellDelegate?
    var objectId = ""
    var indexPath = IndexPath()
    var namedButtonMore = ""
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true
        
        imageVisualEffect.layer.cornerRadius = 6
        imageVisualEffect.clipsToBounds = true
        
        progressView.tintColor = NCBrandColor.shared.brandElement
        progressView.transform = CGAffineTransform(scaleX: 1.0, y: 0.5)
        progressView.trackTintColor = .clear
        
        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gestureRecognizer:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        self.addGestureRecognizer(longPressedGesture)
        
        let longPressedGestureMore = UILongPressGestureRecognizer(target: self, action: #selector(longPressInsideMore(gestureRecognizer:)))
        longPressedGestureMore.minimumPressDuration = 0.5
        longPressedGestureMore.delegate = self
        longPressedGestureMore.delaysTouchesBegan = true
        buttonMore.addGestureRecognizer(longPressedGestureMore)        
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageItem.backgroundColor = nil
    }
    
    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, sender: sender)
    }
    
    @objc func longPressInsideMore(gestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.longPressMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, gestureRecognizer: gestureRecognizer)
    }
    
    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.longPressGridItem(with: objectId, gestureRecognizer: gestureRecognizer)
    }
    
    func setButtonMore(named: String, image: UIImage) {
        namedButtonMore = named
        buttonMore.setImage(image, for: .normal)
    }
    
    func hideButtonMore(_ status: Bool) {
        buttonMore.isHidden = status
    }
    
    func selectMode(_ status: Bool) {
        if status {
            imageSelect.isHidden = false
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
        }
    }
    
    func selected(_ status: Bool) {
        if status {
            imageSelect.image = NCCollectionCommon.images.cellCheckedYes
            imageVisualEffect.isHidden = false
            imageVisualEffect.alpha = 0.4
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
        }
    }
}

protocol NCGridCellDelegate {
    func tapMoreGridItem(with objectId: String, namedButtonMore: String, sender: Any)
    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer)
    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer)
}
