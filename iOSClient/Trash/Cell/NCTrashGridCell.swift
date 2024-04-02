//
//  NCTrashGridCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/03/2024.
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

protocol NCTrashGridCellDelegate: AnyObject {
    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any)
}

class NCTrashGridCell: UICollectionViewCell, NCTrashCellProtocol {

    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var labelSubinfo: UILabel!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!

    weak var delegate: NCTrashGridCellDelegate?
    var objectId = ""
    var indexPath = IndexPath()
    var user = ""
    var namedButtonMore = ""

    override func awakeFromNib() {
        super.awakeFromNib()

        // use entire cell as accessibility element
        accessibilityHint = nil
        accessibilityLabel = nil
        accessibilityValue = nil
        isAccessibilityElement = true

        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true

        imageVisualEffect.layer.cornerRadius = 6
        imageVisualEffect.clipsToBounds = true
        imageVisualEffect.alpha = 0.5

        labelTitle.text = ""
        labelInfo.text = ""
        labelSubinfo.text = ""
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

    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreGridItem(with: objectId, namedButtonMore: namedButtonMore, image: imageItem.image, indexPath: indexPath, sender: sender)
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

    func selectMode(_ status: Bool) {
        if status {
            imageSelect.isHidden = false
            buttonMore.isHidden = true
            accessibilityCustomActions = nil
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
            buttonMore.isHidden = false
            setA11yActions()
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
            imageSelect.image = NCImageCache.images.checkedYes
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
}

// MARK: - Grid Layout

class NCTrashGridLayout: UICollectionViewFlowLayout {

    var heightLabelPlusButton: CGFloat = 60
    var marginLeftRight: CGFloat = 10
    var itemForLine: CGFloat = 3
    var itemWidthDefault: CGFloat = 140

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
