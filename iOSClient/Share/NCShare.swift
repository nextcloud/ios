//
//  NCShare.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/07/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//  Copyright © 2024 STRATO GmbH
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
import SwiftUI

class NCShare: UIViewController, NCSharePagingContent {
    @IBOutlet weak var viewContainerConstraint: NSLayoutConstraint!
    @IBOutlet weak var sharedWithYouByView: UIView!
    @IBOutlet weak var sharedWithYouByImage: UIImageView!
    @IBOutlet weak var sharedWithYouByLabel: UILabel!
    @IBOutlet weak var searchFieldTopConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var searchPlaceholder: UIView!
    private var shareSearchHost: ShareSearchFieldHost?
    var textField: UIView? { shareSearchHost?.view }

    @IBOutlet weak var tableView: UITableView!

    weak var appDelegate = UIApplication.shared.delegate as? AppDelegate

    public var metadata: tableMetadata!
    public var sharingEnabled = true
    public var height: CGFloat = 0
    let shareCommon = NCShareCommon()
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared

    var canReshare: Bool {
        return ((metadata.sharePermissionsCollaborationServices & NCPermissions().permissionShareShare) != 0)
    }

    var session: NCSession.Session {
        NCSession.shared.getSession(account: metadata.account)
    }

    var shares: (firstShareLink: tableShare?, share: [tableShare]?) = (nil, nil)

    private var dropDown = DropDown()
    var networking: NCShareNetworking?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = NCBrandColor.shared.appBackgroundColor
        
        viewContainerConstraint.constant = height
        searchFieldTopConstraint.constant = 0

        shareSearchHost = ShareSearchFieldHost(onSearchTextChanged: { [weak self] text in
            self?.searchTextDidChange(text)
        }, onContactButtonTap: { [weak self] in
            self?.selectContactClicked()
        })
        shareSearchHost?.placeholder = NSLocalizedString("_shareLinksearch_placeholder_", comment: "")
        if let shareSearchHost {
            searchPlaceholder.addSubview(shareSearchHost.view)
            shareSearchHost.view.translatesAutoresizingMaskIntoConstraints = false
            searchPlaceholder.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([searchPlaceholder.leadingAnchor.constraint(equalTo: shareSearchHost.view.leadingAnchor),
                                         searchPlaceholder.trailingAnchor.constraint(equalTo: shareSearchHost.view.trailingAnchor),
                                         searchPlaceholder.topAnchor.constraint(equalTo: shareSearchHost.view.topAnchor),
                                         searchPlaceholder.bottomAnchor.constraint(equalTo: shareSearchHost.view.bottomAnchor)])
        }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.backgroundColor = NCBrandColor.shared.appBackgroundColor
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 10, right: 0)

        tableView.register(UINib(nibName: "NCShareLinkCell", bundle: nil), forCellReuseIdentifier: "cellLink")
        tableView.register(UINib(nibName: "NCShareUserCell", bundle: nil), forCellReuseIdentifier: "cellUser")

        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataNCShare), object: nil)

        if metadata.e2eEncrypted {
            let direcrory = self.database.getTableDirectory(account: metadata.account, serverUrl: metadata.serverUrl)
            let capabilities = NCCapabilities.shared.getCapabilities(account: metadata.account)
            if capabilities.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV12 ||
                (capabilities.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 && direcrory?.e2eEncrypted ?? false) {
                searchFieldTopConstraint.constant = -50
                textField?.alpha = 0
            }
        } else {
            checkSharedWithYou()
        }

        reloadData()

        networking = NCShareNetworking(metadata: metadata, view: self.view, delegate: self, session: session)
        if sharingEnabled {
            let isVisible = (self.navigationController?.topViewController as? NCSharePaging)?.page == .sharing
            networking?.readShare(showLoadingIndicator: isVisible)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarAppearance()
    }

    func makeNewLinkShare() {
        guard
            let advancePermission = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "NCShareAdvancePermission") as? NCShareAdvancePermission,
            let navigationController = self.navigationController else { return }
        self.checkEnforcedPassword(shareType: shareCommon.SHARE_TYPE_LINK) { password in
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
            if let shareSearchHost {
                shareSearchHost.view.isUserInteractionEnabled = false
                shareSearchHost.view.alpha = 0.5
                shareSearchHost.placeholder = NSLocalizedString("_share_reshare_disabled_", comment: "")
            }
        }

        searchFieldTopConstraint.constant = 45
        sharedWithYouByView.isHidden = false
        sharedWithYouByLabel.text = NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata.ownerDisplayName
        sharedWithYouByImage.image = utility.loadUserImage(for: metadata.ownerId, displayName: metadata.ownerDisplayName, urlBase: session.urlBase)
        sharedWithYouByLabel.accessibilityHint = NSLocalizedString("_show_profile_", comment: "")

        let shareAction = UITapGestureRecognizer(target: self, action: #selector(openShareProfile))
        sharedWithYouByImage.addGestureRecognizer(shareAction)
        let shareLabelAction = UITapGestureRecognizer(target: self, action: #selector(openShareProfile))
        sharedWithYouByLabel.addGestureRecognizer(shareLabelAction)
    }

    // MARK: - Notification Center

    @objc func openShareProfile() {
        self.showProfileMenu(userId: metadata.ownerId, session: session)
    }

    // MARK: -

    @objc func reloadData() {
        shares = self.database.getTableShares(metadata: metadata)
        tableView.reloadData()
    }

    // MARK: - IBAction

    @IBAction func searchFieldDidEndOnExit(textField: UITextField) {
        // https://stackoverflow.com/questions/25471114/how-to-validate-an-e-mail-address-in-swift
        func isValidEmail(_ email: String) -> Bool {

            let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
            return emailPred.evaluate(with: email)
        }
        guard let searchString = textField.text, !searchString.isEmpty else { return }
        if searchString.contains("@"), !isValidEmail(searchString) { return }
        networking?.getSharees(searchString: searchString)
    }

    func checkEnforcedPassword(shareType: Int, completion: @escaping (String?) -> Void) {
        guard NCCapabilities.shared.getCapabilities(account: session.account).capabilityFileSharingPubPasswdEnforced,
              shareType == shareCommon.SHARE_TYPE_LINK || shareType == shareCommon.SHARE_TYPE_EMAIL
        else { return completion(nil) }

        self.present(UIAlertController.password(titleKey: "_enforce_password_protection_", completion: completion), animated: true)
    }

    private func selectContactClicked() {
        let cnPicker = CNContactPickerViewController()
        cnPicker.delegate = self
        cnPicker.displayedPropertyKeys = [CNContactEmailAddressesKey]
        cnPicker.predicateForEnablingContact = NSPredicate(format: "emailAddresses.@count > 0")
        cnPicker.predicateForSelectionOfProperty = NSPredicate(format: "emailAddresses.@count > 0")
        self.present(cnPicker, animated: true)
    }
}

// MARK: - NCShareNetworkingDelegate

extension NCShare: NCShareNetworkingDelegate {
    func readShareCompleted() {
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
    }

    func shareCompleted() {
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
    }

    func unShareCompleted() {
        self.reloadData()
    }

    func updateShareWithError(idShare: Int) {
        self.reloadData()
    }

    func getSharees(sharees: [NKSharee]?) {
        guard let sharees else { return }

        dropDown = DropDown()
        let appearance = DropDown.appearance()

        // Setting up the blur effect
        let blurEffect = UIBlurEffect(style: .light) // You can choose .dark, .extraLight, or .light
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = CGRect(x: 0, y: 0, width: 500, height: 20)

        appearance.backgroundColor = UIColor(resource: .Share.SearchUserCell.Background.normal)
        appearance.selectionBackgroundColor = UIColor(resource: .Share.SearchUserCell.Background.pressed)
        appearance.cornerRadius = 10
        appearance.shadowColor = .black
        appearance.shadowOpacity = 0.2
        appearance.shadowRadius = 30
        appearance.animationduration = 0.25
        appearance.textColor = UIColor(resource: .Share.SearchUserCell.title)
		appearance.selectedTextColor = UIColor(resource: .Share.SearchUserCell.title)

        for sharee in sharees {
            var label = sharee.label
            if sharee.shareType == shareCommon.SHARE_TYPE_CIRCLE {
                label += " (\(sharee.circleInfo), \(sharee.circleOwner))"
            }
            dropDown.dataSource.append(label)
        }

        if let shareSearchHost {
            dropDown.anchorView = shareSearchHost.view
            dropDown.bottomOffset = CGPoint(x: 10, y: shareSearchHost.view.bounds.height)
            dropDown.width = shareSearchHost.view.bounds.width - 20
            dropDown.direction = .bottom
        }

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
    
    func showOKAlert(title: String?, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
        return present(alertController, animated: true)
    }
}

// MARK: - UITableViewDelegate

extension NCShare: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0, indexPath.row == 0 {
            // internal cell has description
            return 40
        }
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
            if metadata.e2eEncrypted, NCCapabilities.shared.getCapabilities(account: metadata.account).capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV12 {
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
            if metadata.e2eEncrypted, NCCapabilities.shared.getCapabilities(account: metadata.account).capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV12 {
                cell.tableShare = shares.firstShareLink
            } else {
                if indexPath.row == 1 {
                    cell.isInternalLink = true
                } else if shares.firstShareLink?.isInvalidated != true {
                    cell.tableShare = shares.firstShareLink
                }
            }
            cell.setupCellUI()
            return cell
        }

        guard let tableShare = shares.share?[indexPath.row] else { return UITableViewCell() }

        // LINK
        if tableShare.shareType == shareCommon.SHARE_TYPE_LINK {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellLink", for: indexPath) as? NCShareLinkCell {
                cell.indexPath = indexPath
                cell.tableShare = tableShare
                cell.delegate = self
                cell.setupCellUI()
                return cell
            }
        } else {
        // USER / GROUP etc.
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellUser", for: indexPath) as? NCShareUserCell {
                cell.indexPath = indexPath
                cell.tableShare = tableShare
                cell.delegate = self
                cell.setupCellUI(userId: session.userId)

                let fileName = NCSession.shared.getFileName(urlBase: session.urlBase, user: tableShare.shareWith)
                
                cell.fileAvatarImageView?.image = utility.loadUserImage(for: tableShare.shareWith, displayName: tableShare.shareWithDisplayname, urlBase: metadata.urlBase)

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
            showEmailList(arrEmail: contact.emailAddresses.map({$0.value as String}))
        } else if let email = contact.emailAddresses.first?.value as? String {
            shareSearchHost?.text = email
            networking?.getSharees(searchString: email)
        }
    }

    func showEmailList(arrEmail: [String]) {
        var actions = [NCMenuAction]()
        for email in arrEmail {
            actions.append(
                NCMenuAction(
                    title: email,
                    icon: utility.loadImage(named: "email", colors: [NCBrandColor.shared.iconImageColor]),
                    selected: false,
                    on: false,
                    action: { _ in
                        self.shareSearchHost?.text = email
                        self.networking?.getSharees(searchString: email)
                    }
                )
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.presentMenu(with: actions)
        }
    }
}

// MARK: - Search

extension NCShare {
    func searchTextDidChange(_ searchText: String) {
        if searchText.isEmpty {
            dropDown.hide()
        } else {
            searchSharees()
        }
    }

    @objc private func searchSharees() {
        // https://stackoverflow.com/questions/25471114/how-to-validate-an-e-mail-address-in-swift
        func isValidEmail(_ email: String) -> Bool {

            let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
            return emailPred.evaluate(with: email)
        }
        guard let searchString = shareSearchHost?.text, !searchString.isEmpty else { return }
        if searchString.contains("@"), !isValidEmail(searchString) { return }
        networking?.getSharees(searchString: searchString)
    }
}
