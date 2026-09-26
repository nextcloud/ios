// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

@available(iOS 27, *)
final class NCBackgroundUploadExtensionManager {
    static let shared = NCBackgroundUploadExtensionManager()

    private let database = NCManageDatabase.shared
    private let global = NCGlobal.shared

    /// Creates the shared host-app manager used to control the PhotoKit extension state.
    /// Callers access this instance through `shared` so enable and disable decisions stay centralized.
    private init() {}

    /// Checks whether device authorization, app settings, account state, and server version allow delegation.
    /// This method evaluates eligibility only and does not change the PhotoKit extension state.
    func shouldUseExtension() async -> Bool {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            return false
        }

        guard !NCPreferences().formatCompatibility else {
            return false
        }

        guard NCBrandOptions.shared.enable_background_upload_extension else {
            return false
        }

        guard let account = await database.getTableAccountAsync(predicate: NSPredicate(format: "autoUploadStart == true")) else {
            return false
        }

        let capabilities = await NKCapabilities.shared.getCapabilities(for: account.account)

        guard NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: .v33) else {
            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension unavailable for account \(account.account): server version is lower than 33")
            return false
        }

        return true
    }

    /// Enables the PhotoKit upload extension when eligible and refreshes its network options if active.
    /// Returns the resulting PhotoKit enabled state, or `false` when eligibility or configuration fails.
    func ensureEnabled() async -> Bool {
        guard NCBrandOptions.shared.enable_background_upload_extension else {
            _ = await disableIfIdle()
            return false
        }

        guard await shouldUseExtension() else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        let options = PHAssetResourceUploadJobOptions()
        options.preventsExpensiveNetworkAccess = false

        do {
            if library.uploadJobExtensionEnabled {
                try library.setUploadJobExtensionOptions(options)
            } else {
                try library.enableUploadJobExtension(with: options)
            }

            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension enabled: \(library.uploadJobExtensionEnabled)")
            return library.uploadJobExtensionEnabled
        } catch {
            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension enable failed: \(error)")
            return false
        }
    }

    /// Disables the PhotoKit extension after the feature or auto upload is turned off and no jobs remain.
    /// Active metadata defers disabling so cancellations and terminal results can still be reconciled.
    func disableIfIdle() async -> Bool {
        let featureEnabled = NCBrandOptions.shared.enable_background_upload_extension
        let account = await database.getTableAccountAsync(predicate: NSPredicate(format: "autoUploadStart == true"))

        guard !featureEnabled || account == nil else {
            return false
        }

        let predicate = NSPredicate(format: "sessionSelector == %@ AND backgroundUploadJobIdentifier != ''", global.selectorUploadAutoUpload)
        let metadatas: [tableMetadata] = await database.getMetadatasAsync(predicate: predicate)

        guard metadatas.isEmpty else {
            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension disable deferred: \(metadatas.count) jobs still active")
            return false
        }

        let library = PHPhotoLibrary.shared()

        guard library.uploadJobExtensionEnabled else {
            return true
        }

        do {
            try library.disableUploadJobExtension()
            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension disabled")
            return !library.uploadJobExtensionEnabled
        } catch {
            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension disable failed: \(error)")
            return false
        }
    }
}
