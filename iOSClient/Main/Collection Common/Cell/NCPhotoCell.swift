// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCPhotoCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellMainProtocol {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!

    var metadata: tableMetadata?
    var previewImg: UIImageView? {
        get { return imageItem }
        set { imageItem = newValue }
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

        imageItem.image = nil

        imageVisualEffect.isHidden = false
        imageVisualEffect.effect = nil
        imageVisualEffect.alpha = 0
        imageVisualEffect.isUserInteractionEnabled = false
        imageVisualEffect.backgroundColor = UIColor.white.withAlphaComponent(0.2)
    }

    override func snapshotView(afterScreenUpdates afterUpdates: Bool) -> UIView? {
        return nil
    }

    func selected(_ status: Bool, isEditMode: Bool, color: UIColor) {
        imageVisualEffect.alpha = status ? 1 : 0
        imageSelect.alpha = status ? 1 : 0
        imageSelect.image = NCImageCache.shared.getImageCheckedYes(color: color)
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
        if isPinchGestureActive || ext == global.previewExt512 || ext == global.previewExt1024 {
            cell.previewImg?.image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase)
        }

        let ocId = metadata.ocId
        let etag = metadata.etag
        let userId = metadata.userId
        let urlBase = metadata.urlBase
        let iconName = metadata.iconName
        let account = metadata.account

        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak cell] in
            guard let self else {
                return
            }

            let image = self.utility.getImage(
                ocId: ocId,
                etag: etag,
                ext: ext,
                userId: userId,
                urlBase: urlBase
            )

            let fallbackImage: UIImage?

            if let image {
                fallbackImage = image
            } else if iconName.isEmpty {
                fallbackImage = NCImageCache.shared.getImageFile()
            } else {
                fallbackImage = self.utility.loadImage(
                    named: iconName,
                    useTypeIconFile: true,
                    account: account
                )
            }

            DispatchQueue.main.async {
                guard let cell,
                      cell.metadata?.ocId == ocId else {
                    return
                }

                cell.previewImg?.image = fallbackImage
                cell.previewImg?.contentMode = image == nil ? .scaleAspectFit : .scaleAspectFill
            }
        }

        // Edit mode
        //
        if fileSelect.contains(metadata.ocId) {
            cell.selected(true, isEditMode: isEditMode, color: NCBrandColor.shared.getElement(account: session.account))
        } else {
            cell.selected(false, isEditMode: isEditMode, color: NCBrandColor.shared.getElement(account: session.account))
        }

        return cell
    }
}
