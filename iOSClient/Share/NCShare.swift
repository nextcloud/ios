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

enum ShareSection: Int, CaseIterable {
    case header
    case linkByEmail
    case links
    case emails
}

class NCShare: UIViewController, NCSharePagingContent {
//    @IBOutlet weak var viewContainerConstraint: NSLayoutConstraint!
//    @IBOutlet weak var sharedWithYouByView: UIView!
//    @IBOutlet weak var sharedWithYouByImage: UIImageView!
//    @IBOutlet weak var sharedWithYouByLabel: UILabel!
//    @IBOutlet weak var searchFieldTopConstraint: NSLayoutConstraint!
//    @IBOutlet weak var searchField: UISearchBar!
//    var textField: UIView? { searchField }
    var textField: UITextField? { self.view.viewWithTag(Tag.searchField) as? UITextField }

    @IBOutlet weak var tableView: UITableView!
//    @IBOutlet weak var btnContact: UIButton!

    weak var appDelegate = UIApplication.shared.delegate as? AppDelegate

    public var metadata: tableMetadata!
    public var height: CGFloat = 0
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared

    var shareLinksCount = 0

    var canReshare: Bool {
        guard let metadata = metadata else { return true }
        return ((metadata.sharePermissionsCollaborationServices & NKShare.Permission.share.rawValue) != 0)
    }

    var session: NCSession.Session {
        NCSession.shared.getSession(account: metadata.account)
    }

    var shares: (firstShareLink: tableShare?, share: [tableShare]?) = (nil, nil)

    var capabilities = NKCapabilities.Capabilities()

    private var dropDown = DropDown()
    var networking: NCShareNetworking?

    var isCurrentUser: Bool {
        if let currentUser = NCManageDatabase.shared.getActiveTableAccount(), currentUser.userId == metadata?.ownerId {
            return true
        }
        return false
    }
    var shareLinks: [tableShare] = []
    var shareEmails: [tableShare] = []
    var shareOthers: [tableShare] = []
    private var cachedHeader: NCShareAdvancePermissionHeader?
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.setNavigationBarAppearance()
        view.backgroundColor = .systemBackground
        title = NSLocalizedString("_details_", comment: "")

        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.backgroundColor = .systemBackground
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 10, right: 0)

        tableView.register(UINib(nibName: "NCShareLinkCell", bundle: nil), forCellReuseIdentifier: "cellLink")
        tableView.register(UINib(nibName: "NCShareUserCell", bundle: nil), forCellReuseIdentifier: "cellUser")
        tableView.register(UINib(nibName: "NCShareEmailFieldCell", bundle: nil), forCellReuseIdentifier: "NCShareEmailFieldCell")
        tableView.register(NCShareEmailLinkHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: NCShareEmailLinkHeaderView.reuseIdentifier)
        tableView.register(CreateLinkFooterView.self, forHeaderFooterViewReuseIdentifier: CreateLinkFooterView.reuseIdentifier)
        tableView.register(NoSharesFooterView.self, forHeaderFooterViewReuseIdentifier: NoSharesFooterView.reuseIdentifier)
        tableView.register(UINib(nibName: "NCShareAdvancePermissionHeader", bundle: nil),
                           forHeaderFooterViewReuseIdentifier: NCShareAdvancePermissionHeader.reuseIdentifier)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataNCShare), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDidCreateShareLink), object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(handleFavoriteStatusChanged), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteStatusChanged), object: nil)

        guard let metadata = metadata else { return }
        
        reloadData()
        
        Task {
            self.capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)
            if metadata.e2eEncrypted {
                let metadataDirectory = await self.database.getMetadataDirectoryAsync(serverUrl: metadata.serverUrl, account: metadata.account)
               
                if capabilities.e2EEApiVersion == "1.2" ||
                    (NCGlobal.shared.isE2eeVersion2(capabilities.e2EEApiVersion) && metadataDirectory?.e2eEncrypted ?? false) {
//                    searchFieldTopConstraint.constant = -50
//                    searchField.alpha = 0
//                    btnContact.alpha = 0
                }
            } else {
//                checkSharedWithYou()
            }

//            reloadData()

            networking = NCShareNetworking(metadata: metadata, view: self.view, delegate: self, session: session)
            let isVisible = (self.navigationController?.topViewController as? NCSharePaging)?.page == .sharing
            networking?.readShare(showLoadingIndicator: isVisible)
//            searchField.searchTextField.font = .systemFont(ofSize: 14)
//            searchField.delegate = self
        }
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .plain, target: self, action: #selector(exitTapped))
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    }
    
    @objc func exitTapped() {
//        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUpdateIcons)
        self.dismiss(animated: true, completion: nil)
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

    // MARK: - Notification Center

    @objc func openShareProfile(_ sender: UITapGestureRecognizer) {
        self.showProfileMenu(userId: metadata.ownerId, session: session, sender: sender.view)
    }

    private func scrollToTopIfNeeded() {
        if tableView.numberOfSections > 0 && tableView.numberOfRows(inSection: 0) > 0 {
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        }
    }

    @objc func keyboardWillShow(notification: Notification) {
        if UIDevice.current.userInterfaceIdiom == .phone {
            if UIScreen.main.bounds.width < 374 || UIDevice.current.orientation.isLandscape {
                if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                    if view.frame.origin.y == 0 {
                        scrollToTopIfNeeded()
                        self.view.frame.origin.y -= keyboardSize.height
                    }
                }
            } else if UIScreen.main.bounds.height < 850 {
                if view.frame.origin.y == 0 {
                    scrollToTopIfNeeded()
                    self.view.frame.origin.y -= 70
                }
            } else {
                if view.frame.origin.y == 0 {
                    scrollToTopIfNeeded()
                    self.view.frame.origin.y -= 40
                }
            }
        }

        if UIDevice.current.userInterfaceIdiom == .pad, UIDevice.current.orientation.isLandscape {
            if view.frame.origin.y == 0 {
                if tableView.numberOfSections > 0 && tableView.numberOfRows(inSection: 0) > 0 {
                    self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
                }
                self.view.frame.origin.y -= 230
            }
        }

        textField?.layer.borderColor = NCBrandColor.shared.brand.cgColor
    }

    
    @objc func keyboardWillHide(notification: Notification) {
        if view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
        textField?.layer.borderColor = NCBrandColor.shared.label.cgColor
    }

    @objc func appWillEnterForeground(notification: Notification) {
        reloadData()
    }
    
    // MARK: -
    
    @objc func reloadData() {
        guard let metadata = metadata else {
            return
        }
        shares = self.database.getTableShares(metadata: metadata)
        updateShareArrays()
        tableView.reloadData()
    }
    
    func updateShareArrays() {
        shareLinks.removeAll()
        shareEmails.removeAll()

        guard var allShares = shares.share else { return }
        allShares = allShares.sorted(by: { $0.date?.compare($1.date as Date? ?? Date()) == .orderedAscending })
        if let firstLink = shares.firstShareLink {
            // Remove if already exists to avoid duplication
            allShares.removeAll { $0.idShare == firstLink.idShare }
            allShares.insert(firstLink, at: 0)
        }

        shares.share = allShares

        for item in allShares {
            if item.shareType == NCShareCommon.shareTypeLink {
                shareLinks.append(item)
            } else {
                shareEmails.append(item)
            }
        }
    }
    
    @objc func handleFavoriteStatusChanged(notification: Notification) {
        // Retrieve the updated metadata from the notification object
        if let updatedMetadata = notification.object as? tableMetadata {
            // Update the table view header with the new metadata
            if let headerView = tableView.tableHeaderView as? NCShareAdvancePermissionHeader {
                headerView.setupUI(with: updatedMetadata, linkCount: shareLinks.count, emailCount: shareEmails.count)  // Update header UI with new metadata
            }
        }
    }

    // MARK: - IBAction

    @IBAction func searchFieldDidEndOnExit(textField: UITextField) {
//        // https://stackoverflow.com/questions/25471114/how-to-validate-an-e-mail-address-in-swift
//        func isValidEmail(_ email: String) -> Bool {
//
//            let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
//            let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
//            return emailPred.evaluate(with: email)
//        }
        guard let searchString = textField.text, !searchString.isEmpty else { return }
        if searchString.contains("@"), !isValidEmail(searchString) { return }
        networking?.getSharees(searchString: searchString)
    }
    
    @IBAction func searchFieldDidChange(textField: UITextField) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(searchSharees), object: nil)
        guard let searchString = textField.text else {return}
        if searchString.count == 0 {
            dropDown.hide()
        } else {
            perform(#selector(searchSharees), with: nil, afterDelay: 0.5)
        }
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
    
    @IBAction func createLinkClicked(_ sender: Any?) {
        appDelegate?.adjust.trackEvent(TriggerEvent(CreateLink.rawValue))
        TealiumHelper.shared.trackEvent(title: "magentacloud-app.sharing.create", data: ["": ""])
//        self.touchUpInsideButtonMenu(sender)
        self.touchUpInsideButtonMenu(sender as Any)
    }
    
    @IBAction func touchUpInsideButtonMenu(_ sender: Any) {
        
        guard let metadata = metadata else { return }
        let capabilities = NCNetworking.shared.capabilities[metadata.account] ?? NKCapabilities.Capabilities()
        let isFilesSharingPublicPasswordEnforced = capabilities.fileSharingPubPasswdEnforced
        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata)
        
        if isFilesSharingPublicPasswordEnforced && shares.firstShareLink == nil {
            let alertController = UIAlertController(title: NSLocalizedString("_enforce_password_protection_", comment: ""), message: "", preferredStyle: .alert)
            alertController.addTextField { (textField) in
                textField.isSecureTextEntry = true
            }
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { (action:UIAlertAction) in })
            let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) {[weak self] (action:UIAlertAction) in
                let password = alertController.textFields?.first?.text
                self?.networking?.createShareLink(password: password ?? "")
            }
            
            alertController.addAction(okAction)
            
            present(alertController, animated: true, completion:nil)
        } else if shares.firstShareLink == nil {
            networking?.createShareLink(password: "")

        } else {
            networking?.createShareLink(password: "")
        }
        
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
//        self.view.endEditing(true)

        dropDown = DropDown()
        let appearance = DropDown.appearance()

//        // Setting up the blur effect
//        let blurEffect = UIBlurEffect(style: .light) // You can choose .dark, .extraLight, or .light
//        let blurEffectView = UIVisualEffectView(effect: blurEffect)
//        blurEffectView.frame = CGRect(x: 0, y: 0, width: 500, height: 20)

        appearance.backgroundColor = .systemBackground
        appearance.cornerRadius = 10
        appearance.shadowColor = .black
        appearance.shadowOpacity = 0.2
        appearance.shadowRadius = 30
        appearance.animationduration = 0.25
        appearance.textColor = NCBrandColor.shared.label
        appearance.setupMaskedCorners([.layerMaxXMaxYCorner, .layerMinXMaxYCorner])

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

        dropDown.anchorView = textField
        dropDown.bottomOffset = CGPoint(x: 10, y: textField?.bounds.height ?? 0)
        dropDown.width = (textField?.bounds.width ?? 0) - 20
        dropDown.direction = .bottom

        dropDown.cellNib = UINib(nibName: "NCSearchUserDropDownCell", bundle: nil)
        dropDown.customCellConfiguration = { (index: Index, _, cell: DropDownCell) in
            guard let cell = cell as? NCSearchUserDropDownCell else { return }
            let sharee = sharees[index]
            cell.setupCell(sharee: sharee, session: self.session)
        }

        dropDown.selectionAction = { index, _ in
            self.textField?.text = ""
            self.textField?.resignFirstResponder()
            let sharee = sharees[index]
            guard
                let advancePermission = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "NCShareAdvancePermission") as? NCShareAdvancePermission,
                let navigationController = self.navigationController else { return }
            self.checkEnforcedPassword(shareType: sharee.shareType) { password in
                let shareOptions = TransientShare(sharee: sharee, metadata: self.metadata, password: password)
                if !shareOptions.shareWithDisplayname.isEmpty {
                    shareOptions.shareWithDisplayname = shareOptions.shareWithDisplayname
                } else {
                    shareOptions.shareWithDisplayname = sharee.label
                }
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
        guard let sectionType = ShareSection(rawValue: indexPath.section) else { return 0 }

        switch sectionType {
        case .header:
            return 210

        case .linkByEmail:
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            if isCurrentUser {
                return 130
            } else {
                return isPad ? (canReshare ? 200 : 220) : 220
            }

        case .links, .emails:
            return 60
        }
    }

}

// MARK: - UITableViewDataSource

extension NCShare: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        ShareSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = ShareSection(rawValue: section) else { return 0 }

        switch sectionType {
        case .header:
            return 0
        case .linkByEmail:
            return 1
        case .links:
            return shareLinks.count
        case .emails:
            return shareEmails.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = ShareSection(rawValue: indexPath.section) else { return UITableViewCell() }

        switch sectionType {
        case .header:
            return UITableViewCell() // Empty row
        case .linkByEmail:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "NCShareEmailFieldCell", for: indexPath) as? NCShareEmailFieldCell else {
                return UITableViewCell()
            }
            cell.searchField.addTarget(self, action: #selector(searchFieldDidEndOnExit(textField:)), for: .editingDidEndOnExit)
            cell.searchField.addTarget(self, action: #selector(searchFieldDidChange(textField:)), for: .editingChanged)
            cell.btnContact.addTarget(self, action: #selector(selectContactClicked(_:)), for: .touchUpInside)
            cell.setupCell(with: metadata)
            return cell

        case .links:
            let tableShare = shareLinks[indexPath.row]
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "cellLink", for: indexPath) as? NCShareLinkCell else {
                return UITableViewCell()
            }
            cell.delegate = self
            if indexPath.row == 0 {
                cell.configure(with: tableShare, at: indexPath, isDirectory: metadata.directory, title: "")
            } else {
                let linkNumber = " \(indexPath.row + 1)"
                cell.configure(with: tableShare, at: indexPath, isDirectory: metadata.directory, title: linkNumber)
            }
            return cell

        case .emails:
            let tableShare = shareEmails[indexPath.row]
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "cellUser", for: indexPath) as? NCShareUserCell else {
                return UITableViewCell()
            }
            cell.delegate = self
            cell.configure(with: tableShare, at: indexPath, isDirectory: metadata.directory, userId: session.userId)
            return cell
        }
    }

    func numberOfRows(in section: Int) -> Int {
        return tableView(tableView, numberOfRowsInSection: section)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionType = ShareSection(rawValue: section) else { return nil }

        switch sectionType {
        case .header:
            let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: NCShareAdvancePermissionHeader.reuseIdentifier) as? NCShareAdvancePermissionHeader
            headerView?.ocId = metadata.ocId
            headerView?.setupUI(with: metadata, linkCount: shareLinks.count, emailCount: shareEmails.count)
            return headerView

        case .linkByEmail:
            return nil
            
        case .links:
            if isCurrentUser || canReshare {
                let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "NCShareEmailLinkHeaderView") as? NCShareEmailLinkHeaderView
                headerView?.configure(text: NSLocalizedString("_share_copy_link_", comment: "123"))
                return headerView
            }
            return nil

        case .emails:
            if (isCurrentUser || canReshare) && numberOfRows(in: section) > 0 {
                let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "NCShareEmailLinkHeaderView") as? NCShareEmailLinkHeaderView
                headerView?.configure(text: NSLocalizedString("_share_shared_with_", comment: ""))
                return headerView
            }
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sectionType = ShareSection(rawValue: section) else { return 0 }

        switch sectionType {
        case .header:
            return 190
        case .linkByEmail:
            return 0
        case .links:
            return (isCurrentUser || canReshare) ? 44 : 0
        case .emails:
            return ((isCurrentUser || canReshare) && numberOfRows(in: section) > 0) ? 44 : 0
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard isCurrentUser || canReshare,
              let sectionType = ShareSection(rawValue: section) else {
            return nil
        }

        switch sectionType {
        case .links:
            let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: CreateLinkFooterView.reuseIdentifier) as? CreateLinkFooterView
            footer?.createButtonAction = { [weak self] in
                self?.createLinkClicked(nil)
            }
            return footer
            
        case .emails:
            if numberOfRows(in: section) == 0 {
                return tableView.dequeueReusableHeaderFooterView(withIdentifier: NoSharesFooterView.reuseIdentifier)
            }
            return nil
        case .header, .linkByEmail:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard isCurrentUser || canReshare,
              let sectionType = ShareSection(rawValue: section) else {
            return 0.001
        }

        switch sectionType {
        case .links:
            return 80
        case .emails:
            return numberOfRows(in: section) == 0 ? 100 : 80
        case .header, .linkByEmail:
            return 0.001
        }
    }

}


// MARK: - CNContactPickerDelegate

extension NCShare: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        if  contact.emailAddresses.count > 1 {
            showEmailList(arrEmail: contact.emailAddresses.map({$0.value as String}), sender: picker)
        } else if let email = contact.emailAddresses.first?.value as? String {
            textField?.text = email
            networking?.getSharees(searchString: email)
        }
    }

    func showEmailList(arrEmail: [String], sender: Any?) {
        var actions = [NCMenuAction]()
        for email in arrEmail {
            actions.append(
                NCMenuAction(
                    title: email,
                    icon: utility.loadImage(named: "email", colors: [NCBrandColor.shared.iconImageColor]),
                    selected: false,
                    on: false,
                    sender: sender,
                    action: { _ in
                        self.textField?.text = email
                        self.networking?.getSharees(searchString: email)
                    }
                )
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.presentMenu(with: actions, sender: sender)
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
            perform(#selector(searchSharees(_:)), with: nil, afterDelay: 0.5)
        }
    }

    @objc private func searchSharees(_ sender: Any?) {
//        // https://stackoverflow.com/questions/25471114/how-to-validate-an-e-mail-address-in-swift
//        func isValidEmail(_ email: String) -> Bool {
//
//            let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
//            let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
//            return emailPred.evaluate(with: email)
//        }
//        guard let searchString = textField?.text, !searchString.isEmpty else { return }
        guard let searchString = textField?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !searchString.isEmpty else { return }
//        guard let searchString = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !searchString.isEmpty else { return }
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
