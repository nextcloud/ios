// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// A data model solely for the use in the download limit user interface.
///
enum DownloadLimitViewModel {
    ///
    /// Download limit is disabled.
    ///
    case unlimited

    ///
    /// Download limit is enabled.
    ///
    /// - Parameters:
    ///     - limit: The maximum allowed downloads.
    ///     - count: The current number of downloads already used.
    ///
    case limited(limit: Int, count: Int)
}
