//
//  NCShareUserCell.swift
//  Nextcloud
//
//  Created by Henrik Storch on 15.11.2021.
//  Copyright © 2021 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

import UIKit
import DropDown
import NextcloudKit

class NCShareUserCell: UITableViewCell, NCCellProtocol {

    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var buttonMenu: UIButton!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var btnQuickStatus: UIButton!
    @IBOutlet weak var labelQuickStatus: UILabel!
    @IBOutlet weak var imageDownArrow: UIImageView!

    private var index = IndexPath()

    var tableShare: tableShare?
    var isDirectory = false
    let utility = NCUtility()
    weak var delegate: NCShareUserCellDelegate?

    var indexPath: IndexPath {
        get { return index }
        set { index = newValue }
    }
    var fileAvatarImageView: UIImageView? {
        return imageItem
    }
    var fileUser: String? {
        get { return tableShare?.shareWith }
        set {}
    }

    func setupCellUI(userId: String, session: NCSession.Session, metadata: tableMetadata) {
        guard let tableShare = tableShare else {
            return
        }
        self.accessibilityCustomActions = [UIAccessibilityCustomAction(
            name: NSLocalizedString("_show_profile_", comment: ""),
            target: self,
            selector: #selector(tapAvatarImage(_:)))]
        let permissions = NCPermissions()
        labelTitle.text = (tableShare.shareWithDisplayname.isEmpty ? tableShare.shareWith : tableShare.shareWithDisplayname)

        let type = getType(tableShare)
        if !type.isEmpty {
            labelTitle.text?.append(" (\(type))")
        }

        labelTitle.lineBreakMode = .byTruncatingMiddle
        labelTitle.textColor = NCBrandColor.shared.textColor
        isUserInteractionEnabled = true
        labelQuickStatus.isHidden = false
        imageDownArrow.isHidden = false
        buttonMenu.isHidden = false
        buttonMenu.accessibilityLabel = NSLocalizedString("_more_", comment: "")
        imageItem.image = NCShareCommon().getImageShareType(shareType: tableShare.shareType)

        let status = utility.getUserStatus(userIcon: tableShare.userIcon, userStatus: tableShare.userStatus, userMessage: tableShare.userMessage)
        imageStatus.image = status.statusImage
        self.status.text = status.statusMessage

        // If the initiator or the recipient is not the current user, show the list of sharees without any options to edit it.
        if tableShare.uidOwner != userId && tableShare.uidFileOwner != userId {
            isUserInteractionEnabled = false
            labelQuickStatus.isHidden = true
            imageDownArrow.isHidden = true
            buttonMenu.isHidden = true
        }

        btnQuickStatus.accessibilityHint = NSLocalizedString("_user_sharee_footer_", comment: "")
        btnQuickStatus.setTitle("", for: .normal)
        btnQuickStatus.contentHorizontalAlignment = .left

        if permissions.canEdit(tableShare.permissions, isDirectory: isDirectory) { // Can edit
            labelQuickStatus.text = NSLocalizedString("_share_editing_", comment: "")
        } else if tableShare.permissions == permissions.permissionReadShare { // Read only
            labelQuickStatus.text = NSLocalizedString("_share_read_only_", comment: "")
        } else { // Custom permissions
            labelQuickStatus.text = NSLocalizedString("_custom_permissions_", comment: "")
        }

        let fileName = NCSession.shared.getFileName(urlBase: session.urlBase, user: tableShare.shareWith)
        let results = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName)

        imageItem.contentMode = .scaleAspectFill

        if tableShare.shareType == NCShareCommon().SHARE_TYPE_CIRCLE {
            imageItem.image = utility.loadImage(named: "person.3.circle.fill", colors: [NCBrandColor.shared.iconImageColor])
        } else if results.image == nil {
            imageItem.image = utility.loadUserImage(for: tableShare.shareWith, displayName: tableShare.shareWithDisplayname, urlBase: metadata.urlBase)
        } else {
            imageItem.image = results.image
        }

        if !(results.tblAvatar?.loaded ?? false),
           NCNetworking.shared.downloadAvatarQueue.operations.filter({ ($0 as? NCOperationDownloadAvatar)?.fileName == fileName }).isEmpty {
            NCNetworking.shared.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: tableShare.shareWith, fileName: fileName, account: metadata.account, view: self))
        }
    }

    private func getType(_ tableShare: tableShareV2) -> String {
        switch tableShare.shareType {
        case NCShareCommon().SHARE_TYPE_FEDERATED:
            return NSLocalizedString("_remote_", comment: "")
        case NCShareCommon().SHARE_TYPE_ROOM:
            return NSLocalizedString("_conversation_", comment: "")
        default:
            return ""
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapAvatarImage(_:)))
        imageItem?.addGestureRecognizer(tapGesture)

        labelQuickStatus.textColor = NCBrandColor.shared.customer
        imageDownArrow.image = utility.loadImage(named: "arrowtriangle.down.circle", colors: [NCBrandColor.shared.customer])
    }

    @objc func tapAvatarImage(_ sender: UITapGestureRecognizer) {
        delegate?.showProfile(with: tableShare, sender: sender)
    }

    @IBAction func touchUpInsideMenu(_ sender: Any) {
        delegate?.tapMenu(with: tableShare, sender: sender)
    }

    @IBAction func quickStatusClicked(_ sender: Any) {
        delegate?.quickStatus(with: tableShare, sender: sender)
    }
}

protocol NCShareUserCellDelegate: AnyObject {
    func tapMenu(with tableShare: tableShare?, sender: Any)
    func showProfile(with tableComment: tableShare?, sender: Any)
    func quickStatus(with tableShare: tableShare?, sender: Any)
}

// MARK: - NCSearchUserDropDownCell

class NCSearchUserDropDownCell: DropDownCell, NCCellProtocol {

    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var imageShareeType: UIImageView!
    @IBOutlet weak var centerTitle: NSLayoutConstraint!

    private var user: String = ""
    private var index = IndexPath()

    var indexPath: IndexPath {
        get { return index }
        set { index = newValue }
    }
    var fileAvatarImageView: UIImageView? {
        return imageItem
    }
    var fileUser: String? {
        get { return user }
        set { user = newValue ?? "" }
    }

    func setupCell(sharee: NKSharee, session: NCSession.Session) {
        let utility = NCUtility()
        imageItem.image = NCShareCommon().getImageShareType(shareType: sharee.shareType)
        imageShareeType.image = NCShareCommon().getImageShareType(shareType: sharee.shareType)
        let status = utility.getUserStatus(userIcon: sharee.userIcon, userStatus: sharee.userStatus, userMessage: sharee.userMessage)

        if let statusImage = status.statusImage {
            imageStatus.image = statusImage
            imageStatus.makeCircularBackground(withColor: .systemBackground)
        }

        self.status.text = status.statusMessage
        if self.status.text?.count ?? 0 > 0 {
            centerTitle.constant = -5
        } else {
            centerTitle.constant = 0
        }

        imageItem.image = utility.loadUserImage(for: sharee.shareWith, displayName: nil, urlBase: session.urlBase)

        let fileName = NCSession.shared.getFileName(urlBase: session.urlBase, user: sharee.shareWith)
        let results = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName)

        if results.image == nil {
            let etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag

            NextcloudKit.shared.downloadAvatar(
                user: sharee.shareWith,
                fileNameLocalPath: NCUtilityFileSystem().directoryUserData + "/" + fileName,
                sizeImage: NCGlobal.shared.avatarSize,
                avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                etag: etag, account: session.account) { _, imageAvatar, _, etag, _, error in
                    if error == .success, let etag = etag, let imageAvatar = imageAvatar {
                        NCManageDatabase.shared.addAvatar(fileName: fileName, etag: etag)
                        self.imageItem.image = imageAvatar
                    } else if error.errorCode == NCGlobal.shared.errorNotModified, let imageAvatar = NCManageDatabase.shared.setAvatarLoaded(fileName: fileName) {
                        self.imageItem.image = imageAvatar
                    }
                }
        }
    }
}
