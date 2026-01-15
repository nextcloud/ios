// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

protocol NCPhotoCellDelegate: AnyObject {
    func onMenuIntent(with ocId: String)
    func contextMenu(with ocId: String, button: UIButton, sender: Any)
}

class NCPhotoCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellProtocol {
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!

    var ocId = "" { didSet { delegate?.contextMenu(with: ocId, button: buttonMore, sender: self) /* preconfigure UIMenu with each ocId */ } }
    var ocIdTransfer = ""
    var user = ""

    weak var delegate: NCPhotoCellDelegate?

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
    var fileStatusImage: UIImageView? {
        get { return imageStatus }
        set { imageStatus = newValue }
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
            delegate?.onMenuIntent(with: ocId)
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
