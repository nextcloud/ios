//
//  NCShare.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/07/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
//

import UIKit
import Parchment
import DropDown
import NCCommunication
import MarqueeLabel

class NCShare: UIViewController, UIGestureRecognizerDelegate, NCShareNetworkingDelegate {

    @IBOutlet weak var viewContainerConstraint: NSLayoutConstraint!
    @IBOutlet weak var sharedWithYouByView: UIView!
    @IBOutlet weak var sharedWithYouByImage: UIImageView!
    @IBOutlet weak var sharedWithYouByLabel: UILabel!
    @IBOutlet weak var sharedWithYouByNoteImage: UIImageView!
    @IBOutlet weak var sharedWithYouByNote: MarqueeLabel!
    @IBOutlet weak var searchFieldTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchField: UITextField!
    @IBOutlet weak var shareLinkImage: UIImageView!
    @IBOutlet weak var shareLinkLabel: UILabel!
    @IBOutlet weak var shareInternalLinkImage: UIImageView!
    @IBOutlet weak var shareInternalLinkLabel: UILabel!
    @IBOutlet weak var shareInternalLinkDescription: UILabel!
    @IBOutlet weak var buttonInternalCopy: UIButton!
    @IBOutlet weak var buttonCopy: UIButton!
    @IBOutlet weak var buttonMenu: UIButton!
    @IBOutlet weak var tableView: UITableView!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    public var metadata: tableMetadata?
    public var sharingEnabled = true
    public var height: CGFloat = 0

    private var shareLinkMenuView: NCShareLinkMenuView?
    private var shareUserMenuView: NCShareUserMenuView?
    private var shareMenuViewWindow: UIView?
    private var dropDown = DropDown()
    private var networking: NCShareNetworking?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = NCBrandColor.shared.systemBackground

        viewContainerConstraint.constant = height
        searchFieldTopConstraint.constant = 10

        searchField.placeholder = NSLocalizedString("_shareLinksearch_placeholder_", comment: "")

        shareLinkImage.image = NCShareCommon.shared.createLinkAvatar(imageName: "sharebylink", colorCircle: NCBrandColor.shared.brandElement)
        shareLinkLabel.text = NSLocalizedString("_share_link_", comment: "")
        shareLinkLabel.textColor = NCBrandColor.shared.label
        buttonCopy.setImage(UIImage(named: "shareCopy")?.image(color: .gray, size: 50), for: .normal)

        shareInternalLinkImage.image = NCShareCommon.shared.createLinkAvatar(imageName: "shareInternalLink", colorCircle: .gray)
        shareInternalLinkLabel.text = NSLocalizedString("_share_internal_link_", comment: "")
        shareInternalLinkDescription.text = NSLocalizedString("_share_internal_link_des_", comment: "")
        buttonInternalCopy.setImage(UIImage(named: "shareCopy")?.image(color: .gray, size: 50), for: .normal)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.backgroundColor = NCBrandColor.shared.systemBackground

        tableView.register(UINib(nibName: "NCShareLinkCell", bundle: nil), forCellReuseIdentifier: "cellLink")
        tableView.register(UINib(nibName: "NCShareUserCell", bundle: nil), forCellReuseIdentifier: "cellUser")

        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataNCShare), object: nil)

        // Shared with you by ...
        if let metadata = metadata, !metadata.ownerId.isEmpty, metadata.ownerId != self.appDelegate.userId {

            searchFieldTopConstraint.constant = 65
            sharedWithYouByView.isHidden = false
            sharedWithYouByLabel.text = NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName
            sharedWithYouByImage.image = NCUtility.shared.loadUserImage(
                for: metadata.ownerId,
                   displayName: metadata.ownerDisplayName,
                   userBaseUrl: appDelegate)
            let shareAction = UITapGestureRecognizer(target: self, action: #selector(openShareProfile))
            sharedWithYouByImage.addGestureRecognizer(shareAction)
            let shareLabelAction = UITapGestureRecognizer(target: self, action: #selector(openShareProfile))
            sharedWithYouByLabel.addGestureRecognizer(shareLabelAction)

            if metadata.note.count > 0 {
                searchFieldTopConstraint.constant = 95
                sharedWithYouByNoteImage.isHidden = false
                sharedWithYouByNoteImage.image = NCUtility.shared.loadImage(named: "note.text", color: .gray)
                sharedWithYouByNote.isHidden = false
                sharedWithYouByNote.text = metadata.note
                sharedWithYouByNote.textColor = NCBrandColor.shared.label
                sharedWithYouByNote.trailingBuffer = sharedWithYouByNote.frame.width
            } else {
                sharedWithYouByNoteImage.isHidden = true
                sharedWithYouByNote.isHidden = true
            }

            let fileName = appDelegate.userBaseUrl + "-" + metadata.ownerId + ".png"

            if NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) == nil {
                let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName
                let etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag

                NCCommunication.shared.downloadAvatar(user: metadata.ownerId, fileNameLocalPath: fileNameLocalPath, sizeImage: NCGlobal.shared.avatarSize, avatarSizeRounded: NCGlobal.shared.avatarSizeRounded, etag: etag) { _, imageAvatar, _, etag, errorCode, _ in

                    if errorCode == 0, let etag = etag, let imageAvatar = imageAvatar {

                        NCManageDatabase.shared.addAvatar(fileName: fileName, etag: etag)
                        self.sharedWithYouByImage.image = imageAvatar

                    } else if errorCode == NCGlobal.shared.errorNotModified, let imageAvatar = NCManageDatabase.shared.setAvatarLoaded(fileName: fileName) {

                        self.sharedWithYouByImage.image = imageAvatar
                    }
                }
            }
        }

        reloadData()

        networking = NCShareNetworking(metadata: metadata!, urlBase: appDelegate.urlBase, view: self.view, delegate: self)
        if sharingEnabled {
            let isVisible = (self.navigationController?.topViewController as? NCSharePaging)?.indexPage == .sharing
            networking?.readShare(showLoadingIndicator: isVisible)
        }

        // changeTheming
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changePermissions(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterShareChangePermissions), object: nil)

        changeTheming()
    }

    // MARK: - Notification Center

    @objc func openShareProfile() {
        guard let metadata = metadata else { return }
        self.showProfileMenu(userId: metadata.ownerId)
    }

    @objc func changeTheming() {
        tableView.reloadData()
    }

    @objc func changePermissions(_ notification: NSNotification) {

        if let userInfo = notification.userInfo as NSDictionary? {
            if let idShare = userInfo["idShare"] as? Int, let permissions = userInfo["permissions"] as? Int, let hideDownload = userInfo["hideDownload"] as? Bool {
                networking?.updateShare(idShare: idShare, password: nil, permissions: permissions, note: nil, label: nil, expirationDate: nil, hideDownload: hideDownload)
            }
        }
    }

    // MARK: -

    @objc func reloadData() {
        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata!)
        if shares.firstShareLink == nil {
            buttonMenu.setImage(UIImage(named: "shareAdd")?.image(color: .gray, size: 50), for: .normal)
            buttonCopy.isHidden = true
        } else {
            buttonMenu.setImage(UIImage(named: "shareMenu")?.image(color: .gray, size: 50), for: .normal)
            buttonCopy.isHidden = false

            shareLinkLabel.text = NSLocalizedString("_share_link_", comment: "")
            if shares.firstShareLink?.label.count ?? 0 > 0 {
                if let shareLinkLabel = shareLinkLabel {
                    if let label = shares.firstShareLink?.label {
                        shareLinkLabel.text = NSLocalizedString("_share_link_", comment: "") + " (" + label + ")"
                    }
                }
            }
        }
        tableView.reloadData()
    }

    // MARK: - IBAction

    @IBAction func searchFieldDidEndOnExit(textField: UITextField) {

        guard let searchString = textField.text else { return }

        networking?.getSharees(searchString: searchString)
    }

    @IBAction func touchUpInsideButtonCopy(_ sender: Any) {

        guard let metadata = self.metadata else { return }

        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata)
        tapCopy(with: shares.firstShareLink, sender: sender)
    }

    @IBAction func touchUpInsideButtonCopyInernalLink(_ sender: Any) {

        guard let metadata = self.metadata else { return }

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, account: metadata.account, queue: .main) { _, metadata, errorCode, errorDescription in
            if errorCode == 0 && metadata != nil {
                let internalLink = self.appDelegate.urlBase + "/index.php/f/" + metadata!.fileId
                NCShareCommon.shared.copyLink(link: internalLink, viewController: self, sender: sender)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }

    func checkEnforcedPassword(callback: @escaping (String?) -> Void) {
        guard let metadata = self.metadata,
              NCManageDatabase.shared.getCapabilitiesServerBool(account: metadata.account, elements: NCElementsJSON.shared.capabilitiesFileSharingPubPasswdEnforced, exists: false)
        else { return callback(nil) }

        let alertController = UIAlertController(title: NSLocalizedString("_enforce_password_protection_", comment: ""), message: "", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.isSecureTextEntry = true
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { _ in })
        let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { _ in
            let password = alertController.textFields?.first?.text
            callback(password)
        }

        alertController.addAction(okAction)

        self.present(alertController, animated: true, completion:nil)
    }
    
    @IBAction func touchUpInsideButtonMenu(_ sender: Any) {

        guard let metadata = self.metadata else { return }
        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata)

        if shares.firstShareLink == nil {
            checkEnforcedPassword { password in
                self.networking?.createShareLink(password: password)
            }
        } else {
            tapMenu(with: shares.firstShareLink!, sender: sender)
        }
    }

    @objc func tapLinkMenuViewWindow(gesture: UITapGestureRecognizer) {
        shareLinkMenuView?.unLoad()
        shareLinkMenuView = nil
        shareUserMenuView?.unLoad()
        shareUserMenuView = nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return gestureRecognizer.view == touch.view
    }

    // MARK: - NCShareNetworkingDelegate

    func readShareCompleted() {
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
    }

    func shareCompleted() {
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
    }

    func unShareCompleted() { }

    func updateShareWithError(idShare: Int) {
        self.reloadData()
    }

    func getSharees(sharees: [NCCommunicationSharee]?) {

        guard let sharees = sharees else { return }

        dropDown = DropDown()
        let appearance = DropDown.appearance()

        appearance.backgroundColor = NCBrandColor.shared.systemBackground
        appearance.cornerRadius = 10
        appearance.shadowColor = UIColor(white: 0.5, alpha: 1)
        appearance.shadowOpacity = 0.9
        appearance.shadowRadius = 25
        appearance.animationduration = 0.25
        appearance.textColor = .darkGray
        appearance.setupMaskedCorners([.layerMaxXMaxYCorner, .layerMinXMaxYCorner])

        for sharee in sharees {
            var label = sharee.label
            if sharee.shareType == NCShareCommon.shared.SHARE_TYPE_CIRCLE {
                label += " (" + sharee.circleInfo + ", " +  sharee.circleOwner + ")"
            }
            dropDown.dataSource.append(label)
        }

        dropDown.anchorView = searchField
        dropDown.bottomOffset = CGPoint(x: 0, y: searchField.bounds.height)
        dropDown.width = searchField.bounds.width
        dropDown.direction = .bottom

        dropDown.cellNib = UINib(nibName: "NCShareUserDropDownCell", bundle: nil)
        dropDown.customCellConfiguration = { (index: Index, _: String, cell: DropDownCell) -> Void in
            guard let cell = cell as? NCShareUserDropDownCell else { return }
            let sharee = sharees[index]
            cell.imageItem.image = NCShareCommon.shared.getImageShareType(shareType: sharee.shareType)
            cell.imageShareeType.image = NCShareCommon.shared.getImageShareType(shareType: sharee.shareType)
            let status = NCUtility.shared.getUserStatus(userIcon: sharee.userIcon, userStatus: sharee.userStatus, userMessage: sharee.userMessage)
            cell.imageStatus.image = status.onlineStatus
            cell.status.text = status.statusMessage
            if cell.status.text?.count ?? 0 > 0 {
                cell.centerTitle.constant = -5
            } else {
                cell.centerTitle.constant = 0
            }

            cell.imageItem.image = NCUtility.shared.loadUserImage(
                for: sharee.shareWith,
                   displayName: nil,
                   userBaseUrl: self.appDelegate)

            let fileName = self.appDelegate.userBaseUrl + "-" + sharee.shareWith + ".png"
            if NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) == nil {
                let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName
                let etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag

                NCCommunication.shared.downloadAvatar(user: sharee.shareWith, fileNameLocalPath: fileNameLocalPath, sizeImage: NCGlobal.shared.avatarSize, avatarSizeRounded: NCGlobal.shared.avatarSizeRounded, etag: etag) { _, imageAvatar, _, etag, errorCode, _ in

                    if errorCode == 0, let etag = etag, let imageAvatar = imageAvatar {

                        NCManageDatabase.shared.addAvatar(fileName: fileName, etag: etag)
                        cell.imageItem.image = imageAvatar

                    } else if errorCode == NCGlobal.shared.errorNotModified, let imageAvatar = NCManageDatabase.shared.setAvatarLoaded(fileName: fileName) {

                        cell.imageItem.image = imageAvatar
                    }
                }
            }
        }

        dropDown.selectionAction = { (index, item) in
            let sharee = sharees[index]
            self.checkEnforcedPassword { password in
                self.networking?.createShare(shareWith: sharee.shareWith, shareType: sharee.shareType, password: password, metadata: self.metadata!)
            }
        }

        dropDown.show()
    }
}

// MARK: - UITableViewDelegate

extension NCShare: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
}

// MARK: - UITableViewDataSource

extension NCShare: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        var numOfRows = 0
        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata!)

        if shares.share != nil {
            numOfRows = shares.share!.count
        }

        return numOfRows
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata!)
        let tableShare = shares.share![indexPath.row]

        // LINK
        if tableShare.shareType == 3 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellLink", for: indexPath) as? NCShareLinkCell {
                cell.tableShare = tableShare
                cell.delegate = self
                cell.labelTitle.text = NSLocalizedString("_share_link_", comment: "")
                if tableShare.label.count > 0 {
                    cell.labelTitle.text = NSLocalizedString("_share_link_", comment: "") + " (" + tableShare.label + ")"
                }
                cell.labelTitle.textColor = NCBrandColor.shared.label
                return cell
            }
        } else {
        // USER
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellUser", for: indexPath) as? NCShareUserCell {

                cell.tableShare = tableShare
                cell.delegate = self
                cell.labelTitle.text = tableShare.shareWithDisplayname
                cell.labelTitle.textColor = NCBrandColor.shared.label
                cell.isUserInteractionEnabled = true
                cell.labelQuickStatus.isHidden = false
                cell.imageDownArrow.isHidden = false
                cell.buttonMenu.isHidden = false
                cell.imageItem.image = NCShareCommon.shared.getImageShareType(shareType: tableShare.shareType)

                let status = NCUtility.shared.getUserStatus(userIcon: tableShare.userIcon, userStatus: tableShare.userStatus, userMessage: tableShare.userMessage)
                cell.imageStatus.image = status.onlineStatus
                cell.status.text = status.statusMessage

                let fileName = appDelegate.userBaseUrl + "-" + tableShare.shareWith + ".png"

                NCOperationQueue.shared.downloadAvatar(user: tableShare.shareWith, dispalyName: tableShare.shareWithDisplayname, fileName: fileName, cell: cell, view: tableView)

                // If the initiator or the recipient is not the current user, show the list of sharees without any options to edit it.
                if tableShare.uidOwner != self.appDelegate.userId && tableShare.uidFileOwner != self.appDelegate.userId {
                    cell.isUserInteractionEnabled = false
                    cell.labelQuickStatus.isHidden = true
                    cell.imageDownArrow.isHidden = true
                    cell.buttonMenu.isHidden = true
                }

                cell.btnQuickStatus.setTitle("", for: .normal)
                cell.btnQuickStatus.contentHorizontalAlignment = .left

                if tableShare.permissions == NCGlobal.shared.permissionCreateShare {
                    cell.labelQuickStatus.text = NSLocalizedString("_share_file_drop_", comment: "")
                } else {
                    // Read Only
                    if CCUtility.isAnyPermission(toEdit: tableShare.permissions) {
                        cell.labelQuickStatus.text = NSLocalizedString("_share_editing_", comment: "")
                    } else {
                        cell.labelQuickStatus.text = NSLocalizedString("_share_read_only_", comment: "")
                    }
                }

                return cell
            }
        }

        return UITableViewCell()
    }
}

// MARK: - NCCell Delegates
extension NCShare: NCShareLinkCellDelegate, NCShareUserCellDelegate {

    func tapCopy(with tableShare: tableShare?, sender: Any) {

        if let link = tableShare?.url {
            NCShareCommon.shared.copyLink(link: link, viewController: self, sender: sender)
        }
    }

    func tapMenu(with tableShare: tableShare?, sender: Any) {

        guard let tableShare = tableShare else { return }

        if tableShare.shareType == 3 {
            let views = NCShareCommon.shared.openViewMenuShareLink(shareViewController: self, tableShare: tableShare, metadata: metadata!)
            shareLinkMenuView = views.shareLinkMenuView
            shareMenuViewWindow = views.viewWindow

            let tap = UITapGestureRecognizer(target: self, action: #selector(tapLinkMenuViewWindow))
            tap.delegate = self
            shareMenuViewWindow?.addGestureRecognizer(tap)
        } else {
            let views = NCShareCommon.shared.openViewMenuUser(shareViewController: self, tableShare: tableShare, metadata: metadata!)
            shareUserMenuView = views.shareUserMenuView
            shareMenuViewWindow = views.viewWindow

            let tap = UITapGestureRecognizer(target: self, action: #selector(tapLinkMenuViewWindow))
            tap.delegate = self
            shareMenuViewWindow?.addGestureRecognizer(tap)
        }
    }

    func showProfile(with tableShare: tableShare?, sender: Any) {
        guard let tableShare = tableShare else { return }
        showProfileMenu(userId: tableShare.shareWith)
    }

    func quickStatus(with tableShare: tableShare?, sender: Any) {

        guard let tableShare = tableShare else { return }

        if tableShare.shareType != NCGlobal.shared.permissionDefaultFileRemoteShareNoSupportShareOption {

            let quickStatusMenu = NCShareQuickStatusMenu()
            quickStatusMenu.toggleMenu(viewController: self, directory: metadata!.directory, tableShare: tableShare)
        }
    }
}
