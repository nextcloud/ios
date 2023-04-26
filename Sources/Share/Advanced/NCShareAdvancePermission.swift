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

class NCShareAdvancePermission: UITableViewController, NCShareAdvanceFotterDelegate, NCShareDetail {
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
        if isNewShare {
            networking?.createShare(option: share)
        } else {
            networking?.updateShare(option: share)
        }
        navigationController?.popViewController(animated: true)
    }

    var oldTableShare: tableShare?
    var share: NCTableShareable!
    var isNewShare: Bool { share is NCTableShareOptions }
    var metadata: tableMetadata!
    var shareConfig: NCShareConfig!
    var networking: NCShareNetworking?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.shareConfig = NCShareConfig(parentMetadata: metadata, share: share)

        tableView.estimatedRowHeight = tableView.rowHeight
        tableView.rowHeight = UITableView.automaticDimension
        self.setNavigationTitle()
        self.navigationItem.hidesBackButton = true
        // disbale pull to dimiss
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
        footerView.setupUI(delegate: self)

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
        guard let headerView = (Bundle.main.loadNibNamed("NCShareAdvancePermissionHeader", owner: self, options: nil)?.first as? NCShareAdvancePermissionHeader) else { return }
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
            return NSLocalizedString("_permissions_", comment: "")
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
            let maxPermission = metadata.directory ? NCGlobal.shared.permissionMaxFolderShare : NCGlobal.shared.permissionMaxFileShare
            return shareConfig.resharePermission != maxPermission ? shareConfig.permissions.count + 1 : shareConfig.permissions.count
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
        guard let cellConfig = cellConfig as? NCShareDetails else {
            cellConfig.didSelect(for: share)
            tableView.reloadData()
            return
        }

        switch cellConfig {
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
        }
    }
}
