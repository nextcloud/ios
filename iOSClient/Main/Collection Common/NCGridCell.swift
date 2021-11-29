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
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!
    @IBOutlet weak var progressView: UIProgressView!

    private var objectId = ""
    private var user = ""

    weak var delegate: NCGridCellDelegate?
    var namedButtonMore = ""

    var fileAvatarImageView: UIImageView? {
        get {
            return nil
        }
    }
    var fileObjectId: String? {
        get {
            return objectId
        }
        set {
            objectId = newValue ?? ""
        }
    }
    var filePreviewImageView: UIImageView? {
        get {
            return imageItem
        }
    }
    var fileUser: String? {
        get {
            return user
        }
        set {
            user = newValue ?? ""
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true

        imageVisualEffect.layer.cornerRadius = 6
        imageVisualEffect.clipsToBounds = true
        imageVisualEffect.alpha = 0.5

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
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageItem.backgroundColor = nil
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, image: imageItem.image, sender: sender)
    }

    @objc func longPressInsideMore(gestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.longPressMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, gestureRecognizer: gestureRecognizer)
    }

    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.longPressGridItem(with: objectId, gestureRecognizer: gestureRecognizer)
    }

    func setButtonMore(named: String, image: UIImage) {
        namedButtonMore = named
        buttonMore.setImage(image, for: .normal)
    }

    func hideButtonMore(_ status: Bool) {
        buttonMore.isHidden = status
    }

    func selectMode(_ status: Bool) {
        if status {
            imageSelect.isHidden = false
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
        }
    }

    func selected(_ status: Bool) {
        if status {
            if traitCollection.userInterfaceStyle == .dark {
                imageVisualEffect.effect = UIBlurEffect(style: .dark)
                imageVisualEffect.backgroundColor = .black
            } else {
                imageVisualEffect.effect = UIBlurEffect(style: .extraLight)
                imageVisualEffect.backgroundColor = .lightGray
            }
            imageSelect.image = NCBrandColor.cacheImages.checkedYes
            imageVisualEffect.isHidden = false
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
        }
    }
}

protocol NCGridCellDelegate: AnyObject {
    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any)
    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer)
    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer)
}

// optional func
extension NCGridCellDelegate {
    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any) {}
    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) {}
    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) {}
}

// MARK: - Grid Layout

class NCGridLayout: UICollectionViewFlowLayout {

    var heightLabelPlusButton: CGFloat = 45
    var marginLeftRight: CGFloat = 6
    var itemForLine: CGFloat = 3
    var itemWidthDefault: CGFloat = 120

    // MARK: - View Life Cycle

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
                    itemForLine = 3
                } else {
                    itemForLine = collectionView.frame.width / itemWidthDefault
                }

                let itemWidth: CGFloat = (collectionView.frame.width - marginLeftRight * 2 - marginLeftRight * (itemForLine - 1)) / itemForLine
                let itemHeight: CGFloat = itemWidth + heightLabelPlusButton

                return CGSize(width: itemWidth, height: itemHeight)
            }

            // Default fallback
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
