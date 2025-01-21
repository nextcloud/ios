//
//  NCAccount.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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
import UIKit
import NextcloudKit

class NCAccount: NSObject {
    let database = NCManageDatabase.shared

    func createAccount(urlBase: String,
                       user: String,
                       password: String,
                       controller: NCMainTabBarController?,
                       completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        var urlBase = urlBase
        if urlBase.last == "/" { urlBase = String(urlBase.dropLast()) }
        let account: String = "\(user) \(urlBase)"

        NextcloudKit.shared.appendSession(account: account,
                                          urlBase: urlBase,
                                          user: user,
                                          userId: user,
                                          password: password,
                                          userAgent: userAgent,
                                          nextcloudVersion: NCCapabilities.shared.getCapabilities(account: account).capabilityServerVersionMajor,
                                          httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                          httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                          httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                          groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

        NextcloudKit.shared.getUserProfile(account: account) { account, userProfile, _, error in
            if error == .success, let userProfile {
                NextcloudKit.shared.updateSession(account: account, userId: userProfile.userId)
                NCSession.shared.appendSession(account: account, urlBase: urlBase, user: user, userId: userProfile.userId)
                self.database.addAccount(account, urlBase: urlBase, user: user, userId: userProfile.userId, password: password)
                self.changeAccount(account, userProfile: userProfile, controller: controller) {
                    NCKeychain().setClientCertificate(account: account, p12Data: NCNetworking.shared.p12Data, p12Password: NCNetworking.shared.p12Password)
                    completion(account, error)
                }
            } else {
                NextcloudKit.shared.removeSession(account: account)
                let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: error.errorDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                UIApplication.shared.firstWindow?.rootViewController?.present(alertController, animated: true)
                completion(account, error)
            }
        }
    }

    func changeAccount(_ account: String,
                       userProfile: NKUserProfile?,
                       controller: NCMainTabBarController?,
                       completion: () -> Void) {
        /// Set account
        controller?.account = account
        database.setAccountActive(account)
        /// Set capabilities
        database.setCapabilities(account: account)
        /// Set User Profile
        if let userProfile {
            database.setAccountUserProfile(account: account, userProfile: userProfile)
        }
        /// Start Push Notification
        NCPushNotification.shared.pushNotification()
        /// Start the service
        NCService().startRequestServicesServer(account: account, controller: controller)
        /// Start the auto upload
        NCAutoUpload.shared.initAutoUpload(controller: nil, account: account) { num in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Initialize Auto upload with \(num) uploads")
        }
        /// Color
        NCBrandColor.shared.settingThemingColor(account: account)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeTheming, userInfo: ["account": account])
        /// Notification
        if let controller {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeUser, userInfo: ["account": account, "controller": controller])
        } else {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeUser, userInfo: ["account": account])
        }

        completion()
    }

    func deleteAccount(_ account: String, wipe: Bool = true, completion: () -> Void = {}) {
        UIApplication.shared.allSceneSessionDestructionExceptFirst()

        /// Unsubscribing Push Notification
        if let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)) {
            NCPushNotification.shared.unsubscribingNextcloudServerPushNotification(account: tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, withSubscribing: false)
        }
        /// Remove al local files
        if wipe {
            let results = database.getTableLocalFiles(predicate: NSPredicate(format: "account == %@", account), sorted: "ocId", ascending: false)
            let utilityFileSystem = NCUtilityFileSystem()
            for result in results {
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId))
            }
            /// Remove account in all database
            database.clearDatabase(account: account, removeAccount: true)
        } else {
            /// Remove account
            database.clearTable(tableAccount.self, account: account)
        }
        /// Remove session in NextcloudKit
        NextcloudKit.shared.removeSession(account: account)
        /// Remove session
        NCSession.shared.removeSession(account: account)
        /// Remove keychain security
        NCKeychain().setPassword(account: account, password: nil)
        NCKeychain().clearAllKeysEndToEnd(account: account)
        NCKeychain().clearAllKeysPushNotification(account: account)
        /// Remove User Default Data
        NCNetworking.shared.removeAllKeyUserDefaultsData(account: account)

        completion()
    }

    func deleteAllAccounts() {
        let accounts = database.getAccounts()
        accounts?.forEach({ account in
            deleteAccount(account)
        })
    }

    func updateAppsShareAccounts() -> Error? {
        guard let dirGroupApps = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroupApps) else { return nil }
        var accounts = [NKShareAccounts.DataAccounts]()

        for account in database.getAllTableAccount() {
            let name = account.alias.isEmpty ? account.displayName : account.alias
            let fileName = NCSession.shared.getFileName(urlBase: account.urlBase, user: account.user)
            let fileNamePath = NCUtilityFileSystem().directoryUserData + "/" + fileName
            let image = UIImage(contentsOfFile: fileNamePath)
            accounts.append(NKShareAccounts.DataAccounts(withUrl: account.urlBase, user: account.user, name: name, image: image))
        }
        return NKShareAccounts().putShareAccounts(at: dirGroupApps, app: NCGlobal.shared.appScheme, dataAccounts: accounts)
    }
}
