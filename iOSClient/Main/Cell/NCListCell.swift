//
//  NCOfflineListCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class NCListCell: UICollectionViewCell {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageItemLeftConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    @IBOutlet weak var imageLocal: UIImageView!

    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelTitleTrailing: NSLayoutConstraint!

    @IBOutlet weak var labelInfo: UILabel!

    @IBOutlet weak var imageShare: UIImageView!
    @IBOutlet weak var imageShareTrailing: NSLayoutConstraint!

    @IBOutlet weak var imageMore: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    
    @IBOutlet weak var separator: UIView!

    var delegate: NCListCellDelegate?
    
    var fileID = ""
    var indexPath = IndexPath()

    let labelTitleTrailingConstant: CGFloat = 75
    let imageShareTrailingConstant: CGFloat = 45
    
    override func awakeFromNib() {
        super.awakeFromNib()
       
        imageMore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)

        separator.backgroundColor = NCBrandColor.sharedInstance.seperator
    }
    
    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreListItem(with: fileID, sender: sender)
    }
    
    func hide(buttonMore: Bool, imageShare: Bool) {
        
        if buttonMore && imageShare {
            
            self.buttonMore.isHidden = true
            self.buttonMore.isEnabled = false
            self.imageMore.isHidden = true
            self.imageShare.isHidden = true
            
            imageShareTrailing.constant = 0
            labelTitleTrailing.constant = 25
            
        } else if buttonMore && !imageShare {
            
            self.buttonMore.isHidden = true
            self.buttonMore.isEnabled = false
            self.imageMore.isHidden = true
            self.imageShare.isHidden = false
            
            imageShareTrailing.constant = 0
            labelTitleTrailing.constant = 10
            
        } else if !buttonMore && imageShare {
            
            self.buttonMore.isHidden = false
            self.buttonMore.isEnabled = true
            self.imageMore.isHidden = false
            self.imageShare.isHidden = true

            imageShareTrailing.constant = 0
            labelTitleTrailing.constant = 25
            
        } else if !buttonMore && !imageShare {
            
            self.buttonMore.isHidden = false
            self.buttonMore.isEnabled = true
            self.imageMore.isHidden = false
            self.imageShare.isHidden = false
            
            imageShareTrailing.constant = labelTitleTrailingConstant
            labelTitleTrailing.constant = labelTitleTrailingConstant
        }
    }
    
    func hideButtonMore() {
        buttonMore.isHidden = true
        buttonMore.isEnabled = false
        imageMore.isHidden = true
        labelTitleTrailing.constant = 10
    }
}

protocol NCListCellDelegate {
    func tapMoreListItem(with fileID: String, sender: Any)
}
