// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCPhotoCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellProtocol {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!

    // Cell Protocol
    var metadata: tableMetadata?
    var previewImage: UIImageView? {
        get { return imageItem }
        set { imageItem = newValue }
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
        imageVisualEffect.clipsToBounds = true
        imageVisualEffect.alpha = 0.5
    }

    override func snapshotView(afterScreenUpdates afterUpdates: Bool) -> UIView? {
        return nil
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
        let ext = global.getSizeExtension(column: self.numberOfColumns)

        cell.metadata = metadata

        // Image
        //
        if let image = NCImageCache.shared.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
            cell.previewImage?.image = image
            cell.previewImage?.contentMode = .scaleAspectFill
        } else {
            if isPinchGestureActive || ext == global.previewExt512 || ext == global.previewExt1024 {
                cell.previewImage?.image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase)
            }

            DispatchQueue.global(qos: .userInteractive).async {
                let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase)
                if let image {
                    self.imageCache.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: ext, cost: indexPath.row)
                    DispatchQueue.main.async {
                        cell.previewImage?.image = image
                        cell.previewImage?.contentMode = .scaleAspectFill
                    }
                } else {
                    DispatchQueue.main.async {
                        cell.previewImage?.contentMode = .scaleAspectFit
                        if metadata.iconName.isEmpty {
                            cell.previewImage?.image = NCImageCache.shared.getImageFile()
                        } else {
                            cell.previewImage?.image = self.utility.loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
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

        return cell
    }
}
