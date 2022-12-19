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
    @IBOutlet weak var imageLocal: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var imageShared: UIImageView!
    @IBOutlet weak var buttonShared: UIButton!
    @IBOutlet weak var imageMore: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var separator: UIView!

    @IBOutlet weak var imageItemLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoTrailingConstraint: NSLayoutConstraint!

    private var objectId = ""
    private var user = ""

    weak var delegate: NCListCellDelegate?
    var namedButtonMore = ""

    var fileAvatarImageView: UIImageView? {
        get { return imageShared }
    }
    var fileObjectId: String? {
        get { return objectId }
        set { objectId = newValue ?? "" }
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
    var fileProgressView: UIProgressView? {
        get { return progressView }
        set { progressView = newValue }
    }
    var fileSelectImage: UIImageView? {
        get { return imageSelect }
        set { imageSelect = newValue }
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
 
    override func awakeFromNib() {
        super.awakeFromNib()

        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true

        // use entire cell as accessibility element
        accessibilityHint = nil
        accessibilityLabel = nil
        accessibilityValue = nil
        isAccessibilityElement = true

        progressView.tintColor = NCBrandColor.shared.brandElement
        progressView.transform = CGAffineTransform(scaleX: 1.0, y: 0.5)
        progressView.trackTintColor = .clear

        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gestureRecognizer:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        self.addGestureRecognizer(longPressedGesture)

        let longPressedGestureMore = UILongPressGestureRecognizer(target: self, action: #selector(longPressInsideMore(gestureRecognizer:)))
        longPressedGestureMore.minimumPressDuration = 0.5
        longPressedGestureMore.delegate = self
        longPressedGestureMore.delaysTouchesBegan = true
        buttonMore.addGestureRecognizer(longPressedGestureMore)

        separator.backgroundColor = .separator
        separatorHeightConstraint.constant = 0.5

        labelTitle.text = ""
        labelInfo.text = ""
        labelTitle.textColor = .label
        labelInfo.textColor = .systemGray
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageItem.backgroundColor = nil
        accessibilityHint = nil
        accessibilityLabel = nil
        accessibilityValue = nil
    }

    override func snapshotView(afterScreenUpdates afterUpdates: Bool) -> UIView? {
        return nil
    }
    
    @IBAction func touchUpInsideShare(_ sender: Any) {
        delegate?.tapShareListItem(with: objectId, sender: sender)
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreListItem(with: objectId, namedButtonMore: namedButtonMore, image: imageItem.image, sender: sender)
    }

    @objc func longPressInsideMore(gestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.longPressMoreListItem(with: objectId, namedButtonMore: namedButtonMore, gestureRecognizer: gestureRecognizer)
    }

    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.longPressListItem(with: objectId, gestureRecognizer: gestureRecognizer)
    }

    fileprivate func setA11yActions() {
        let moreName = namedButtonMore == NCGlobal.shared.buttonMoreStop ? "_cancel_" : "_more_"
        self.accessibilityCustomActions = [
            UIAccessibilityCustomAction(
                name: NSLocalizedString("_share_", comment: ""),
                target: self,
                selector: #selector(touchUpInsideShare)),
            UIAccessibilityCustomAction(
                name: NSLocalizedString(moreName, comment: ""),
                target: self,
                selector: #selector(touchUpInsideMore))
        ]
    }

    func titleInfoTrailingFull() {
        titleTrailingConstraint.constant = 10
        infoTrailingConstraint.constant = 10
    }

    func titleInfoTrailingDefault() {
        titleTrailingConstraint.constant = 90
        infoTrailingConstraint.constant = 90
    }
    
    func setButtonMore(named: String, image: UIImage) {
        namedButtonMore = named
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

    func hideSeparator(_ status: Bool) {
        separator.isHidden = status
    }

    func selectMode(_ status: Bool) {
        if status {
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
    }

    func selected(_ status: Bool) {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(objectId), !metadata.isDownloadUpload else {
            backgroundView = nil
            separator.isHidden = false
            return
        }
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

    func writeInfoDateSize(date: NSDate, size: Int64) {
        labelInfo.text = CCUtility.dateDiff(date as Date) + " · " + CCUtility.transformedSize(size)
    }

    func setAccessibility(label: String, value: String) {
        accessibilityLabel = label
        accessibilityValue = value
    }
}

protocol NCListCellDelegate: AnyObject {
    func tapShareListItem(with objectId: String, sender: Any)
    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any)
    func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer)
    func longPressListItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer)
}

// optional func
extension NCListCellDelegate {
    func tapShareListItem(with objectId: String, sender: Any) {}
    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {}
    func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {}
    func longPressListItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {}
}

// MARK: - List Layout

class NCListLayout: UICollectionViewFlowLayout {

    var itemHeight: CGFloat = 60

    // MARK: - View Life Cycle

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

            // Default fallback
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
