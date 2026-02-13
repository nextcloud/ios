// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

protocol NCPhotoCellDelegate: AnyObject {
    func onMenuIntent(with metadata: tableMetadata?)
    func openContextMenu(with metadata: tableMetadata?, button: UIButton, sender: Any)
}

class NCPhotoCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellProtocol {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!

    weak var delegate: NCPhotoCellDelegate?

    var metadata: tableMetadata? {
        didSet {
            delegate?.openContextMenu(with: metadata, button: buttonMore, sender: self) /* preconfigure UIMenu with each metadata */
        }
    }

    var previewImageView: UIImageView? {
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

        imageItem.image = nil
        imageSelect.isHidden = true
        imageSelect.image = NCImageCache.shared.getImageCheckedYes()
        imageStatus.image = nil
        imageVisualEffect.clipsToBounds = true
        imageVisualEffect.alpha = 0.5

        buttonMore.isHidden = true
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

    func hideButtonMore(_ status: Bool) {
       // buttonMore.isHidden = status NO MORE USED
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

extension NCCollectionViewCommon {
    // MARK: - LAYOUT PHOTO
    //
    func photoCell(cell: NCPhotoCell, indexPath: IndexPath, metadata: tableMetadata) -> NCPhotoCell {
        let width = UIScreen.main.bounds.width / CGFloat(self.numberOfColumns)
        let ext = global.getSizeExtension(column: self.numberOfColumns)

        cell.metadata = metadata
        // cell.hideButtonMore(true) NO MORE USED
        cell.hideImageStatus(true)

        // Image
        //
        if let image = NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
            cell.previewImageView?.image = image
            cell.previewImageView?.contentMode = .scaleAspectFill
        } else {
            if isPinchGestureActive || ext == global.previewExt512 || ext == global.previewExt1024 {
                cell.previewImageView?.image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase)
            }

            DispatchQueue.global(qos: .userInteractive).async {
                let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase)
                if let image {
                    self.imageCache.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: ext, cost: indexPath.row)
                    DispatchQueue.main.async {
                        cell.previewImageView?.image = image
                        cell.previewImageView?.contentMode = .scaleAspectFill
                    }
                } else {
                    DispatchQueue.main.async {
                        cell.previewImageView?.contentMode = .scaleAspectFit
                        if metadata.iconName.isEmpty {
                            cell.previewImageView?.image = NCImageCache.shared.getImageFile()
                        } else {
                            cell.previewImageView?.image = self.utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                        }
                    }
                }
            }
        }

        // Edit mode
        //
        if fileSelect.contains(metadata.ocId) {
            cell.selected(true, isEditMode: isEditMode)
        } else {
            cell.selected(false, isEditMode: isEditMode)
        }

        if width > 100 {
            cell.hideImageStatus(false)
        }

        return cell
    }
}
