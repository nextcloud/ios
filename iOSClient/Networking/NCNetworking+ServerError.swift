//
//  NCNetworking+ServerError.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/03/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

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
}
