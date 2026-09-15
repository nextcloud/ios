// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    func setupAccount() async -> tableAccount? {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            logDebug("Background upload account setup skipped: Photos authorization is not granted")
            return nil
        }

        guard !NCPreferences().formatCompatibility else {
            logDebug("Background upload account setup skipped: compatibility format is enabled")
            return nil
        }

        guard NCBrandOptions.shared.enable_background_upload_extension else {
            logDebug("Background upload account setup skipped: feature is disabled")
            return nil
        }

        guard let account = await database.getTableAccountAsync(predicate: NSPredicate(format: "autoUploadStart == true")) else {
            logDebug("Background upload account setup skipped: no Auto Upload account")
            return nil
        }

        NextcloudKit.shared.appendSession(
            account: account.account,
            urlBase: account.urlBase,
            user: account.user,
            userId: account.userId,
            password: NCPreferences().getPassword(account: account.account),
            userAgent: userAgent,
            httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
            httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
            httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
            groupIdentifier: NCBrandOptions.shared.capabilitiesGroup
        )

        guard let capabilities = await database.getCapabilities(account: account.account) else {
            logError("Background upload account setup failed: capabilities not found for \(account.account)")
            return nil
        }

        guard NCBrandOptions.shared.isServerVersion(
            capabilities,
            greaterOrEqualTo: .v33
        ) else {
            logInfo("Background upload extension stopped because account \(account.account) uses a server lower than version 33", persist: true)
            return nil
        }

        return account
    }
}
