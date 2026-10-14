// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A collective as returned by the Collectives app OCS API.
struct NCCollective: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let emoji: String?
    let canEdit: Bool
}
