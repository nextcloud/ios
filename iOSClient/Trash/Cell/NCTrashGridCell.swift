//
//  NCTrashGridCell.swift
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

class NCTrashGridCell: UICollectionViewCell {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var imageMore: UIImageView!
    @IBOutlet weak var buttonMoreGrid: UIButton!

    var delegate: NCTrashGridCellDelegate?
    
    var fileID = ""
    var indexPath = IndexPath()

    override func awakeFromNib() {
        super.awakeFromNib()
       
        imageMore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
    }
    
    @IBAction func touchUpInsideMoreGrid(_ sender: Any) {
        delegate?.tapMoreGridItem(with: fileID, sender: sender)
    }
}

protocol NCTrashGridCellDelegate {
    func tapMoreGridItem(with fileID: String, sender: Any)
}
