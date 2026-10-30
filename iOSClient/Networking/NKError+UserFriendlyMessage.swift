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

    private var isVirusDetected: Bool {
        let global = NCGlobal.shared
        let isRejectedUpload = errorCode == global.errorBadRequest || errorCode == global.errorUnsupportedMediaType

        return isRejectedUpload && errorDescription.localizedCaseInsensitiveContains("virus")
    }

    /// Unique cases that require a specific non-generic error
    private func operationMessage(for context: NCErrorContext, kind: Kind) -> String? {
        switch (context, kind) {
        case (.upload, .unknown) where isVirusDetected:
            return NSLocalizedString("_virus_detect_", comment: "")

        case (.upload, .conflict) where errorCode == NCGlobal.shared.errorConflict:
            return NSLocalizedString("_error_upload_no_folder_", comment: "")

        case (.createFolder, .conflict):
            return NSLocalizedString("_error_create_folder_no_parent_", comment: "")

        case (.createDocument, .forbidden):
            return NSLocalizedString("_error_create_document_", comment: "")

        case (.openDocument, .forbidden):
            return NSLocalizedString("_error_open_document_", comment: "")

        case (.login, .unauthorized), (.login, .forbidden):
            return NSLocalizedString("_error_login_credentials_", comment: "")

        default:
            return nil
        }
    }
}
