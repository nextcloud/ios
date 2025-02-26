// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// The ``NCShareDownloadLimitTableViewController`` needs to inform another object about changes in the download limit configuration.
///
protocol NCShareDownloadLimitTableViewControllerDelegate: AnyObject {
    ///
    /// Called for every change in regard to the download limit.
    ///
    /// Changes may be:
    ///
    /// * Enabing a download limit on a share.
    /// * Disabling a download limit on a share.
    /// * Changing the number of allowed downloads.
    ///
    func didSetDownloadLimit(_ downloadLimit: DownloadLimitViewModel)
}
