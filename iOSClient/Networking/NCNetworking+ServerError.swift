// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

extension NCNetworking {
    func appendServerErrorAccount(_ account: String, errorCode: Int) {
#if !EXTENSION
        guard let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier) else {
            return
        }

        /// Unavailable
        if errorCode == 503 {
            var array = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable) as? [String] ?? []

            if !array.contains(account) {
                array.append(account)
                groupDefaults.set(array, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable)
            }
        /// Unauthorized
        } else if errorCode == 401 {
            var array = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized) as? [String] ?? []

            if !array.contains(account) {
                array.append(account)
                groupDefaults.set(array, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized)
            }
        /// ToS
        } else if errorCode == 403 {
            self.termsOfService(account: account)
        }
#endif
    }

    func noServerErrorAccount(_ account: String) -> Bool {
        guard let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier) else {
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
        guard let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier) else {
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
    func checkUserServerError(account: String, controller: NCMainTabBarController?, completion: @escaping () -> Void = {}) {
        guard let groupDefaults = UserDefaults(suiteName: NextcloudKit.shared.nkCommonInstance.groupIdentifier) else {
            return completion()
        }
        var unavailableArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable) as? [String] ?? []
        let unauthorizedArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnauthorized) as? [String] ?? []
        let tosArray = groupDefaults.array(forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsToS) as? [String] ?? []

        /// Unavailable
        if unavailableArray.contains(account) {
            let serverUrl = NCSession.shared.getSession(account: account).urlBase
            NextcloudKit.shared.getServerStatus(serverUrl: serverUrl) { _, serverInfoResult in
                switch serverInfoResult {
                case .success(let serverInfo):

                    unavailableArray.removeAll { $0 == account }
                    groupDefaults.set(unavailableArray, forKey: NextcloudKit.shared.nkCommonInstance.groupDefaultsUnavailable)

                    if serverInfo.maintenance {
                        NCContentPresenter().showInfo(title: "_warning_", description: "_maintenance_mode_")
                    }
                case .failure:
                    break
                }
                completion()
            }
        /// Unauthorized
        } else if unauthorizedArray.contains(account) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NCAccount().checkRemoteUser(account: account, controller: controller) {
                    completion()
                }

            }
        /// ToS
        } else if tosArray.contains(account) {
            NCNetworking.shared.termsOfService(account: account)
        } else {
            completion()
        }
    }
#endif
}
