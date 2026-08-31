// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    func setupAccount() async -> tableAccount? {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            return nil
        }

        guard !NCPreferences().formatCompatibility else {
            return nil
        }

        guard let account = await database.getTableAccountAsync(predicate: NSPredicate(format: "autoUploadStart == true")) else {
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

        let capabilities = await NKCapabilities.shared.getCapabilities(for: account.account)

        guard NCBrandOptions.shared.isServerVersion(
            capabilities,
            greaterOrEqualTo: .v33
        ) else {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "Background upload extension stopped because account \(account.account) uses a server lower than version 33"
            )
            return nil
        }

        return account
    }
}
