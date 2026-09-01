// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

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

    /// A non-sensitive value suitable for diagnostics. Never include key material here.
    var diagnosticDescription: String {
        switch self {
        case .active:
            return "active"
        case .archived:
            return "archived"
        case .unavailable:
            return "unavailable"
        }
    }

    /// A write is allowed only when the active key set decrypts the storage space.
    var writeAccessError: NKError {
        switch self {
        case .active:
            return .success
        case .archived:
            return NKError(
                errorCode: NCGlobal.shared.errorE2EEReadOnly,
                errorDescription: NSLocalizedString("_e2ee_read_only_", comment: "")
            )
        case .unavailable:
            return NKError(
                errorCode: NCGlobal.shared.errorE2EENoUserFound,
                errorDescription: NSLocalizedString("_e2ee_no_metadataKey_found_", comment: "")
            )
        }
    }
}
