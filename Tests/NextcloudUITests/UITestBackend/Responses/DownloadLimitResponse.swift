// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// Partial information about a download limit as returned by the OCS API of the `files_downloadlimit` server app.
///
struct DownloadLimitResponse: Decodable {
    let count: Int?
    let limit: Int?
}
