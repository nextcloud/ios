//
//  NCOfflineListCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/10/2018.
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

class NCListCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCImageCellProtocol {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageItemLeftConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    @IBOutlet weak var imageLocal: UIImageView!

    @IBOutlet weak var labelTitle: UILabel!

    @IBOutlet weak var labelInfo: UILabel!

    @IBOutlet weak var imageShared: UIImageView!
    @IBOutlet weak var buttonShared: UIButton!
    @IBOutlet weak var sharedLeftConstraint: NSLayoutConstraint!

    @IBOutlet weak var imageMore: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    
    @IBOutlet weak var progressView: UIProgressView!
    
    @IBOutlet weak var separator: UIView!
    
    var filePreviewImageView : UIImageView {
        get{
         return imageItem
        }
    }

    var delegate: NCListCellDelegate?
    var objectId = ""
    var indexPath = IndexPath()
    var namedButtonMore = ""

    override func awakeFromNib() {
        super.awakeFromNib()
               
        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true
        
        progressView.tintColor = NCBrandColor.sharedInstance.brandElement
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
        
        setButtonMore(named: "more")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageItem.backgroundColor = nil
    }
    
    @IBAction func touchUpInsideShare(_ sender: Any) {
        delegate?.tapShareListItem(with: objectId, sender: sender)
    }
    
    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreListItem(with: objectId, namedButtonMore: namedButtonMore, sender: sender)
    }
    
    @objc func longPressInsideMore(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state != .began { return }
        delegate?.longPressMoreListItem(with: objectId, namedButtonMore: namedButtonMore, gestureRecognizer: gestureRecognizer)
    }
    
    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state != .began { return }
        delegate?.longPressListItem(with: objectId, gestureRecognizer: gestureRecognizer)
    }
    
    func setButtonMore(named: String) {
        namedButtonMore = named
        imageMore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: named), width: 50, height: 50, color: NCBrandColor.sharedInstance.optionItem)
    }
    
    func hideButtonMore() {
        imageMore.isHidden = true
        sharedLeftConstraint.constant = 5
    }
    
    func hideButtonShare(_ status: Bool) {
        imageShared.isHidden = status
        buttonShared.isHidden = status
    }
}

protocol NCListCellDelegate {
    func tapShareListItem(with objectId: String, sender: Any)
    func tapMoreListItem(with objectId: String, namedButtonMore: String, sender: Any)
    func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer)
    func longPressListItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer)
}
