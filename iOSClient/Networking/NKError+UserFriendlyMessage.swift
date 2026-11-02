// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

extension NKError {
    /// The message to show users for this error, or `nil` when nothing should be shown (success or cancellation).
    ///
    /// Tries the app's own text, then the few operations where the generic message would be wrong, then
    /// NextcloudKit's generic message. Keep `errorDescription` for logs.
    func userFriendlyMessage(for context: NCErrorContext = .generic) -> String? {
        guard let kind, kind != .cancelled, errorCode != NCGlobal.shared.errorTaskCancelled else { return nil }

        if let appMessage {
            return appMessage
        }

        if let operationMessage = operationMessage(for: context, kind: kind) {
            return operationMessage
        }

        return localizedGenericMessage
    }

    /// Text the app wrote itself: a localization key, or the description of one of its own error codes.
    private var appMessage: String? {
        let localized = NSLocalizedString(errorDescription, comment: "")

        if localized != errorDescription {
            return localized
        }

        let global = NCGlobal.shared
        let isAppError = (global.errorInternalError...global.errorE2EENotEnabled).contains(errorCode)

        return isAppError && !errorDescription.isEmpty ? errorDescription : nil
    }

    /// Unique cases that require a specific non-generic error
    private func operationMessage(for context: NCErrorContext, kind: Kind) -> String? {
        switch (context, kind) {
        // Direct editing answers every failure with 403, so "no permission" isn't reliable there.
        case (.createDocument, .forbidden), (.openDocument, .forbidden):
            return NSLocalizedString("_error_occurred_", comment: "")

        default:
            return nil
        }
    }
}
