// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import UIKit

///
/// View controller for the table view managing the input form for download limits.
///
/// This view controller does not interfere with persistent data by itself but only handles an injected transient model and returns whatever final choice the user makes.
/// Persistence of the transient model depends on higher level choices up in the view controller hierarchy and is out of scope here.
///
/// This child view controller is required because table views require a dedicated table view controller.
///
class NCShareDownloadLimitTableViewController: UITableViewController {
    let database = NCManageDatabase.shared

    ///
    /// The delegate to inform about changes in the download limit.
    ///
    public weak var delegate: NCShareDownloadLimitTableViewControllerDelegate?

    ///
    /// The initial state injected from the parent view controller on appearance.
    ///
    public var downloadLimit: DownloadLimitViewModel!
    public var metadata: tableMetadata!
    public var share: Shareable!

    ///
    /// Default value for limits as possibly provided by the server capabilities.
    ///
    var defaultLimit: Int {
        NCCapabilities.shared.getCapabilities(account: metadata.account).capabilityFileSharingDownloadLimitDefaultLimit
    }

    @IBOutlet var limitSwitch: UISwitch!
    @IBOutlet var limitTextField: UITextField!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if case let .limited(limit, _) = downloadLimit {
            limitSwitch.isOn = true
            limitTextField.text = "\(limit)"
        } else {
            limitSwitch.isOn = false
        }
    }

    @IBAction func switchDownloadLimit(_ sender: UISwitch) {
        if sender.isOn {
            downloadLimit = .limited(limit: defaultLimit, count: 0)
            limitTextField.text = String(defaultLimit)
        } else {
            downloadLimit = .unlimited
        }

        tableView.reloadData()
        delegate?.didSetDownloadLimit(downloadLimit)
    }

    @IBAction func editingAllowedDownloadsDidBegin(_ sender: UITextField) {
        // The UITextField might not be the first responder yet, breaking this.
        // To circumvent this problem, the selection is deferred a bit.
        // This is necessary due to the scenario of the UITextField being an accessory view.
        DispatchQueue.main.async {
            sender.selectAll(sender)
        }
    }

    @IBAction func editingAllowedDownloadsDidEnd(_ sender: UITextField) {
        guard let text = sender.text else {
            return
        }

        if let enteredValue = Int(text) {
            downloadLimit = .limited(limit: enteredValue, count: 0)
        } else {
            downloadLimit = .limited(limit: defaultLimit, count: 0)
            limitTextField.text = String(defaultLimit)
        }

        tableView.reloadData()
        delegate?.didSetDownloadLimit(downloadLimit)

        sender.selectedTextRange = nil
    }
}

// MARK: - UITableViewDataSource

extension NCShareDownloadLimitTableViewController {
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if case let .limited(limit, count) = downloadLimit {
            String(format: NSLocalizedString("_remaining_share_downloads_", comment: "Table footer for download limit configuration form."), limit - count)
        } else {
            nil
        }
    }
}

// MARK: - UITableViewDelegate

extension NCShareDownloadLimitTableViewController {
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
}
