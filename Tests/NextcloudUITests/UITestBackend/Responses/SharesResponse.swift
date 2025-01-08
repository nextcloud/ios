// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// Partial information about a share as returned by the OCS API of the `files_sharing` server app.
///
struct ShareResponse: Decodable {
    let token: String
}
