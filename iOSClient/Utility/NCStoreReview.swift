// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import StoreKit

class NCStoreReview: NSObject {
    let runIncrementerSetting = "numberOfRuns"
    let minimumRunCount = 5

    func getRunCounts () -> Int {
        let uDefaults = UserDefaults()
        let savedRuns = uDefaults.value(forKey: runIncrementerSetting)
        var runs = 0
        if savedRuns != nil {
            runs = savedRuns as? Int ?? 0
        }
        return runs
    }

    func incrementAppRuns() {
        let uDefaults = UserDefaults()
        let runs = getRunCounts() + 1
        uDefaults.setValuesForKeys([runIncrementerSetting: runs])
        uDefaults.synchronize()
    }

    func showStoreReview() {
        let runs = getRunCounts()

        if runs > minimumRunCount,
           let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}
