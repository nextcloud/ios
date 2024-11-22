// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import UIKit

///
/// View controller for the table view managing the input form for download limits.
///
/// This child view controller is required because table views require a dedicated table view controller.
///
class NCShareDownloadLimitTableViewController: UITableViewController {
    let database = NCManageDatabase.shared

    ///
    /// The initial state injected from the parent view controller on appearance.
    ///
    public var initialDownloadLimit: tableDownloadLimit?
    public var metadata: tableMetadata!
    public var share: NCTableShareable!

    ///
    /// Default value for limits as possibly provided by the server capabilities.
    ///
    var defaultLimit: Int {
        NCCapabilities.shared.getCapabilities(account: metadata.account).capabilityFileSharingDownloadLimitDefaultLimit
    }

    ///
    /// Share token required to work with download limits.
    ///
    private var token: String!

    ///
    /// The final state to apply once the view is about to disappear.
    ///
    private var finalDownloadLimit: tableDownloadLimit?

    private var networking: NCShareDownloadLimitNetworking!

    @IBOutlet var limitSwitch: UISwitch!
    @IBOutlet var limitTextField: UITextField!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let initialDownloadLimit {
            limitSwitch.isOn = true
            limitTextField.text = "\(initialDownloadLimit.limit)"

            finalDownloadLimit = tableDownloadLimit()
            finalDownloadLimit?.count = initialDownloadLimit.count
            finalDownloadLimit?.limit = initialDownloadLimit.limit
            finalDownloadLimit?.token = initialDownloadLimit.token
        } else {
            limitSwitch.isOn = false
        }

        if let token = self.database.getTableShare(account: metadata.account, idShare: share.idShare)?.token {
            self.token = token
        } else {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Failed to resolve share token!")
            self.token = ""
        }

        networking = NCShareDownloadLimitNetworking(account: metadata.account, delegate: self, token: token)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row == 1 else {
            super.tableView(tableView, didSelectRowAt: indexPath)
            return
        }

        // The accessory text field should become first responder regardless where the user tapped in the table row.
        limitTextField.becomeFirstResponder()
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Programmatically hide the limit input row depending on limit enablement.
        if limitSwitch.isOn == false && indexPath.row == 1 {
            return 0
        }

        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if let finalDownloadLimit {
            String(format: NSLocalizedString("_remaining_share_downloads_", comment: "Table footer text for form of configuring download limits."), finalDownloadLimit.limit - finalDownloadLimit.count)
        } else {
            nil
        }
    }

    @IBAction func switchDownloadLimit(_ sender: UISwitch) {
        if sender.isOn {
            finalDownloadLimit = tableDownloadLimit()
            finalDownloadLimit?.count = 0
            finalDownloadLimit?.limit = defaultLimit
            finalDownloadLimit?.token = token

            limitTextField.text = String(defaultLimit)
        } else {
            finalDownloadLimit = nil
        }

        tableView.reloadData()
        dispatchShareDownloadLimitUpdate()
    }

    @IBAction func editingAllowedDownloadsDidBegin(_ sender: UITextField) {
        sender.selectAll(nil)
    }
    
    @IBAction func editingAllowedDownloadsDidEnd(_ sender: UITextField) {
        finalDownloadLimit?.limit = Int(sender.text ?? "1") ?? defaultLimit
        finalDownloadLimit?.count = 0

        tableView.reloadData()
        dispatchShareDownloadLimitUpdate()
    }

    func dispatchShareDownloadLimitUpdate() {
        guard let text = limitTextField.text else {
            return
        }

        guard let limit = Int(text) else {
            return
        }

        if limitSwitch.isOn {
            networking.setShareDownloadLimit(limit: limit)
        } else {
            networking.removeShareDownloadLimit()
        }
    }
}

// MARK: - NCShareDownloadLimitNetworkingDelegate

extension NCShareDownloadLimitTableViewController: NCShareDownloadLimitNetworkingDelegate {
    func downloadLimitRemoved(by token: String, in account: String) {
        do {
            try self.database.deleteDownloadLimit(byShareToken: token)
        } catch {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Failed to delete download limit in database!")
        }
    }

    func downloadLimitSet(to limit: Int, by token: String, in account: String) {
        do {
            try self.database.createDownloadLimit(count: 0, limit: limit, token: token)
        } catch {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Failed to create download limit in database!")
        }
    }
}
