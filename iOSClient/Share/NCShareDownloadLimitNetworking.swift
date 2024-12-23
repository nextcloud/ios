// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

///
/// Delegate requirements for ``NCShareDownloadLimitNetworking`` to handle results.
///
protocol NCShareDownloadLimitNetworkingDelegate: AnyObject {
    ///
    /// The download limit was successfully removed from the share on the server.
    ///
    func downloadLimitRemoved(by token: String, in account: String)

    ///
    /// The download limit was successfully removed from the share on the server.
    ///
    func downloadLimitSet(to limit: Int, by token: String, in account: String)
}

///
/// Share-bound network abstraction for download limits.
///
class NCShareDownloadLimitNetworking: NSObject {
    let account: String
    weak var delegate: (any NCShareDownloadLimitNetworkingDelegate)?
    weak var view: UIView?
    let token: String

    init(account: String, delegate: (any NCShareDownloadLimitNetworkingDelegate)?, token: String) {
        self.account = account
        self.delegate = delegate
        self.token = token
    }

    ///
    /// Remove the download limit on the share, if existent.
    ///
    func removeShareDownloadLimit() {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.removeShareDownloadLimit(account: account, token: token) { error in
            NCActivityIndicator.shared.stop()

            if error == .success {
                self.delegate?.downloadLimitRemoved(by: self.token, in: self.account)
            } else {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    ///
    /// Set the download limit for the share.
    ///
    /// - Parameter limit: The new download limit to set.
    ///
    func setShareDownloadLimit(limit: Int) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.setShareDownloadLimit(account: account, token: token, limit: limit) { error in
            NCActivityIndicator.shared.stop()

            if error == .success {
                self.delegate?.downloadLimitSet(to: limit, by: self.token, in: self.account)
            } else {
                NCContentPresenter().showError(error: error)
            }
        }
    }
}
