//
//  NCShareAdvancePermission.swift
//  Nextcloud
//
//  Created by T-systems on 09/08/21.
//  Copyright © 2022 Henrik Storch. All rights reserved.
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
//

import UIKit
import NextcloudKit
import SVGKit
import CloudKit

class NCShareAdvancePermission: UITableViewController, NCShareAdvanceFotterDelegate, NCShareNavigationTitleSetting {
    let database = NCManageDatabase.shared

    var oldTableShare: tableShare?

    ///
    /// View model for the share link user interface.
    ///
    var share: (any Shareable)!

    ///
    /// Determining whether the currently represented share is new based on its concrete type.
    ///
    var isNewShare: Bool { share is TransientShare }

    ///
    /// The subject to share.
    ///
    var metadata: tableMetadata!

    ///
    /// The possible download limit associated with this share.
    ///
    /// This can only be created after the share has been actually created due to its requirement of the share token provided by the server.
    ///
    var downloadLimit: DownloadLimitViewModel = .unlimited

    var shareConfig: NCShareConfig!
    var networking: NCShareNetworking?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.shareConfig = NCShareConfig(parentMetadata: metadata, share: share)

        // Only persisted shares have tokens which are provided by the server.
        // A download limit requires a token to exist.
        // Hence it can only be looked up if the share is already persisted at this point.
        if isNewShare == false {
            if let persistedShare = share as? tableShare {
                do {
                    if let limit = try database.getDownloadLimit(byAccount: metadata.account, shareToken: persistedShare.token) {
                        self.downloadLimit = .limited(limit: limit.limit, count: limit.count)
                    }
                } catch {
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] There was an error while fetching the download limit for share with token \(persistedShare.token)!")
                }
            }
        }

        tableView.estimatedRowHeight = tableView.rowHeight
        tableView.rowHeight = UITableView.automaticDimension
        self.setNavigationTitle()
        self.navigationItem.hidesBackButton = true
        // disable pull to dimiss
        isModalInPresentation = true
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard tableView.tableHeaderView == nil, tableView.tableFooterView == nil else { return }
        setupHeaderView()
        setupFooterView()
    }

    func setupFooterView() {
        guard let footerView = (Bundle.main.loadNibNamed("NCShareAdvancePermissionFooter", owner: self, options: nil)?.first as? NCShareAdvancePermissionFooter) else { return }
        footerView.setupUI(delegate: self, account: metadata.account)

        // tableFooterView can't use auto layout directly
        let container = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 120))
        container.addSubview(footerView)
        tableView.tableFooterView = container
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        footerView.heightAnchor.constraint(equalTo: container.heightAnchor).isActive = true
        footerView.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
    }

    func setupHeaderView() {
        guard let headerView = (Bundle.main.loadNibNamed("NCShareHeader", owner: self, options: nil)?.first as? NCShareHeader) else { return }
        headerView.setupUI(with: metadata)

        let container = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 220))
        container.addSubview(headerView)
        tableView.tableHeaderView = container
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        headerView.heightAnchor.constraint(equalTo: container.heightAnchor).isActive = true
        headerView.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return NSLocalizedString("_custom_permissions_", comment: "")
        } else if section == 1 {
            return NSLocalizedString("_advanced_", comment: "")
        } else { return nil }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            // check reshare permission, if restricted add note
            let maxPermission = metadata.directory ? NCPermissions().permissionMaxFolderShare : NCPermissions().permissionMaxFileShare
            return shareConfig.sharePermission != maxPermission ? shareConfig.permissions.count + 1 : shareConfig.permissions.count
        } else if section == 1 {
            return shareConfig.advanced.count
        } else { return 0 }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = shareConfig.cellFor(indexPath: indexPath) else {
            let noteCell = UITableViewCell(style: .subtitle, reuseIdentifier: "noteCell")
            noteCell.detailTextLabel?.text = NSLocalizedString("_share_reshare_restricted_", comment: "")
            noteCell.detailTextLabel?.isEnabled = false
            noteCell.isUserInteractionEnabled = false
            noteCell.detailTextLabel?.numberOfLines = 0
            return noteCell
        }
        if let cell = cell as? NCShareDateCell { cell.onReload = tableView.reloadData }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cellConfig = shareConfig.config(for: indexPath) else { return }
        guard let cellConfig = cellConfig as? NCAdvancedPermission else {
            cellConfig.didSelect(for: share)
            tableView.reloadData()
            return
        }

        switch cellConfig {
        case .limitDownload:
            let storyboard = UIStoryboard(name: "NCShare", bundle: nil)
            guard let viewController = storyboard.instantiateViewController(withIdentifier: "NCShareDownloadLimit") as? NCShareDownloadLimitViewController else { return }
            viewController.downloadLimit = self.downloadLimit
            viewController.metadata = self.metadata
            viewController.share = self.share
            viewController.shareDownloadLimitTableViewControllerDelegate = self
            viewController.onDismiss = tableView.reloadData
            self.navigationController?.pushViewController(viewController, animated: true)
        case .hideDownload:
            share.hideDownload.toggle()
            tableView.reloadData()
        case .expirationDate:
            let cell = tableView.cellForRow(at: indexPath) as? NCShareDateCell
            cell?.textField.becomeFirstResponder()
            cell?.checkMaximumDate(account: metadata.account)
        case .password:
            guard share.password.isEmpty else {
                share.password = ""
                tableView.reloadData()
                return
            }
            let alertController = UIAlertController.password(titleKey: "_share_password_") { password in
                self.share.password = password ?? ""
                tableView.reloadData()
            }
            self.present(alertController, animated: true)
        case .note:
            let storyboard = UIStoryboard(name: "NCShare", bundle: nil)
            guard let viewNewUserComment = storyboard.instantiateViewController(withIdentifier: "NCShareNewUserAddComment") as? NCShareNewUserAddComment else { return }
            viewNewUserComment.metadata = self.metadata
            viewNewUserComment.share = self.share
            viewNewUserComment.onDismiss = tableView.reloadData
            self.navigationController?.pushViewController(viewNewUserComment, animated: true)
        case .label:
            let alertController = UIAlertController.withTextField(titleKey: "_share_link_name_") { textField in
                textField.placeholder = cellConfig.title
                textField.text = self.share.label
            } completion: { newValue in
                self.share.label = newValue ?? ""
                self.setNavigationTitle()
                tableView.reloadData()
            }
            self.present(alertController, animated: true)
        case .downloadAndSync:
            share.downloadAndSync.toggle()
            tableView.reloadData()
        }
    }

    func dismissShareAdvanceView(shouldSave: Bool) {
        guard shouldSave else {
            guard oldTableShare?.hasChanges(comparedTo: share) != false else {
                navigationController?.popViewController(animated: true)
                return
            }

            let alert = UIAlertController(
                title: NSLocalizedString("_cancel_request_", comment: ""),
                message: NSLocalizedString("_discard_changes_info_", comment: ""),
                preferredStyle: .alert)

            alert.addAction(UIAlertAction(
                title: NSLocalizedString("_discard_changes_", comment: ""),
                style: .destructive,
                handler: { _ in self.navigationController?.popViewController(animated: true) }))

            alert.addAction(UIAlertAction(title: NSLocalizedString("_continue_editing_", comment: ""), style: .default))
            self.present(alert, animated: true)

            return
        }

        Task {
            if (share.shareType == NCShareCommon().SHARE_TYPE_LINK || share.shareType == NCShareCommon().SHARE_TYPE_EMAIL) && NCPermissions().isPermissionToCanShare(share.permissions) {
                share.permissions = share.permissions - NCPermissions().permissionShareShare
            }

            if isNewShare {
                let serverUrl = metadata.serverUrl + "/" + metadata.fileName

                if share.shareType != NCShareCommon().SHARE_TYPE_LINK, metadata.e2eEncrypted,
                   NCCapabilities.shared.getCapabilities(account: metadata.account).capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {

                    if NCNetworkingE2EE().isInUpload(account: metadata.account, serverUrl: serverUrl) {
                        let error = NKError(errorCode: NCGlobal.shared.errorE2EEUploadInProgress, errorDescription: NSLocalizedString("_e2e_in_upload_", comment: ""))
                        return NCContentPresenter().showInfo(error: error)
                    }

                    let error = await NCNetworkingE2EE().uploadMetadata(serverUrl: serverUrl, addUserId: share.shareWith, removeUserId: nil, account: metadata.account)

                    if error != .success {
                        return NCContentPresenter().showError(error: error)
                    }
                }

                networking?.createShare(share, downloadLimit: self.downloadLimit)
            } else {
                networking?.updateShare(share, downloadLimit: self.downloadLimit)
            }
        }

        navigationController?.popViewController(animated: true)
    }
}

// MARK: - NCShareDownloadLimitTableViewControllerDelegate

extension NCShareAdvancePermission: NCShareDownloadLimitTableViewControllerDelegate {
    func didSetDownloadLimit(_ downloadLimit: DownloadLimitViewModel) {
        self.downloadLimit = downloadLimit
    }
}
