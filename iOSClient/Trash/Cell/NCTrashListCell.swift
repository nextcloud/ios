//
//  NCTrashListCell.swift
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

class NCTrashListCell: UICollectionViewCell {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageItemLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageSelect: UIImageView!

    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    
    @IBOutlet weak var imageRestore: UIImageView!
    @IBOutlet weak var imageMore: UIImageView!

    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var buttonRestore: UIButton!
    
    @IBOutlet weak var separator: UIView!

    var delegate: NCTrashListCellDelegate?
    
    var objectId = ""
    var indexPath = IndexPath()

    override func awakeFromNib() {
        super.awakeFromNib()
       
        imageRestore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), width: 50, height: 50, color: NCBrandColor.sharedInstance.optionItem)
        imageMore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.optionItem)
        
        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true
        
        separator.backgroundColor = NCBrandColor.sharedInstance.separator
    }
    
    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreListItem(with: objectId, sender: sender)
    }
    
    @IBAction func touchUpInsideRestore(_ sender: Any) {
        delegate?.tapRestoreListItem(with: objectId, sender: sender)
    }
}

protocol NCTrashListCellDelegate {
    func tapRestoreListItem(with objectId: String, sender: Any)
    func tapMoreListItem(with objectId: String, sender: Any)
}
