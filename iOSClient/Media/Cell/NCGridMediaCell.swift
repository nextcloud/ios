//
//  NCGridMediaCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/02/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

class NCGridMediaCell: UICollectionViewCell, NCImageCellProtocol {

    @IBOutlet weak var imageItem: UIImageView!

    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!

    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    @IBOutlet weak var imageLocal: UIImageView!
    
    var date: Date?

    var filePreviewImageView: UIImageView {
        get {
            return imageItem
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        initCell()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        initCell()
    }
    
    func initCell() {
        imageItem.backgroundColor = UIColor.lightGray
        imageStatus.image = nil
        imageLocal.image = nil
        imageFavorite.image = nil
        imageItem.image = nil
        imageItem.layer.masksToBounds = true
        imageItem.layer.cornerRadius = 6
        imageVisualEffect.layer.cornerRadius = 6
        imageVisualEffect.clipsToBounds = true
    }
}

