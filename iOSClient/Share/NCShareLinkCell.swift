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

    @IBOutlet private weak var imageItem: UIImageView!
    @IBOutlet private weak var labelTitle: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!

    @IBOutlet private weak var menuButton: UIButton!
    @IBOutlet private weak var copyButton: UIButton!
    var tableShare: tableShare?
    weak var delegate: NCShareLinkCellDelegate?
    var isInternalLink = false
    var indexPath = IndexPath()

    override func prepareForReuse() {
        super.prepareForReuse()
        isInternalLink = false
        tableShare = nil
    }

    func setupCellUI() {
        var menuImageName = "ellipsis"

        menuButton.isHidden = isInternalLink
        descriptionLabel.isHidden = !isInternalLink
        copyButton.isHidden = !isInternalLink && tableShare == nil
        if #available(iOS 18.0, *) {
            // use NCShareLinkCell image
        } else {
            copyButton.setImage(UIImage(systemName: "doc.on.doc")?.withTintColor(.label, renderingMode: .alwaysOriginal), for: .normal)
        }
        copyButton.accessibilityLabel = NSLocalizedString("_copy_", comment: "")

        menuButton.accessibilityLabel = NSLocalizedString("_more_", comment: "")
        menuButton.accessibilityIdentifier = "showShareLinkDetails"

        if isInternalLink {
            labelTitle.text = NSLocalizedString("_share_internal_link_", comment: "")
            descriptionLabel.text = NSLocalizedString("_share_internal_link_des_", comment: "")
            imageItem.image = NCUtility().loadImage(named: "square.and.arrow.up.circle.fill", colors: [NCBrandColor.shared.iconImageColor2])
        } else {
            labelTitle.text = NSLocalizedString("_share_link_", comment: "")
            if let tableShare = tableShare {
                if !tableShare.label.isEmpty {
                    labelTitle.text? += " (\(tableShare.label))"
                }
            } else {
                menuImageName = "plus"
                menuButton.accessibilityLabel = NSLocalizedString("_add_", comment: "")
                menuButton.accessibilityIdentifier = "addShareLink"
            }

            imageItem.image = NCUtility().loadImage(named: "link.circle.fill", colors: [NCBrandColor.shared.getElement(account: tableShare?.account)])
            menuButton.setImage(NCUtility().loadImage(named: menuImageName, colors: [NCBrandColor.shared.iconImageColor]), for: .normal)
        }

        labelTitle.textColor = NCBrandColor.shared.textColor
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
