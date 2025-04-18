//
//  NCListCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/10/2018.
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

class NCListCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellProtocol {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var imageFavorite: UIImageView!
    @IBOutlet weak var imageFavoriteBackground: UIImageView!
    @IBOutlet weak var imageLocal: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var labelInfoSeparator: UILabel!
    @IBOutlet weak var labelSubinfo: UILabel!
    @IBOutlet weak var imageShared: UIImageView!
    @IBOutlet weak var buttonShared: UIButton!
    @IBOutlet weak var imageMore: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var tag0: UILabel!
    @IBOutlet weak var tag1: UILabel!

    @IBOutlet weak var imageItemLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleTrailingConstraint: NSLayoutConstraint!

    var ocId = ""
    var ocIdTransfer = ""
    var user = ""

    weak var listCellDelegate: NCListCellDelegate?

    var fileAvatarImageView: UIImageView? {
        return imageShared
    }
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
    var fileSharedImage: UIImageView? {
        get { return imageShared }
        set { imageShared = newValue }
    }
    var fileMoreImage: UIImageView? {
        get { return imageMore }
        set { imageMore = newValue }
    }
    var cellSeparatorView: UIView? {
        get { return separator }
        set { separator = newValue }
    }

    override var accessibilityIdentifier: String? {
        get {
            super.accessibilityIdentifier
        }
        set {
            super.accessibilityIdentifier = newValue

            if let newValue {
                buttonShared.accessibilityIdentifier = "\(newValue)/shareButton"
            }
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
        accessibilityHint = nil
        accessibilityLabel = nil
        accessibilityValue = nil
        isAccessibilityElement = true

        imageItem.image = nil
        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true
        imageStatus.image = nil
        imageFavorite.image = nil
        imageFavoriteBackground.isHidden = true
        imageLocal.image = nil
        labelTitle.text = ""
        labelInfo.text = ""
        labelSubinfo.text = ""
        imageShared.image = nil
        imageMore.image = nil
        separatorHeightConstraint.constant = 0.5
        tag0.text = ""
        tag1.text = ""
        titleInfoTrailingDefault()

        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gestureRecognizer:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        self.addGestureRecognizer(longPressedGesture)
    }

    override func snapshotView(afterScreenUpdates afterUpdates: Bool) -> UIView? {
        return nil
    }

    @IBAction func touchUpInsideShare(_ sender: Any) {
        listCellDelegate?.tapShareListItem(with: ocId, ocIdTransfer: ocIdTransfer, sender: sender)
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        listCellDelegate?.tapMoreListItem(with: ocId, ocIdTransfer: ocIdTransfer, image: imageItem.image, sender: sender)
    }

    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        listCellDelegate?.longPressListItem(with: ocId, ocIdTransfer: ocIdTransfer, gestureRecognizer: gestureRecognizer)
    }

    fileprivate func setA11yActions() {
        self.accessibilityCustomActions = [
            UIAccessibilityCustomAction(
                name: NSLocalizedString("_share_", comment: ""),
                target: self,
                selector: #selector(touchUpInsideShare(_:))),
            UIAccessibilityCustomAction(
                name: NSLocalizedString("_more_", comment: ""),
                target: self,
                selector: #selector(touchUpInsideMore(_:)))
        ]
    }

    func titleInfoTrailingFull() {
        titleTrailingConstraint.constant = 10
    }

    func titleInfoTrailingDefault() {
        titleTrailingConstraint.constant = 90
    }

    func setButtonMore(image: UIImage) {
        imageMore.image = image
        setA11yActions()
    }

    func hideButtonMore(_ status: Bool) {
        imageMore.isHidden = status
        buttonMore.isHidden = status
    }

    func hideButtonShare(_ status: Bool) {
        imageShared.isHidden = status
        buttonShared.isHidden = status
    }

    func selected(_ status: Bool, isEditMode: Bool) {
        if isEditMode {
            imageItemLeftConstraint.constant = 45
            imageSelect.isHidden = false
            imageShared.isHidden = true
            imageMore.isHidden = true
            buttonShared.isHidden = true
            buttonMore.isHidden = true
            accessibilityCustomActions = nil
        } else {
            imageItemLeftConstraint.constant = 10
            imageSelect.isHidden = true
            imageShared.isHidden = false
            imageMore.isHidden = false
            buttonShared.isHidden = false
            buttonMore.isHidden = false
            backgroundView = nil
            setA11yActions()
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

    func writeInfoDateSize(date: NSDate, size: Int64) {
        labelInfo.text = NCUtility().getRelativeDateTitle(date as Date)
        labelSubinfo.text = NCUtilityFileSystem().transformedSize(size)
    }

    func setAccessibility(label: String, value: String) {
        accessibilityLabel = label
        accessibilityValue = value
    }

    func setTags(tags: [String]) {
        if tags.isEmpty {
            tag0.isHidden = true
            tag1.isHidden = true
            labelInfo.isHidden = false
            labelSubinfo.isHidden = false
        } else {
            tag0.isHidden = false
            tag1.isHidden = true
            labelInfo.isHidden = true
            labelSubinfo.isHidden = true

            if let tag = tags.first {
                tag0.text = tag
                if tags.count > 1 {
                    tag1.isHidden = false
                    tag1.text = "+\(tags.count - 1)"
                }
            }
        }
    }

    func setIconOutlines() {
        imageFavoriteBackground.isHidden = fileFavoriteImage?.image == nil

        if imageStatus.image != nil {
            imageStatus.makeCircularBackground(withColor: .systemBackground)
        } else {
            imageStatus.backgroundColor = .clear
        }

        if imageLocal.image != nil {
            imageLocal.makeCircularBackground(withColor: .systemBackground)
        } else {
            imageLocal.backgroundColor = .clear
        }
    }
}

protocol NCListCellDelegate: AnyObject {
    func tapShareListItem(with ocId: String, ocIdTransfer: String, sender: Any)
    func tapMoreListItem(with ocId: String, ocIdTransfer: String, image: UIImage?, sender: Any)
    func longPressListItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer)
}

// MARK: - List Layout

class NCListLayout: UICollectionViewFlowLayout {
    var itemHeight: CGFloat = 60

    override init() {
        super.init()

        sectionHeadersPinToVisibleBounds = false

        minimumInteritemSpacing = 0
        minimumLineSpacing = 1

        self.scrollDirection = .vertical
        self.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                let itemWidth: CGFloat = collectionView.frame.width
                return CGSize(width: itemWidth, height: self.itemHeight)
            }
            return CGSize(width: 100, height: 100)
        }
        set {
            super.itemSize = newValue
        }
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
}
