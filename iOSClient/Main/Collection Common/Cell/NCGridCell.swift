//
//  NCGridCell.swift
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

class NCGridCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellProtocol {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    @IBOutlet weak var imageLocal: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var labelSubinfo: UILabel!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!

    var ocId = ""
    var ocIdTransfer = ""
    var account = ""
    var user = ""

    weak var gridCellDelegate: NCGridCellDelegate?

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
    var fileTitleLabel: UILabel? {
        get { return labelTitle }
        set { labelTitle = newValue }
    }
    var fileInfoLabel: UILabel? {
        get { return labelInfo }
        set { labelInfo = newValue }
    }
    var fileSubinfoLabel: UILabel? {
        get { return labelSubinfo }
        set { labelSubinfo = newValue }
    }
    var fileStatusImage: UIImageView? {
        get { return imageStatus }
        set { imageStatus = newValue }
    }
    var fileLocalImage: UIImageView? {
        get { return imageLocal }
        set { imageLocal = newValue }
    }
    var fileFavoriteImage: UIImageView? {
        get { return imageFavorite }
        set { imageFavorite = newValue }
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
        isAccessibilityElement = true

        imageItem.image = nil
        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true
        imageSelect.isHidden = true
        imageSelect.image = NCImageCache.shared.getImageCheckedYes()
        imageStatus.image = nil
        imageFavorite.image = nil
        imageLocal.image = nil
        labelTitle.text = ""
        labelInfo.text = ""
        labelSubinfo.text = ""
        imageVisualEffect.layer.cornerRadius = 6
        imageVisualEffect.clipsToBounds = true
        imageVisualEffect.alpha = 0.5

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
        gridCellDelegate?.tapMoreGridItem(with: ocId, ocIdTransfer: ocIdTransfer, image: imageItem.image, sender: sender)
    }

    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        gridCellDelegate?.longPressGridItem(with: ocId, ocIdTransfer: ocIdTransfer, gestureRecognizer: gestureRecognizer)
    }

    fileprivate func setA11yActions() {
        self.accessibilityCustomActions = [
            UIAccessibilityCustomAction(
                name: NSLocalizedString("_more_", comment: ""),
                target: self,
                selector: #selector(touchUpInsideMore(_:)))
        ]
    }

    func setButtonMore(image: UIImage) {
        buttonMore.setImage(image, for: .normal)
        setA11yActions()
    }

    func hideImageItem(_ status: Bool) {
        imageItem.isHidden = status
    }

    func hideImageFavorite(_ status: Bool) {
        imageFavorite.isHidden = status
    }

    func hideImageStatus(_ status: Bool) {
        imageStatus.isHidden = status
    }

    func hideImageLocal(_ status: Bool) {
        imageLocal.isHidden = status
    }

    func hideLabelTitle(_ status: Bool) {
        labelTitle.isHidden = status
    }

    func hideLabelInfo(_ status: Bool) {
        labelInfo.isHidden = status
    }

    func hideLabelSubinfo(_ status: Bool) {
        labelSubinfo.isHidden = status
    }

    func hideButtonMore(_ status: Bool) {
        buttonMore.isHidden = status
    }

    func selected(_ status: Bool, isEditMode: Bool) {
        if isEditMode {
            buttonMore.isHidden = true
            accessibilityCustomActions = nil
        } else {
            buttonMore.isHidden = false
            setA11yActions()
        }
        if status {
            imageSelect.isHidden = false
            imageSelect.image = NCImageCache.shared.getImageCheckedYes()
            imageVisualEffect.isHidden = false
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
        }
    }

    func writeInfoDateSize(date: NSDate, size: Int64) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale.current

        labelInfo.text = dateFormatter.string(from: date as Date)
        labelSubinfo.text = NCUtilityFileSystem().transformedSize(size)
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

protocol NCGridCellDelegate: AnyObject {
    func tapMoreGridItem(with ocId: String, ocIdTransfer: String, image: UIImage?, sender: Any)
    func longPressGridItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer)
}

// MARK: - Grid Layout

class NCGridLayout: UICollectionViewFlowLayout {
    var heightLabelPlusButton: CGFloat = 60
    var marginLeftRight: CGFloat = 10
    var column: CGFloat = 3
    var itemWidthDefault: CGFloat = 140

    override init() {
        super.init()

        sectionHeadersPinToVisibleBounds = false

        minimumInteritemSpacing = 1
        minimumLineSpacing = marginLeftRight

        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 10, left: marginLeftRight, bottom: 0, right: marginLeftRight)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                if collectionView.frame.width < 400 {
                    column = 3
                } else {
                    column = collectionView.frame.width / itemWidthDefault
                }
                let itemWidth: CGFloat = (collectionView.frame.width - marginLeftRight * 2 - marginLeftRight * (column - 1)) / column
                let itemHeight: CGFloat = itemWidth + heightLabelPlusButton
                return CGSize(width: itemWidth, height: itemHeight)
            }
            return CGSize(width: itemWidthDefault, height: itemWidthDefault)
        }
        set {
            super.itemSize = newValue
        }
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}
