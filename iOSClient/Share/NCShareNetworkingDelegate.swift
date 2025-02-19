// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

///
/// Delegate requirements for ``NCShareNetworking`` to handle results.
///
protocol NCShareNetworkingDelegate: AnyObject {
    func readShareCompleted()
    func shareCompleted()
    func unShareCompleted()
    func updateShareWithError(idShare: Int)
    func getSharees(sharees: [NKSharee]?)

    // MARK: - Download Limit

    ///
    /// The download limit was successfully removed from the share on the server.
    ///
    func downloadLimitRemoved(by token: String)

    ///
    /// The download limit was successfully removed from the share on the server.
    ///
    func downloadLimitSet(to limit: Int, by token: String)
}
