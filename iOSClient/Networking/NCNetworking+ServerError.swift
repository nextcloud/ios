// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

extension NCNetworking {
    func noServerErrorAccount(_ account: String) -> Bool {
        guard let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)
        else {
            return true
        }
        let unavailableArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable) as? [String] ?? []
        let unauthorizedArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized) as? [String] ?? []
        let tosArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String] ?? []

        if unavailableArray.contains(account) || unauthorizedArray.contains(account) || tosArray.contains(account) {
            return false
        }

        return true
    }

    func removeServerErrorAccount(_ account: String) {
        guard let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)
        else {
            return
        }
        var unauthorizedArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized) as? [String] ?? []
        var unavailableArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable) as? [String] ?? []
        var tosArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String] ?? []

        unauthorizedArray.removeAll { $0 == account }
        groupDefaults.set(unauthorizedArray, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized)

        unavailableArray.removeAll { $0 == account }
        groupDefaults.set(unavailableArray, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable)

        tosArray.removeAll { $0 == account }
        groupDefaults.set(tosArray, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS)

        groupDefaults.synchronize()
    }

#if !EXTENSION
    func checkServerError(account: String, controller: NCMainTabBarController?) async {
        guard let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier)
        else {
            return
        }
        var unavailableArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable) as? [String] ?? []
        let unauthorizedArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized) as? [String] ?? []
        let tosArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String] ?? []

        // Unavailable
        if unavailableArray.contains(account) {
            let serverUrl = NCSession.shared.getSession(account: account).urlBase
            let resultsServerStatus = await NextcloudKit.shared.getServerStatusAsync(serverUrl: serverUrl)
            switch resultsServerStatus.result {
            case .success(let serverInfo):
                unavailableArray.removeAll { $0 == account }
                groupDefaults.set(unavailableArray, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable)
                unavailableArray.removeAll { $0 == account }
                groupDefaults.set(unavailableArray, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable)

                if serverInfo.maintenance {
                    NCContentPresenter().showInfo(title: "_warning_", description: "_maintenance_mode_")
                }
            case .failure:
                break
            }
        // Unauthorized
        } else if unauthorizedArray.contains(account) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await NCAccount().checkRemoteUserAsync(account: account, controller: controller)
        /// ToS
        } else if tosArray.contains(account) {
            await NCNetworking.shared.termsOfService(account: account)
        }
    }
#endif
}
