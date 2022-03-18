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

class NCShare: UIViewController, UIGestureRecognizerDelegate, NCShareNetworkingDelegate, NCSharePagingContent {

    @IBOutlet weak var viewContainerConstraint: NSLayoutConstraint!
    @IBOutlet weak var sharedWithYouByView: UIView!
    @IBOutlet weak var sharedWithYouByImage: UIImageView!
    @IBOutlet weak var sharedWithYouByLabel: UILabel!
    @IBOutlet weak var sharedWithYouByNoteImage: UIImageView!
    @IBOutlet weak var sharedWithYouByNote: MarqueeLabel!
    @IBOutlet weak var searchFieldTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchField: UITextField!
    var textField: UITextField? { searchField }

    @IBOutlet weak var tableView: UITableView!

    weak var appDelegate = UIApplication.shared.delegate as? AppDelegate

    public var metadata: tableMetadata?
    public var sharingEnabled = true
    public var height: CGFloat = 0

    var shares: (firstShareLink: tableShare?, share: [tableShare]?) = (nil, nil)

    private var dropDown = DropDown()
    var networking: NCShareNetworking?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = NCBrandColor.shared.systemBackground

        viewContainerConstraint.constant = height
        searchFieldTopConstraint.constant = 10

        searchField.placeholder = NSLocalizedString("_shareLinksearch_placeholder_", comment: "")

        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.backgroundColor = NCBrandColor.shared.systemBackground

        tableView.register(UINib(nibName: "NCShareLinkCell", bundle: nil), forCellReuseIdentifier: "cellLink")
        tableView.register(UINib(nibName: "NCShareUserCell", bundle: nil), forCellReuseIdentifier: "cellUser")

        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataNCShare), object: nil)

        guard let appDelegate = appDelegate, let metadata = metadata else { return }

        checkSharedWithYou()

        reloadData()

        networking = NCShareNetworking(metadata: metadata, urlBase: appDelegate.urlBase, view: self.view, delegate: self)
        if sharingEnabled {
            let isVisible = (self.navigationController?.topViewController as? NCSharePaging)?.indexPage == .sharing
            networking?.readShare(showLoadingIndicator: isVisible)
        }

        // changeTheming
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changePermissions(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterShareChangePermissions), object: nil)

        changeTheming()
    }

    // Shared with you by ...
    func checkSharedWithYou() {
        guard let appDelegate = self.appDelegate, let metadata = metadata, !metadata.ownerId.isEmpty, metadata.ownerId != appDelegate.userId else { return }

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

        if !metadata.note.isEmpty {
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

            NCCommunication.shared.downloadAvatar(
                user: metadata.ownerId,
                fileNameLocalPath: fileNameLocalPath,
                sizeImage: NCGlobal.shared.avatarSize,
                avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                etag: etag) { _, imageAvatar, _, etag, errorCode, _ in
                    if errorCode == 0, let etag = etag, let imageAvatar = imageAvatar {
                        NCManageDatabase.shared.addAvatar(fileName: fileName, etag: etag)
                        self.sharedWithYouByImage.image = imageAvatar
                    } else if errorCode == NCGlobal.shared.errorNotModified, let imageAvatar = NCManageDatabase.shared.setAvatarLoaded(fileName: fileName) {
                        self.sharedWithYouByImage.image = imageAvatar
                    }
                }
        }
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
        if let metadata = metadata {
            shares = NCManageDatabase.shared.getTableShares(metadata: metadata)
        }
        tableView.reloadData()
    }

    // MARK: - IBAction

    @IBAction func searchFieldDidEndOnExit(textField: UITextField) {
        guard let searchString = textField.text, !searchString.isEmpty else { return }
        networking?.getSharees(searchString: searchString)
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

        self.present(alertController, animated: true, completion: nil)
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

        guard let sharees = sharees, let appDelegate = appDelegate else { return }

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
                label += " (\(sharee.circleInfo), \(sharee.circleOwner))"
            }
            dropDown.dataSource.append(label)
        }

        dropDown.anchorView = searchField
        dropDown.bottomOffset = CGPoint(x: 0, y: searchField.bounds.height)
        dropDown.width = searchField.bounds.width
        dropDown.direction = .bottom

        dropDown.cellNib = UINib(nibName: "NCSearchUserDropDownCell", bundle: nil)
        dropDown.customCellConfiguration = { (index: Index, _, cell: DropDownCell) -> Void in
            guard let cell = cell as? NCSearchUserDropDownCell else { return }
            let sharee = sharees[index]
            cell.setupCell(sharee: sharee, baseUrl: appDelegate)
        }

        dropDown.selectionAction = { index, _ in
            let sharee = sharees[index]
            self.checkEnforcedPassword { password in
                guard let metadata = self.metadata else { return }
                self.networking?.createShare(shareWith: sharee.shareWith, shareType: sharee.shareType, password: password, metadata: metadata)
            }
        }

        dropDown.show()
    }
}

// MARK: - UITableViewDelegate

extension NCShare: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0, indexPath.row == 0 {
            // internal cell has description
            return 90
        }
        return 70
    }
}

// MARK: - UITableViewDataSource

extension NCShare: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section != 0 else { return 2 }
        return shares.share?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Setup default share cells
        guard indexPath.section != 0 else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "cellLink", for: indexPath) as? NCShareLinkCell
            else { return UITableViewCell() }
            cell.delegate = self
            if indexPath.row == 0 {
                cell.isInternalLink = true
            } else if shares.firstShareLink?.isInvalidated != true {
                cell.tableShare = shares.firstShareLink
            }
            cell.setupCellUI()
            return cell
        }

        guard let appDelegate = appDelegate, let tableShare = shares.share?[indexPath.row] else { return UITableViewCell() }

        // LINK
        if tableShare.shareType == 3 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellLink", for: indexPath) as? NCShareLinkCell {
                cell.tableShare = tableShare
                cell.delegate = self
                cell.setupCellUI()
                return cell
            }
        } else {
        // USER
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellUser", for: indexPath) as? NCShareUserCell {
                cell.tableShare = tableShare
                cell.delegate = self
                cell.setupCellUI(userId: appDelegate.userId)
                let fileName = appDelegate.userBaseUrl + "-" + tableShare.shareWith + ".png"
                NCOperationQueue.shared.downloadAvatar(user: tableShare.shareWith, dispalyName: tableShare.shareWithDisplayname, fileName: fileName, cell: cell, view: tableView)
                return cell
            }
        }

        return UITableViewCell()
    }
}
