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
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!

    weak var delegate: NCTrashListCellDelegate?

    var objectId = ""

    override func awakeFromNib() {
        super.awakeFromNib()

        imageRestore.image = NCBrandColor.cacheImages.buttonRestore
        imageMore.image = NCBrandColor.cacheImages.buttonMore

        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true

        separator.backgroundColor = NCBrandColor.shared.separator
        separatorHeightConstraint.constant = 0.5
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreListItem(with: objectId, image: imageItem.image, sender: sender)
    }

    @IBAction func touchUpInsideRestore(_ sender: Any) {
        delegate?.tapRestoreListItem(with: objectId, image: imageItem.image, sender: sender)
    }

    func selectMode(_ status: Bool) {
        if status {
            imageItemLeftConstraint.constant = 45
            imageSelect.isHidden = false
        } else {
            imageItemLeftConstraint.constant = 10
            imageSelect.isHidden = true
            backgroundView = nil
        }
    }

    func selected(_ status: Bool) {
        if status {
            var blurEffect: UIVisualEffect?
            var blurEffectView: UIView?
            imageSelect.image = NCBrandColor.cacheImages.checkedYes
            if traitCollection.userInterfaceStyle == .dark {
                blurEffect = UIBlurEffect(style: .dark)
                blurEffectView = UIVisualEffectView(effect: blurEffect)
                blurEffectView?.backgroundColor = .black
            } else {
                blurEffect = UIBlurEffect(style: .extraLight)
                blurEffectView = UIVisualEffectView(effect: blurEffect)
                blurEffectView?.backgroundColor = .lightGray
            }
            blurEffectView?.frame = self.bounds
            blurEffectView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            backgroundView = blurEffectView
            separator.isHidden = true
        } else {
            imageSelect.image = NCBrandColor.cacheImages.checkedNo
            backgroundView = nil
            separator.isHidden = false
        }
    }
}

protocol NCTrashListCellDelegate: AnyObject {
    func tapRestoreListItem(with objectId: String, image: UIImage?, sender: Any)
    func tapMoreListItem(with objectId: String, image: UIImage?, sender: Any)
}
