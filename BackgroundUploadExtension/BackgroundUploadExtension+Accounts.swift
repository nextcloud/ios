// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    func setupAccounts() async -> [tableAccount] {
        let accounts = await database.getAllTableAccountAsync()

        for account in accounts {
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
        }

        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            return []
        }

        guard !NCPreferences().formatCompatibility else {
            return []
        }

        return accounts.filter(\.autoUploadStart)
    }
}
