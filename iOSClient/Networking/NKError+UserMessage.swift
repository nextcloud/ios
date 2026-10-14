// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

extension NKError {
    /// The message to show people for this error, or `nil` when nothing should be shown (success or cancellation).
    ///
    /// Tries the app's own text, the server's message when Nextcloud wrote it for people, a message for what was
    /// being done, then one for the kind of failure. Keep `errorDescription` for logs.
    func userMessage(for context: NCErrorContext = .generic) -> String? {
        guard let kind, kind != .cancelled, errorCode != NCGlobal.shared.errorTaskCancelled else { return nil }

        if let appMessage {
            return appMessage
        }

        if let userFacingServerMessage {
            return userFacingServerMessage
        }

        return contextMessage(for: context, kind: kind) ?? kindMessage(for: kind)
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

    private func contextMessage(for context: NCErrorContext, kind: Kind) -> String? {
        switch (context, kind) {
        case (.upload, .unknown) where isVirusDetected:
            return NSLocalizedString("_virus_detect_", comment: "")

        case (.upload, .forbidden), (.createFolder, .forbidden):
            return NSLocalizedString("_no_file_no_permission_to_create_", comment: "")

        case (.upload, .conflict) where errorCode == NCGlobal.shared.errorConflict:
            return NSLocalizedString("_error_upload_no_folder_", comment: "")

        case (.download, .notFound):
            return NSLocalizedString("_error_download_not_found_", comment: "")

        case (.delete, .forbidden):
            return NSLocalizedString("_no_permission_delete_file_", comment: "")

        case (.delete, .locked):
            return NSLocalizedString("_error_delete_locked_", comment: "")

        case (.rename, .forbidden), (.moveOrCopy, .forbidden):
            return NSLocalizedString("_no_permission_modify_file_", comment: "")

        case (.rename, .alreadyExists):
            return NSLocalizedString("_rename_already_exists_", comment: "")

        case (.moveOrCopy, .alreadyExists):
            return NSLocalizedString("_file_already_exists_", comment: "")

        case (.createFolder, .alreadyExists):
            return NSLocalizedString("_error_create_folder_exists_", comment: "")

        case (.createFolder, .conflict):
            return NSLocalizedString("_error_create_folder_no_parent_", comment: "")

        case (.favorite, .forbidden):
            return NSLocalizedString("_no_permission_favorite_file_", comment: "")

        default:
            return nil
        }
    }

    private func kindMessage(for kind: Kind) -> String {
        switch kind {
        case .offline:
            return NSLocalizedString("_error_offline_", comment: "")

        case .timeout:
            return NSLocalizedString("_error_timeout_", comment: "")

        case .serverUnreachable:
            return NSLocalizedString("_error_server_unreachable_", comment: "")

        case .secureConnection:
            return NSLocalizedString("_error_secure_connection_", comment: "")

        case .unauthorized:
            return NSLocalizedString("_error_unauthorized_", comment: "")

        case .forbidden:
            return NSLocalizedString("_error_forbidden_", comment: "")

        case .notFound:
            return NSLocalizedString("_error_not_found_on_server_", comment: "")

        case .alreadyExists:
            return NSLocalizedString("_error_already_exists_", comment: "")

        case .conflict:
            return NSLocalizedString("_error_changed_on_server_", comment: "")

        case .locked:
            return NSLocalizedString("_error_locked_", comment: "")

        case .quotaExceeded:
            return NSLocalizedString("_error_quota_exceeded_", comment: "")

        case .tooLarge:
            return NSLocalizedString("_error_too_large_", comment: "")

        case .rateLimited:
            return NSLocalizedString("_error_rate_limited_", comment: "")

        case .unavailable:
            return NSLocalizedString("_error_unavailable_", comment: "")

        case .serverError:
            return NSLocalizedString("_error_server_error_", comment: "")

        case .invalidResponse:
            return NSLocalizedString("_error_invalid_response_", comment: "")

        case .localStorageFull:
            return NSLocalizedString("_error_local_storage_full_", comment: "")

        case .cancelled, .unknown:
            return NSLocalizedString("_error_occurred_", comment: "")
        }
    }
}
