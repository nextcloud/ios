// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

///
/// View controller for the download limit detail view in share details.
///
class NCShareDownloadLimitViewController: UIViewController, NCShareNavigationTitleSetting {
    public var downloadLimit: DownloadLimitViewModel = .unlimited
    public var metadata: tableMetadata!
    public var onDismiss: (() -> Void)?
    public var share: Shareable!
    public var shareDownloadLimitTableViewControllerDelegate: NCShareDownloadLimitTableViewControllerDelegate?

    @IBOutlet var headerContainerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setNavigationTitle()

        // Set up header view.

        guard let headerView = (Bundle.main.loadNibNamed("NCShareHeader", owner: self, options: nil)?.first as? NCShareHeader) else { return }
        headerContainerView.addSubview(headerView)
        headerView.frame = headerContainerView.frame
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.topAnchor.constraint(equalTo: headerContainerView.topAnchor).isActive = true
        headerView.bottomAnchor.constraint(equalTo: headerContainerView.bottomAnchor).isActive = true
        headerView.leftAnchor.constraint(equalTo: headerContainerView.leftAnchor).isActive = true
        headerView.rightAnchor.constraint(equalTo: headerContainerView.rightAnchor).isActive = true

        headerView.setupUI(with: metadata)

        // End editing of inputs when the user taps anywhere else.

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        view.addGestureRecognizer(tapGesture)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let tableViewController = segue.destination as? NCShareDownloadLimitTableViewController else {
            return
        }

        tableViewController.delegate = shareDownloadLimitTableViewControllerDelegate
        tableViewController.downloadLimit = downloadLimit
        tableViewController.metadata = metadata
        tableViewController.share = share
    }

    @objc private func dismissKeyboard(_ sender: Any?) {
        view.endEditing(true)
    }
}
