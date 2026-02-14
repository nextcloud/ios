// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

protocol NCGridCellDelegate: AnyObject {
    func onMenuIntent(with metadata: tableMetadata?)
    func openContextMenu(with metadata: tableMetadata?, button: UIButton, sender: Any)
}

class NCGridCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellMainProtocol {
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
    @IBOutlet weak var iconsStackView: UIStackView!

    weak var delegate: NCGridCellDelegate?

    // Cell Protocol
    var metadata: tableMetadata? {
        didSet {
            delegate?.openContextMenu(with: metadata, button: buttonMore, sender: self) /* preconfigure UIMenu with each metadata */
        }
    }
    var previewImage: UIImageView? {
        get { return imageItem }
        set { imageItem = newValue }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let tapObserver = UITapGestureRecognizer(target: self, action: #selector(handleTapObserver(_:)))
        tapObserver.cancelsTouchesInView = false
        tapObserver.delegate = self
        contentView.addGestureRecognizer(tapObserver)

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

        iconsStackView.addBlurBackground(style: .systemMaterial)
        iconsStackView.layer.cornerRadius = 8
        iconsStackView.clipsToBounds = true

        buttonMore.menu = nil
        buttonMore.showsMenuAsPrimaryAction = true

        contentView.bringSubviewToFront(buttonMore)
    }

    override func snapshotView(afterScreenUpdates afterUpdates: Bool) -> UIView? {
        return nil
    }

    @objc private func handleTapObserver(_ g: UITapGestureRecognizer) {
        let location = g.location(in: contentView)

        if buttonMore.frame.contains(location) {
            delegate?.onMenuIntent(with: metadata)
        }
    }

    func setButtonMore(image: UIImage) {
        buttonMore.setImage(image, for: .normal)
    }

    func setButtonMore(_ status: Bool) {
        buttonMore.isHidden = status
    }

    func selected(_ status: Bool, isEditMode: Bool) {
        if isEditMode {
            buttonMore.isHidden = true
            accessibilityCustomActions = nil
        } else {
            buttonMore.isHidden = false
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

extension NCCollectionViewCommon {
    func gridCell(cell: NCGridCell, indexPath: IndexPath, metadata: tableMetadata) -> NCGridCell {
        var isShare = false
        var isMounted = false
        var a11yValues: [String] = []
        let existsImagePreview = utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag, userId: metadata.userId, urlBase: metadata.urlBase)

        // CONTENT MODE
        cell.previewImage?.layer.borderWidth = 0

        if existsImagePreview && layoutForView?.layout != global.layoutPhotoRatio {
            cell.previewImage?.contentMode = .scaleAspectFill
        } else {
            cell.previewImage?.contentMode = .scaleAspectFit
        }

        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else {
            return cell
        }

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(NCMetadataPermissions.permissionShared) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionShared)
            isMounted = metadata.permissions.contains(NCMetadataPermissions.permissionMounted) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionMounted)
        }

        if !metadata.sessionError.isEmpty, metadata.status != global.metadataStatusNormal {
            cell.labelSubinfo.isHidden = false
            cell.labelInfo.text = metadata.sessionError
        } else {
            cell.labelSubinfo.isHidden = false
            cell.writeInfoDateSize(date: metadata.date, size: metadata.size)
        }

        cell.labelTitle.text = metadata.fileNameView

        // Accessibility [shared] if metadata.ownerId != appDelegate.userId, appDelegate.account == metadata.account {
        if metadata.ownerId != metadata.userId {
            a11yValues.append(NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName)
        }

        if metadata.directory {
            cellMainDirectory(cell: cell, metadata: metadata, isShare: isShare, isMounted: isMounted)
        } else {
            cellMainFile(cell: cell, metadata: metadata, a11yValues: &a11yValues)
        }

        // image Favorite
        if metadata.favorite {
            cell.imageFavorite.image = imageCache.getImageFavorite()
            a11yValues.append(NSLocalizedString("_favorite_short_", comment: ""))
        }

        // Button More
        if metadata.lock == true {
            cell.setButtonMore(image: imageCache.getImageButtonMoreLock())
            a11yValues.append(String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName))
        } else {
            cell.setButtonMore(image: imageCache.getImageButtonMore())
        }

        // Status
        cellMainStatus(cell: cell, metadata: metadata, a11yValues: &a11yValues)

        // URL
        if metadata.classFile == NKTypeClassFile.url.rawValue {
            cell.imageLocal.image = nil
        }

        // Edit mode
        if fileSelect.contains(metadata.ocId) {
            cell.selected(true, isEditMode: isEditMode)
            a11yValues.append(NSLocalizedString("_selected_", comment: ""))
        } else {
            cell.selected(false, isEditMode: isEditMode)
        }

        // Accessibility
        cell.setAccessibility(label: metadata.fileNameView + ", " + (cell.labelInfo.text ?? "") + (cell.labelSubinfo.text ?? ""), value: a11yValues.joined(separator: ", "))

        // Color string find in search
        cell.labelTitle.textColor = NCBrandColor.shared.textColor
        cell.labelTitle.font = .systemFont(ofSize: 15)

        // Obligatory here, at the end !!
        cell.metadata = metadata

        return cell
    }
}
