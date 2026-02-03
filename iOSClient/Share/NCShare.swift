//
//  NCShare.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/07/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//  Copyright © 2022 Henrik Storch. All rights reserved.
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
import NextcloudKit
import MarqueeLabel
import ContactsUI

class NCShare: UIViewController, NCSharePagingContent {
    @IBOutlet weak var viewContainerConstraint: NSLayoutConstraint!
    @IBOutlet weak var sharedWithYouByView: UIView!
    @IBOutlet weak var sharedWithYouByImage: UIImageView!
    @IBOutlet weak var sharedWithYouByLabel: UILabel!
    @IBOutlet weak var searchFieldTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchField: UISearchBar!
    var textField: UIView? { searchField }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnContact: UIButton!

    weak var appDelegate = UIApplication.shared.delegate as? AppDelegate

    public var metadata: tableMetadata!
    public var height: CGFloat = 0
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared

    var shareLinksCount = 0

    var canReshare: Bool {
        return ((metadata.sharePermissionsCollaborationServices & NKShare.Permission.share.rawValue) != 0)
    }

    var session: NCSession.Session {
        NCSession.shared.getSession(account: metadata.account)
    }

    var shares: (firstShareLink: tableShare?, share: [tableShare]?) = (nil, nil)

    var capabilities = NKCapabilities.Capabilities()

    private var dropDown = DropDown()
    private var avatarButton: UIButton!
    var networking: NCShareNetworking?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        viewContainerConstraint.constant = height
        searchFieldTopConstraint.constant = 0

        searchField.placeholder = NSLocalizedString("_shareLinksearch_placeholder_", comment: "")
        searchField.autocorrectionType = .no

        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.backgroundColor = .systemBackground
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 10, right: 0)

        tableView.register(UINib(nibName: "NCShareLinkCell", bundle: nil), forCellReuseIdentifier: "cellLink")
        tableView.register(UINib(nibName: "NCShareUserCell", bundle: nil), forCellReuseIdentifier: "cellUser")

        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataNCShare), object: nil)

        Task {
            self.capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)
            if metadata.e2eEncrypted {
                let metadataDirectory = await self.database.getMetadataDirectoryAsync(serverUrl: metadata.serverUrl, account: metadata.account)
                if capabilities.e2EEApiVersion == "1.2" ||
                    (NCGlobal.shared.isE2eeVersion2(capabilities.e2EEApiVersion) && metadataDirectory?.e2eEncrypted ?? false) {
                    searchFieldTopConstraint.constant = -50
                    searchField.alpha = 0
                    btnContact.alpha = 0
                }
            } else {
                checkSharedWithYou()
            }

            reloadData()

            networking = NCShareNetworking(metadata: metadata, view: self.view, delegate: self, session: session)
            let isVisible = (self.navigationController?.topViewController as? NCSharePaging)?.page == .sharing
            networking?.readShare(showLoadingIndicator: isVisible)
            searchField.searchTextField.font = .systemFont(ofSize: 14)
            searchField.delegate = self
        }
    }

    func makeNewLinkShare() {
        guard
            let advancePermission = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "NCShareAdvancePermission") as? NCShareAdvancePermission,
            let navigationController = self.navigationController else { return }
        self.checkEnforcedPassword(shareType: NKShare.ShareType.publicLink.rawValue) { password in
            advancePermission.networking = self.networking
            advancePermission.share = TransientShare.shareLink(metadata: self.metadata, password: password)
            advancePermission.metadata = self.metadata
            navigationController.pushViewController(advancePermission, animated: true)
        }
    }

    // Shared with you by ...
    func checkSharedWithYou() {
        guard !metadata.ownerId.isEmpty, metadata.ownerId != session.userId else { return }

        if !canReshare {
            searchField.isUserInteractionEnabled = false
            searchField.alpha = 0.5
            searchField.placeholder = NSLocalizedString("_share_reshare_disabled_", comment: "")
            btnContact.isEnabled = false
        }

        searchFieldTopConstraint.constant = 45
        sharedWithYouByView.isHidden = false
        sharedWithYouByLabel.text = NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName
        sharedWithYouByImage.image = utility.loadUserImage(for: metadata.ownerId, displayName: metadata.ownerDisplayName, urlBase: session.urlBase)
        sharedWithYouByLabel.accessibilityHint = NSLocalizedString("_show_profile_", comment: "")

        avatarButton = UIButton(type: .system)
        avatarButton.translatesAutoresizingMaskIntoConstraints = false
        avatarButton.backgroundColor = .clear
        sharedWithYouByView.addSubview(avatarButton)
        NSLayoutConstraint.activate([
            avatarButton.topAnchor.constraint(equalTo: sharedWithYouByImage.topAnchor),
            avatarButton.bottomAnchor.constraint(equalTo: sharedWithYouByImage.bottomAnchor),
            avatarButton.leadingAnchor.constraint(equalTo: sharedWithYouByImage.leadingAnchor),
            avatarButton.trailingAnchor.constraint(equalTo: sharedWithYouByLabel.trailingAnchor)
        ])
        avatarButton.showsMenuAsPrimaryAction = true
        avatarButton.menu = NCContextMenuProfile(userId: metadata.ownerId, session: session, viewController: self).viewMenu()

        let fileName = NCSession.shared.getFileName(urlBase: session.urlBase, user: metadata.ownerId)
        let results = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName)

        if results.image == nil {
            let etag = self.database.getTableAvatar(fileName: fileName)?.etag
            let fileNameLocalPath = utilityFileSystem.createServerUrl(serverUrl: utilityFileSystem.directoryUserData, fileName: fileName)

            NextcloudKit.shared.downloadAvatar(
                user: metadata.ownerId,
                fileNameLocalPath: fileNameLocalPath,
                sizeImage: NCGlobal.shared.avatarSize,
                avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                etagResource: etag,
                account: metadata.account) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.metadata.account,
                                                                                                    path: self.metadata.ownerId,
                                                                                                    name: "downloadAvatar")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                } completion: { _, imageAvatar, _, etag, _, error in
                    if error == .success, let etag = etag, let imageAvatar = imageAvatar {
                        self.database.addAvatar(fileName: fileName, etag: etag)
                        self.sharedWithYouByImage.image = imageAvatar
                        self.reloadData()
                    } else if error.errorCode == NCGlobal.shared.errorNotModified, let imageAvatar = self.database.setAvatarLoaded(fileName: fileName) {
                        self.sharedWithYouByImage.image = imageAvatar
                    }
                }
        }

        reloadData()
    }

    // MARK: -

    @objc func reloadData() {
        shares = self.database.getTableShares(metadata: metadata)
        shareLinksCount = 0
        tableView.reloadData()
    }

    // MARK: - IBAction

    @IBAction func searchFieldDidEndOnExit(textField: UITextField) {
        guard let searchString = textField.text, !searchString.isEmpty else { return }
        if searchString.contains("@"), !isValidEmail(searchString) { return }
        networking?.getSharees(searchString: searchString)
    }

    func checkEnforcedPassword(shareType: Int, completion: @escaping (String?) -> Void) {
        guard capabilities.fileSharingPubPasswdEnforced,
              shareType == NKShare.ShareType.publicLink.rawValue || shareType == NKShare.ShareType.email.rawValue
        else { return completion(nil) }

        self.present(UIAlertController.password(titleKey: "_enforce_password_protection_", completion: completion), animated: true)
    }

    @IBAction func selectContactClicked(_ sender: Any) {
        let cnPicker = CNContactPickerViewController()
        cnPicker.delegate = self
        cnPicker.displayedPropertyKeys = [CNContactEmailAddressesKey]
        cnPicker.predicateForEnablingContact = NSPredicate(format: "emailAddresses.@count > 0")
        cnPicker.predicateForSelectionOfProperty = NSPredicate(format: "emailAddresses.@count > 0")
        self.present(cnPicker, animated: true)
    }

    func presentQuickStatusActionSheet(for share: tableShare, sender: Any?) {
        guard let metadata = metadata else { return }

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let isDirectory = metadata.directory

        // Read Only
        let readOnlyAction = UIAlertAction(title: NSLocalizedString("_share_read_only_", comment: ""), style: .default) { [weak self] _ in
            let permissions = NCSharePermissions.getPermissionValue(canCreate: false, canEdit: false, canDelete: false, canShare: false, isDirectory: isDirectory)
            self?.updateSharePermissions(share: share, permissions: permissions)
        }
        alertController.addAction(readOnlyAction)

        // Editing
        let editingAction = UIAlertAction(title: NSLocalizedString("_share_editing_", comment: ""), style: .default) { [weak self] _ in
            let permissions = NCSharePermissions.getPermissionValue(canCreate: true, canEdit: true, canDelete: true, canShare: true, isDirectory: isDirectory)
            self?.updateSharePermissions(share: share, permissions: permissions)
        }
        alertController.addAction(editingAction)

        // File Drop (only for directories with public link or email share)
        if isDirectory && (share.shareType == NKShare.ShareType.publicLink.rawValue || share.shareType == NKShare.ShareType.email.rawValue) {
            let fileDropAction = UIAlertAction(title: NSLocalizedString("_share_file_drop_", comment: ""), style: .default) { [weak self] _ in
                let permissions = NCSharePermissions.getPermissionValue(canRead: false, canCreate: true, canEdit: false, canDelete: false, canShare: false, isDirectory: isDirectory)
                self?.updateSharePermissions(share: share, permissions: permissions)
            }
            alertController.addAction(fileDropAction)
        }

        // Custom Permissions
        let customAction = UIAlertAction(title: NSLocalizedString("_custom_permissions_", comment: ""), style: .default) { [weak self] _ in
            self?.openAdvancePermission(for: share)
        }
        alertController.addAction(customAction)

        // Cancel
        let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel)
        alertController.addAction(cancelAction)

        // iPad popover support
        if let popover = alertController.popoverPresentationController,
           let sourceView = sender as? UIView {
            let barItem = UIBarButtonItem(customView: sourceView)
            popover.sourceItem = barItem
        }

        present(alertController, animated: true)
    }

    private func openAdvancePermission(for share: tableShare) {
        guard let advancePermission = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "NCShareAdvancePermission") as? NCShareAdvancePermission,
              !share.isInvalidated,
              let metadata = metadata else { return }

        advancePermission.networking = networking
        advancePermission.share = tableShare(value: share)
        advancePermission.oldTableShare = tableShare(value: share)
        advancePermission.metadata = metadata

        if let downloadLimit = try? NCManageDatabase.shared.getDownloadLimit(byAccount: metadata.account, shareToken: share.token) {
            advancePermission.downloadLimit = .limited(limit: downloadLimit.limit, count: downloadLimit.count)
        }

        navigationController?.pushViewController(advancePermission, animated: true)
    }

    func updateSharePermissions(share: tableShare, permissions: Int) {
        let updatedShare = tableShare(value: share)
        updatedShare.permissions = permissions

        var downloadLimit: DownloadLimitViewModel = .unlimited

        do {
            if let model = try database.getDownloadLimit(byAccount: metadata.account, shareToken: updatedShare.token) {
                downloadLimit = .limited(limit: model.limit, count: model.count)
            }
        } catch {
            nkLog(error: "Failed to get download limit from database!")
            return
        }

        networking?.updateShare(updatedShare, downloadLimit: downloadLimit)
    }
}

// MARK: - NCShareNetworkingDelegate

extension NCShare: NCShareNetworkingDelegate {
    func readShareCompleted() {
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
        reloadData()
    }

    func shareCompleted() {
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
        reloadData()
    }

    func unShareCompleted() {
        reloadData()
    }

    func updateShareWithError(idShare: Int) {
        reloadData()
    }

    func getSharees(sharees: [NKSharee]?) {
        guard let sharees else {
            return
        }

        // close keyboard
        self.view.endEditing(true)

        dropDown = DropDown()
        let appearance = DropDown.appearance()

        // Setting up the blur effect
        let blurEffect = UIBlurEffect(style: .light) // You can choose .dark, .extraLight, or .light
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = CGRect(x: 0, y: 0, width: 500, height: 20)

        appearance.backgroundColor = .systemBackground
        appearance.cornerRadius = 10
        appearance.shadowColor = .black
        appearance.shadowOpacity = 0.2
        appearance.shadowRadius = 30
        appearance.animationduration = 0.25
        appearance.textColor = .darkGray

        let account = NCManageDatabase.shared.getTableAccount(account: metadata.account)
        let existingShares = NCManageDatabase.shared.getTableShares(metadata: metadata)

        for sharee in sharees {
            if sharee.shareWith == account?.user { continue } // do not show your own account
            if let shares = existingShares.share, shares.contains(where: {$0.shareWith == sharee.shareWith}) { continue } // do not show already existing sharees
            if metadata.ownerDisplayName == sharee.shareWith { continue } // do not show owner of the share 
            var label = sharee.label
            if sharee.shareType == NKShare.ShareType.team.rawValue {
                label += " (\(sharee.circleInfo), \(sharee.circleOwner))"
            }

            dropDown.dataSource.append(label)
        }

        dropDown.anchorView = searchField
        dropDown.bottomOffset = CGPoint(x: 10, y: searchField.bounds.height)
        dropDown.width = searchField.bounds.width - 20
        dropDown.direction = .bottom

        dropDown.cellNib = UINib(nibName: "NCSearchUserDropDownCell", bundle: nil)
        dropDown.customCellConfiguration = { (index: Index, _, cell: DropDownCell) in
            guard let cell = cell as? NCSearchUserDropDownCell else { return }
            let sharee = sharees[index]
            cell.setupCell(sharee: sharee, session: self.session)
        }

        dropDown.selectionAction = { index, _ in
            let sharee = sharees[index]
            guard
                let advancePermission = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "NCShareAdvancePermission") as? NCShareAdvancePermission,
                let navigationController = self.navigationController else { return }
            self.checkEnforcedPassword(shareType: sharee.shareType) { password in
                let shareOptions = TransientShare(sharee: sharee, metadata: self.metadata, password: password)
                advancePermission.share = shareOptions
                advancePermission.networking = self.networking
                advancePermission.metadata = self.metadata
                navigationController.pushViewController(advancePermission, animated: true)
            }
        }

        dropDown.show()
    }

    func downloadLimitRemoved(by token: String) {
        database.deleteDownloadLimit(byAccount: metadata.account, shareToken: token)
    }

    func downloadLimitSet(to limit: Int, by token: String) {
        database.createDownloadLimit(account: metadata.account, count: 0, limit: limit, token: token)
    }
}

// MARK: - UITableViewDelegate

extension NCShare: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - UITableViewDataSource

extension NCShare: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numRows = shares.share?.count ?? 0
        if section == 0 {
            if metadata.e2eEncrypted, capabilities.e2EEApiVersion == "1.2" {
                numRows = 1
            } else {
                // don't allow link creation if reshare is disabled
                numRows = shares.firstShareLink != nil || canReshare ? 2 : 1
            }
        }
        return numRows
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Setup default share cells
        guard indexPath.section != 0 else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "cellLink", for: indexPath) as? NCShareLinkCell
            else { return UITableViewCell() }
            cell.delegate = self
            if metadata.e2eEncrypted, capabilities.e2EEApiVersion == "1.2" {
                cell.tableShare = shares.firstShareLink
            } else {
                if indexPath.row == 0 {
                    cell.isInternalLink = true
                } else if shares.firstShareLink?.isInvalidated != true {
                    cell.tableShare = shares.firstShareLink
                }
            }
            cell.isDirectory = metadata.directory
            cell.setupCellUI()

            if cell.tableShare != nil, let tableShare = shares.firstShareLink {
                cell.menuButton.menu = NCContextMenuShare(share: tableShare, isDirectory: metadata.isDirectory, canReshare: canReshare, shareController: self).viewMenu()
                cell.menuButton.showsMenuAsPrimaryAction = true
            }

            shareLinksCount += 1
            return cell
        }

        let orderedShares = shares.share?.sorted(by: { $0.date?.compare($1.date as Date? ?? Date()) == .orderedAscending })
        guard let tableShare = orderedShares?[indexPath.row] else { return UITableViewCell() }

        // LINK, EMAIL
        if tableShare.shareType == NKShare.ShareType.publicLink.rawValue || tableShare.shareType == NKShare.ShareType.email.rawValue {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellLink", for: indexPath) as? NCShareLinkCell {
                cell.indexPath = indexPath
                cell.tableShare = tableShare
                cell.isDirectory = metadata.directory
                cell.delegate = self
                cell.setupCellUI(titleAppendString: String(shareLinksCount))
                cell.menuButton.menu = NCContextMenuShare(share: tableShare, isDirectory: metadata.isDirectory, canReshare: canReshare, shareController: self).viewMenu()
                cell.menuButton.showsMenuAsPrimaryAction = true
                if tableShare.shareType == NKShare.ShareType.publicLink.rawValue { shareLinksCount += 1 }
                return cell
            }
        } else {
        // USER / GROUP etc.
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellUser", for: indexPath) as? NCShareUserCell {
                cell.indexPath = indexPath
                cell.tableShare = tableShare
                cell.isDirectory = metadata.directory
                cell.delegate = self
                cell.setupCellUI(userId: session.userId, session: session, metadata: metadata)

                cell.buttonMenu.menu = NCContextMenuShare(share: tableShare, isDirectory: metadata.isDirectory, canReshare: canReshare, shareController: self).viewMenu()
                cell.buttonMenu.showsMenuAsPrimaryAction = true

                return cell
            }
        }

        return UITableViewCell()
    }
}

// MARK: - CNContactPickerDelegate

extension NCShare: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        if  contact.emailAddresses.count > 1 {
            showEmailList(arrEmail: contact.emailAddresses.map({$0.value as String}), sender: picker)
        } else if let email = contact.emailAddresses.first?.value as? String {
            searchField?.text = email
            networking?.getSharees(searchString: email)
        }
    }

    func showEmailList(arrEmail: [String], sender: Any?) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        for email in arrEmail {
            alert.addAction(UIAlertAction(title: email, style: .default) { _ in
                self.searchField?.text = email
                self.networking?.getSharees(searchString: email)
            })
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))

        // iPad popover support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.present(alert, animated: true)
        }
    }
}

// MARK: - UISearchBarDelegate

extension NCShare: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(searchSharees(_:)), object: nil)

        if searchText.isEmpty {
            dropDown.hide()
        } else {
            perform(#selector(searchSharees(_:)), with: nil, afterDelay: 1)
        }
    }

    @objc private func searchSharees(_ sender: Any?) {
        guard let searchString = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !searchString.isEmpty else { return }
        if searchString.contains("@"), !isValidEmail(searchString) { return }
        networking?.getSharees(searchString: searchString)
    }
}

extension NCShare {
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "^[\u{0021}-\u{007E}\\p{L}\\p{M}\\p{N}._%+\\-]+@([\\p{L}\\p{M}\\p{N}0-9\\-]+\\.)+[\\p{L}\\p{M}]{2,64}$" // Unicode regex allows for all unicode chars, ex. ß, ü, and more.
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

