//
//  NCTrashListCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

protocol NCTrashListCellDelegate: AnyObject {
    func tapRestoreListItem(with objectId: String, image: UIImage?, sender: Any)
    func tapMoreListItem(with objectId: String, image: UIImage?, sender: Any)
}

class NCTrashListCell: UICollectionViewCell, NCTrashCellProtocol {
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
    var account = ""

    override func awakeFromNib() {
        super.awakeFromNib()
        initCell()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        initCell()
    }

    func initCell() {
        isAccessibilityElement = true

        self.accessibilityCustomActions = [
            UIAccessibilityCustomAction(
                name: NSLocalizedString("_restore_", comment: ""),
                target: self,
                selector: #selector(touchUpInsideRestore(_:))),
            UIAccessibilityCustomAction(
                name: NSLocalizedString("_delete_", comment: ""),
                target: self,
                selector: #selector(touchUpInsideMore(_:)))

        ]

        imageRestore.image = NCUtility().loadImage(named: "arrow.circlepath", colors: [NCBrandColor.shared.iconImageColor])
        imageMore.image = NCUtility().loadImage(named: "trash", colors: [.red])
        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true

        separator.backgroundColor = .separator
        separatorHeightConstraint.constant = 0.5
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreListItem(with: objectId, image: imageItem.image, sender: sender)
    }

    @IBAction func touchUpInsideRestore(_ sender: Any) {
        delegate?.tapRestoreListItem(with: objectId, image: imageItem.image, sender: sender)
    }

    func selected(_ status: Bool, isEditMode: Bool, account: String) {
        if isEditMode {
            imageItemLeftConstraint.constant = 45
            imageSelect.isHidden = false
            imageRestore.isHidden = true
            buttonRestore.isHidden = true
            imageMore.isHidden = true
            buttonMore.isHidden = true
        } else {
            imageItemLeftConstraint.constant = 10
            imageSelect.isHidden = true
            imageRestore.isHidden = false
            buttonRestore.isHidden = false
            imageMore.isHidden = false
            buttonMore.isHidden = false
            backgroundView = nil
        }
        if status {
            var blurEffectView: UIView?
            blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            blurEffectView?.backgroundColor = .lightGray
            blurEffectView?.frame = self.bounds
            blurEffectView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            imageSelect.image = NCImageCache.shared.getImageCheckedYes()
            backgroundView = blurEffectView
            separator.isHidden = true
        } else {
            imageSelect.image = NCImageCache.shared.getImageCheckedNo()
            backgroundView = nil
            separator.isHidden = false
        }

    }
}
