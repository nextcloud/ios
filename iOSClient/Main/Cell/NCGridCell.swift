//
//  NCGridCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/10/2018.
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

class NCGridCell: UICollectionViewCell {
    
    @IBOutlet weak var imageItem: UIImageView!
    
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    @IBOutlet weak var imageLocal: UIImageView!

    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelTitleTrailing: NSLayoutConstraint!

    @IBOutlet weak var imageShare: UIImageView!
    @IBOutlet weak var imageShareTrailing: NSLayoutConstraint!

    @IBOutlet weak var buttonMore: UIButton!

    var delegate: NCGridCellDelegate?
    
    var fileID = ""
    var indexPath = IndexPath()
    
    let labelTitleTrailingConstant: CGFloat = 50
    let imageShareTrailingConstant: CGFloat = 25
    let imageShareWidth: CGFloat = 25
    let buttonMoreWidth: CGFloat = 25

    override func awakeFromNib() {
        super.awakeFromNib()
       
        buttonMore.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem), for: UIControl.State.normal)
    }
    
    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreGridItem(with: fileID, sender: sender)
    }
    
    func hide(buttonMore: Bool, imageShare: Bool) {
        
        if buttonMore && imageShare {
            
            self.buttonMore.isHidden = true
            self.imageShare.isHidden = true
            
            labelTitleTrailing.constant = 0
            
        } else if buttonMore && !imageShare {
            
            self.buttonMore.isHidden = true
            self.imageShare.isHidden = false
            
            imageShareTrailing.constant = 0
            labelTitleTrailing.constant = imageShareWidth
            
        } else if !buttonMore && imageShare {
            
            self.buttonMore.isHidden = false
            self.imageShare.isHidden = true
            
            labelTitleTrailing.constant = buttonMoreWidth
            
        } else if !buttonMore && !imageShare {
            
            self.buttonMore.isHidden = false
            self.imageShare.isHidden = false
            
            imageShareTrailing.constant = labelTitleTrailingConstant
            labelTitleTrailing.constant = labelTitleTrailingConstant
        }
    }
}

protocol NCGridCellDelegate {
    func tapMoreGridItem(with fileID: String, sender: Any)
}
