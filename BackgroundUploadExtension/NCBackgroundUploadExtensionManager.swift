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

    private init() {}

    func shouldUseExtension() async -> Bool {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            return false
        }

        guard !NCPreferences().formatCompatibility else {
            return false
        }

        let accounts = await database.getTableAccountsAsync(predicate: NSPredicate(format: "autoUploadStart == true"))

        guard !accounts.isEmpty else {
            return false
        }

        for account in accounts {
            let capabilities = await NKCapabilities.shared.getCapabilities(for: account.account)
            guard NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: .v33) else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Background upload extension unavailable for account \(account.account): server version is lower than 33"
                )
                return false
            }
        }

        return true
    }

    func ensureEnabled() async -> Bool {
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
}
