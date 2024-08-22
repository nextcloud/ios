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

class NCPhotoCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellProtocol {

    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!

    var ocId = ""
    var ocIdTransfer = ""
    var indexPath = IndexPath()
    private var user = ""

    weak var photoCellDelegate: NCPhotoCellDelegate?
    var namedButtonMore = ""

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
    var fileInfoLabel: UILabel? {
        get { return nil }
        set { }
    }
    var fileSubinfoLabel: UILabel? {
        get { return nil }
        set { }
    }
    var fileStatusImage: UIImageView? {
        get { return imageStatus }
        set { imageStatus = newValue }
    }
    var fileLocalImage: UIImageView? {
        get { return nil }
        set { }
    }
    var fileFavoriteImage: UIImageView? {
        get { return nil }
        set { }
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

        imageVisualEffect.clipsToBounds = true
        imageVisualEffect.alpha = 0.5

        imageSelect.isHidden = true
        imageSelect.image = NCImageCache.shared.getImageCheckedYes()

        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gestureRecognizer:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        self.addGestureRecognizer(longPressedGesture)
    }

    override func snapshotView(afterScreenUpdates afterUpdates: Bool) -> UIView? {
        return nil
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        photoCellDelegate?.tapMorePhotoItem(with: ocId, ocIdTransfer: ocIdTransfer, namedButtonMore: namedButtonMore, image: imageItem.image, indexPath: indexPath, sender: sender)
    }

    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        photoCellDelegate?.longPressPhotoItem(with: ocId, ocIdTransfer: ocIdTransfer, indexPath: indexPath, gestureRecognizer: gestureRecognizer)
    }

    fileprivate func setA11yActions() {
        let moreName = namedButtonMore == NCGlobal.shared.buttonMoreStop ? "_cancel_" : "_more_"

        self.accessibilityCustomActions = [
            UIAccessibilityCustomAction(
                name: NSLocalizedString(moreName, comment: ""),
                target: self,
                selector: #selector(touchUpInsideMore))
        ]
    }

    func setButtonMore(named: String, image: UIImage) {
        namedButtonMore = named
        buttonMore.setImage(image, for: .normal)
        setA11yActions()
    }

    func hideButtonMore(_ status: Bool) {
        buttonMore.isHidden = status
    }

    func selected(_ status: Bool, isEditMode: Bool) {
        if status {
            imageSelect.isHidden = false
            imageVisualEffect.isHidden = false
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
        }
    }

    func setAccessibility(label: String, value: String) {
        accessibilityLabel = label
        accessibilityValue = value
    }

    func setIconOutlines() {
        if imageStatus.image != nil {
            imageStatus.makeCircularBackground(withColor: .systemBackground)
        } else {
            imageStatus.backgroundColor = .clear
        }
    }
}

protocol NCPhotoCellDelegate: AnyObject {
    func tapMorePhotoItem(with ocId: String, ocIdTransfer: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any)
    func longPressPhotoItem(with objectId: String, ocIdTransfer: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer)
}
