// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Describes which local E2EE key set can read an encrypted storage space.
enum NCEndToEndKeySetAccess: Equatable, Sendable {
    case active(NCEndToEndKeySet)
    case archived(NCEndToEndKeySet)
    case unavailable

    var keySet: NCEndToEndKeySet? {
        switch self {
        case .active(let keySet), .archived(let keySet):
            return keySet
        case .unavailable:
            return nil
        }
    }

    var canWrite: Bool {
        if case .active = self {
            return true
        }
        return false
    }

    var isReadOnly: Bool {
        if case .archived = self {
            return true
        }
        return false
    }
}
