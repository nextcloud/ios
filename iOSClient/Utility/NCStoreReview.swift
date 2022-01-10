//
//  NCStoreReview.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/11/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

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
            runs = savedRuns as! Int
        }

        print("Nextcloud iOS run Counts are \(runs)")
        return runs
    }

    @objc func incrementAppRuns() {

        let uDefaults = UserDefaults()
        let runs = getRunCounts() + 1
        uDefaults.setValuesForKeys([runIncrementerSetting: runs])
        uDefaults.synchronize()
    }

    @objc func showStoreReview() {

        let runs = getRunCounts()

        if runs > minimumRunCount {
            SKStoreReviewController.requestReview()
        }
    }
}
