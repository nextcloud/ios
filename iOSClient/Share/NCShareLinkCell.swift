// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Henrik Storch
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class NCShareLinkCell: UITableViewCell {
    @IBOutlet private weak var imageItem: UIImageView!
    @IBOutlet private weak var labelTitle: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!

    @IBOutlet weak var labelQuickStatus: UILabel!
    @IBOutlet weak var statusStackView: UIStackView!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet private weak var copyButton: UIButton!
    @IBOutlet weak var imageDownArrow: UIImageView!

    var tableShare: tableShare?
    var isDirectory = false
    weak var delegate: NCShareLinkCellDelegate?
    var isInternalLink = false
    var indexPath = IndexPath()
    let utility = NCUtility()

    override func prepareForReuse() {
        super.prepareForReuse()
        isInternalLink = false
        tableShare = nil
    }

    func setupCellUI(titleAppendString: String? = nil) {
        var menuImageName = "ellipsis"

        menuButton.isHidden = isInternalLink
        descriptionLabel.isHidden = !isInternalLink
        copyButton.isHidden = !isInternalLink && tableShare == nil
        statusStackView.isHidden = isInternalLink

        copyButton.setImage(UIImage(systemName: "doc.on.doc")?.withTintColor(.label, renderingMode: .alwaysOriginal), for: .normal)
        copyButton.accessibilityLabel = NSLocalizedString("_copy_", comment: "")

        menuButton.accessibilityLabel = NSLocalizedString("_more_", comment: "")
        menuButton.accessibilityIdentifier = "showShareLinkDetails"

        if isInternalLink {
            labelTitle.text = NSLocalizedString("_share_internal_link_", comment: "")
            descriptionLabel.text = NSLocalizedString("_share_internal_link_des_", comment: "")
            imageItem.image = NCUtility().loadImage(named: "square.and.arrow.up.circle.fill", colors: [NCBrandColor.shared.iconImageColor2])
        } else {
            labelTitle.text = NSLocalizedString("_share_link_", comment: "")

            if let titleAppendString {
                labelTitle.text?.append(" (\(titleAppendString))")
            }

            if let tableShare = tableShare {
                if !tableShare.label.isEmpty {
                    labelTitle.text? += " (\(tableShare.label))"
                }
            } else {
                menuImageName = "plus"
                menuButton.accessibilityLabel = NSLocalizedString("_add_", comment: "")
                menuButton.accessibilityIdentifier = "addShareLink"
            }

            imageItem.image = NCUtility().loadImage(named: "link.circle.fill", colors: [NCBrandColor.shared.getElement(account: tableShare?.account)])
            menuButton.setImage(NCUtility().loadImage(named: menuImageName, colors: [NCBrandColor.shared.iconImageColor]), for: .normal)
        }

        labelTitle.textColor = NCBrandColor.shared.textColor

        statusStackView.isHidden = true

        if let tableShare {
            statusStackView.isHidden = false
            labelQuickStatus.text = NSLocalizedString("_custom_permissions_", comment: "")

            if NCSharePermissions.canEdit(tableShare.permissions, isDirectory: isDirectory) { // Can edit
                labelQuickStatus.text = NSLocalizedString("_share_editing_", comment: "")
            }
            if NCSharePermissions.getPermissionValue(canRead: false, canCreate: true, canEdit: false, canDelete: false, canShare: false, isDirectory: isDirectory) == tableShare.permissions { // File request
                labelQuickStatus.text = NSLocalizedString("_share_file_drop_", comment: "")
            }
            if NCSharePermissions.getPermissionValue(canCreate: false, canEdit: false, canDelete: false, canShare: true, isDirectory: isDirectory) == tableShare.permissions { // Read only
                labelQuickStatus.text = NSLocalizedString("_share_read_only_", comment: "")
            }

            if tableShare.shareType == NKShare.ShareType.email.rawValue {
                labelTitle.text = tableShare.shareWithDisplayname
                imageItem.image = NCUtility().loadImage(named: "envelope.circle.fill", colors: [NCBrandColor.shared.getElement(account: tableShare.account)])
            }
        }

        statusStackView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openQuickStatus)))
        labelQuickStatus.textColor = NCBrandColor.shared.customer
        imageDownArrow.image = utility.loadImage(named: "arrowtriangle.down.circle", colors: [NCBrandColor.shared.customer])

        menuButton.menu = nil
        menuButton.showsMenuAsPrimaryAction = true
    }

    @IBAction func touchUpCopy(_ sender: Any) {
        delegate?.tapCopy(with: tableShare, sender: sender)
    }

    @IBAction func touchUpMenu(_ sender: Any) {
        delegate?.tapMenu(with: tableShare, sender: sender)
    }

    @objc func openQuickStatus(_ sender: UITapGestureRecognizer) {
        delegate?.tapQuickStatus(with: tableShare, sender: sender.view ?? sender)
    }
}

protocol NCShareLinkCellDelegate: AnyObject {
    func tapCopy(with tableShare: tableShare?, sender: Any)
    func tapMenu(with tableShare: tableShare?, sender: Any)
    func tapQuickStatus(with tableShare: tableShare?, sender: Any)
}
