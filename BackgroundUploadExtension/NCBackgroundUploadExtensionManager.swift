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

        return !accounts.isEmpty
    }

    func ensureEnabled() async -> Bool {
        guard await shouldUseExtension() else {
            return false
        }

        let library = PHPhotoLibrary.shared()

        if library.uploadJobExtensionEnabled {
            return true
        }

        let options = PHAssetResourceUploadJobOptions()

        options.preventsExpensiveNetworkAccess = true

        do {
            try library.enableUploadJobExtension(with: options)

            nkLog(
                tag: global.logTagBackgroundUpload,
                message: """
                Background upload extension enabled: \
                \(library.uploadJobExtensionEnabled)
                """
            )

            return library.uploadJobExtensionEnabled

        } catch {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: """
                Background upload extension enable failed: \
                \(error)
                """
            )

            return false
        }
    }
}
