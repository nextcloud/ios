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
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var imageItemBottom: NSLayoutConstraint!

    var objectId = ""
    var indexPath = IndexPath()
    private var user = ""

    weak var photoCellDelegate: NCPhotoCellDelegate?
    var namedButtonMore = ""

    var fileObjectId: String? {
        get { return objectId }
        set { objectId = newValue ?? "" }
    }
    var filePreviewImageView: UIImageView? {
        get { return imageItem }
        set { imageItem = newValue }
    }
    var filePreviewImageBottom: NSLayoutConstraint? {
        get { return imageItemBottom }
        set { imageItemBottom = newValue}
    }
    var fileUser: String? {
        get { return user }
        set { user = newValue ?? "" }
    }
    var fileTitleLabel: UILabel? {
        get { return labelTitle }
        set { labelTitle = newValue }
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
        imageSelect.image = NCImageCache.images.checkedYes

        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gestureRecognizer:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        self.addGestureRecognizer(longPressedGesture)
    }

    override func snapshotView(afterScreenUpdates afterUpdates: Bool) -> UIView? {
        return nil
    }

    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        photoCellDelegate?.longPressGridItem(with: objectId, indexPath: indexPath, gestureRecognizer: gestureRecognizer)
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
    func longPressGridItem(with objectId: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer)
}
