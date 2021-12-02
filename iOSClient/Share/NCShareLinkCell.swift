//
//  NCShareLinkCell.swift
//  Nextcloud
//
//  Created by Henrik Storch on 15.11.2021.
//  Copyright © 2021 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

import UIKit

class NCShareLinkCell: UITableViewCell {

    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var copyButton: UIButton!
    var tableShare: tableShare?
    var delegate: NCShareLinkCellDelegate?
    var isInternalLink = false

    override func awakeFromNib() {
        super.awakeFromNib()
        var imageName: String
        var imageBGColor: UIColor
        var menuImageName = "shareMenu"

        if isInternalLink {
            imageName = "shareInternalLink"
            imageBGColor = .gray
            descriptionLabel.text = "_share_internal_link_des_"
            labelTitle.text = "_share_internal_link_"
            menuButton.removeFromSuperview()
        } else {
            if tableShare == nil {
                copyButton.removeFromSuperview()
                menuImageName = "shareAdd"
            }
            imageName = "sharebylink"
            imageBGColor = NCBrandColor.shared.brandElement
            labelTitle.text = "_share_link_"
            descriptionLabel.removeFromSuperview()
            menuButton.setImage(UIImage.init(named: menuImageName)!.image(color: .gray, size: 50), for: .normal)
        }

        imageItem.image = NCShareCommon.shared.createLinkAvatar(imageName: imageName, colorCircle: imageBGColor)
        copyButton.setImage(UIImage.init(named: "shareCopy")!.image(color: .gray, size: 50), for: .normal)
    }

    @IBAction func touchUpCopy(_ sender: Any) {
        delegate?.tapCopy(with: tableShare, sender: sender)
    }

    @IBAction func touchUpMenu(_ sender: Any) {
        delegate?.tapMenu(with: tableShare, sender: sender)
    }
}

protocol NCShareLinkCellDelegate: AnyObject {
    func tapCopy(with tableShare: tableShare?, sender: Any)
    func tapMenu(with tableShare: tableShare?, sender: Any)
}
