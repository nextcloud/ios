//
//  NCSettingsBundleHelper.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/02/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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

import Foundation

class NCSettingsBundleHelper: NSObject {

    struct SettingsBundleKeys {
        static let Reset = "reset_application"
        static let BuildVersionKey = "version_preference"
    }

    class func setVersionAndBuildNumber() {
        let version = NCUtility.shared.getVersionApp() as String
        UserDefaults.standard.set(version, forKey: SettingsBundleKeys.BuildVersionKey)
    }

    class func checkAndExecuteSettings(delay: Double) {
        if UserDefaults.standard.bool(forKey: SettingsBundleKeys.Reset) {
            UserDefaults.standard.set(false, forKey: SettingsBundleKeys.Reset)

            URLCache.shared.memoryCapacity = 0
            URLCache.shared.diskCapacity = 0

            CCUtility.removeGroupDirectoryProviderStorage()
            CCUtility.removeGroupApplicationSupport()
            CCUtility.removeDocumentsDirectory()
            CCUtility.removeTemporaryDirectory()

            CCUtility.deleteAllChainStore()
            NCManageDatabase.shared.removeDB()

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                exit(0)
            }
        }
    }
}
