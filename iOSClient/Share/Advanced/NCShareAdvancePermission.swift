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
import NCCommunication
import SVGKit
import CloudKit

class NCShareAdvancePermission: UITableViewController, NCShareAdvanceFotterDelegate, NCShareDetail {
    func dismissShareAdvanceView(shouldSave: Bool) {
        defer { navigationController?.popViewController(animated: true) }
        guard shouldSave else { return }
        if isNewShare {
            networking?.createShare(option: share)
        } else {
            networking?.updateShare(option: share)
        }
    }

    var share: NCTableShareable!
    var isNewShare: Bool { NCManageDatabase.shared.getTableShare(account: share.account, idShare: share.idShare) == nil }
    var metadata: tableMetadata!
    var shareConfig: NCShareConfig!
    var networking: NCShareNetworking?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.shareConfig = NCShareConfig(isDirectory: metadata.directory, share: share)
        self.setNavigationTitle()
        if #available(iOS 13.0, *) {
            // disbale pull to dimiss
            isModalInPresentation = true
        }
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
        container.backgroundColor = .blue
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

        headerView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 200)
        tableView.tableHeaderView = headerView
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        headerView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor).isActive = true
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return NSLocalizedString("_advanced_", comment: "")
        } else if section == 1 {
            return NSLocalizedString("_misc_", comment: "")
        } else { return nil }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return shareConfig.permissions.count
        } else if section == 1 {
            return shareConfig.advanced.count
        } else { return 0 }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = shareConfig.cellFor(indexPath: indexPath) else { return UITableViewCell() }
        if let cell = cell as? NCShareDateCell {
            cell.onReload = tableView.reloadData
        }
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
        case .password:
            guard share.password.isEmpty else {
                share.password = ""
                tableView.reloadData()
                return
            }
            let alertController = UIAlertController.withTextField(titleKey: "_enforce_password_protection_") { textField in
                textField.placeholder = NSLocalizedString("_password_", comment: "")
                textField.isSecureTextEntry = true
            } completion: { password in
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
