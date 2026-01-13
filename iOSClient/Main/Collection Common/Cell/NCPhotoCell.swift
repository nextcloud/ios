//
//  NCPhotoCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/07/2024.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

protocol NCPhotoCellDelegate: AnyObject {
    func contextMenu(with ocId: String, button: UIButton, sender: Any)
}

class NCPhotoCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellProtocol {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!

    var ocId = "" { didSet { photoCellDelegate?.contextMenu(with: ocId, button: buttonMore, sender: self) /* preconfigure UIMenu with each ocId */ } }
    var ocIdTransfer = ""
    var user = ""

    weak var photoCellDelegate: NCPhotoCellDelegate?

    var fileOcId: String? {
        get { return ocId }
        set { ocId = newValue ?? "" }
    }
    var fileOcIdTransfer: String? {
        get { return ocIdTransfer }
        set { ocIdTransfer = newValue ?? "" }
    }
    var filePreviewImageView: UIImageView? {
        get { return imageItem }
        set { imageItem = newValue }
    }
    var fileUser: String? {
        get { return user }
        set { user = newValue ?? "" }
    }
    var fileStatusImage: UIImageView? {
        get { return imageStatus }
        set { imageStatus = newValue }
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
        accessibilityHint = nil
        accessibilityLabel = nil
        accessibilityValue = nil

        imageItem.image = nil
        imageSelect.isHidden = true
        imageSelect.image = NCImageCache.shared.getImageCheckedYes()
        imageStatus.image = nil
        imageVisualEffect.clipsToBounds = true
        imageVisualEffect.alpha = 0.5

        contentView.bringSubviewToFront(buttonMore)

        buttonMore.menu = nil
        buttonMore.showsMenuAsPrimaryAction = true
    }

    override func snapshotView(afterScreenUpdates afterUpdates: Bool) -> UIView? {
        return nil
    }

    func setButtonMore(image: UIImage) {
        buttonMore.setImage(image, for: .normal)
    }

    func hideButtonMore(_ status: Bool) {
        buttonMore.isHidden = status
    }

    func hideImageStatus(_ status: Bool) {
        imageStatus.isHidden = status
    }

    func selected(_ status: Bool, isEditMode: Bool) {
        if status {
            imageSelect.isHidden = false
            imageVisualEffect.isHidden = false
            imageSelect.image = NCImageCache.shared.getImageCheckedYes()
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
        }
    }

    func setAccessibility(label: String, value: String) {
        accessibilityLabel = label
        accessibilityValue = value
    }
}
