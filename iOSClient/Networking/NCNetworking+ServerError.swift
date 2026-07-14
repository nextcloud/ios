// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

extension NCNetworking {
    func noServerErrorAccount(_ account: String) -> Bool {
        guard let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup) else {
            return true
        }
        let unavailableArray = groupDefaults.array(forKey: nkComm.groupDefaultsUnavailable) as? [String] ?? []
        let unauthorizedArray = groupDefaults.array(forKey: nkComm.groupDefaultsUnauthorized) as? [String] ?? []
        let tosArray = groupDefaults.array(forKey: nkComm.groupDefaultsToS) as? [String] ?? []

        if unavailableArray.contains(account) || unauthorizedArray.contains(account) || tosArray.contains(account) {
            return false
        }

        return true
    }

    func removeServerErrorAccount(_ account: String) {
        guard let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup) else {
            return
        }
        var unauthorizedArray = groupDefaults.array(forKey: nkComm.groupDefaultsUnauthorized) as? [String] ?? []
        var unavailableArray = groupDefaults.array(forKey: nkComm.groupDefaultsUnavailable) as? [String] ?? []
        var tosArray = groupDefaults.array(forKey: nkComm.groupDefaultsToS) as? [String] ?? []

        unauthorizedArray.removeAll { $0 == account }
        groupDefaults.set(unauthorizedArray, forKey: nkComm.groupDefaultsUnauthorized)

        unavailableArray.removeAll { $0 == account }
        groupDefaults.set(unavailableArray, forKey: nkComm.groupDefaultsUnavailable)

        tosArray.removeAll { $0 == account }
        groupDefaults.set(tosArray, forKey: nkComm.groupDefaultsToS)

        groupDefaults.synchronize()
    }

    func checkServerError(account: String, controller: NCMainTabBarController?) async {
        guard let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup) else {
            return
        }
        var unavailableArray = groupDefaults.array(forKey: nkComm.groupDefaultsUnavailable) as? [String] ?? []
        let unauthorizedArray = groupDefaults.array(forKey: nkComm.groupDefaultsUnauthorized) as? [String] ?? []
        let tosArray = groupDefaults.array(forKey: nkComm.groupDefaultsToS) as? [String] ?? []

        // Unavailable (503)
        if unavailableArray.contains(account) {
            let serverUrl = NCSession.shared.getSession(account: account).urlBase
            let resultsServerStatus = await NextcloudKit.shared.getServerStatusAsync(serverUrl: serverUrl) { task in
                Task {
                    let identifier = serverUrl + "_getServerStatus"
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            switch resultsServerStatus.result {
            case .success(let serverInfo):
                // Always remove the (503) error for the account from groupDefaults.
                unavailableArray.removeAll { $0 == account }
                groupDefaults.set(unavailableArray, forKey: nkComm.groupDefaultsUnavailable)

                if serverInfo.maintenance {
                    // Show maintenance mode warning.
                    let windowScene = await SceneManager.shared.getWindowScene(controller: controller)
                    await showWarningBanner(windowScene: windowScene,
                                            subtitle: "_maintenance_mode_",
                                            systemImage: "xmark.icloud.fill",
                                            imageAnimation: .none,
                                            errorCode: global.errorMaintenance)
                }
            case .failure:
                break
            }
        // Unauthorized (401)
        } else if unauthorizedArray.contains(account) {
            nkLog(error: "Unauthorized for \(account)")

            try? await Task.sleep(for: .seconds(0.5))
            await NCAccount().checkRemoteUser(account: account, controller: controller)
        /// ToS (403)
        } else if tosArray.contains(account) {
            nkLog(error: "Terms of service for \(account)")

            await NCNetworking.shared.termsOfService(account: account)
        }
    }
}
