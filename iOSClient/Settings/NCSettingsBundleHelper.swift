// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

class NCSettingsBundleHelper: NSObject {

    struct SettingsBundleKeys {
        static let Reset = "reset_application"
        static let BuildVersionKey = "version_preference"
    }

    class func setVersionAndBuildNumber() {
        let version = NCUtility().getVersionBuild() as String
        UserDefaults.standard.set(version, forKey: SettingsBundleKeys.BuildVersionKey)
    }

    class func checkAndExecuteSettings(delay: Double) {
        if UserDefaults.standard.bool(forKey: SettingsBundleKeys.Reset) {
            UserDefaults.standard.set(false, forKey: SettingsBundleKeys.Reset)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
                appDelegate.resetApplication()
            }
        }
    }
}
