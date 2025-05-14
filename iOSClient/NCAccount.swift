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
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    func createAccount(viewController: UIViewController,
                       urlBase: String,
                       user: String,
                       password: String,
                       controller: NCMainTabBarController?,
                       completion: @escaping () -> Void = {}) {
        var urlBase = urlBase
        if urlBase.last == "/" { urlBase = String(urlBase.dropLast()) }
        let account: String = "\(user) \(urlBase)"

        /// Remove Account Server in Error
        NCNetworking.shared.removeServerErrorAccount(account)

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
                /// Login log debug
                NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Create new account \(account) with user \(user) and userId \(userProfile.userId)")
                ///
                NextcloudKit.shared.updateSession(account: account, userId: userProfile.userId)
                NCSession.shared.appendSession(account: account, urlBase: urlBase, user: user, userId: userProfile.userId)
                self.database.addAccount(account, urlBase: urlBase, user: user, userId: userProfile.userId, password: password)
                self.changeAccount(account, userProfile: userProfile, controller: controller) {
                    NCKeychain().setClientCertificate(account: account, p12Data: NCNetworking.shared.p12Data, p12Password: NCNetworking.shared.p12Password)
                    if let controller {
                        controller.account = account
                        viewController.dismiss(animated: true)

                        completion()
                    } else if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                        controller.account = account
                        controller.modalPresentationStyle = .fullScreen
                        controller.view.alpha = 0

                        UIApplication.shared.firstWindow?.rootViewController = controller
                        UIApplication.shared.firstWindow?.makeKeyAndVisible()

                        if let scene = UIApplication.shared.firstWindow?.windowScene {
                            SceneManager.shared.register(scene: scene, withRootViewController: controller)
                        }

                        UIView.animate(withDuration: 0.5) {
                            controller.view.alpha = 1
                        }

                        completion()
                    }
                }
            } else {
                NextcloudKit.shared.removeSession(account: account)
                let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: error.errorDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                viewController.present(alertController, animated: true)

                completion()
            }
        }
    }

    func changeAccount(_ account: String,
                       userProfile: NKUserProfile?,
                       controller: NCMainTabBarController?,
                       completion: () -> Void) {
        if let tblAccount = database.setAccountActive(account) {
            /// Set account
            controller?.account = account
            /// Set capabilities
            database.setCapabilities(account: account)
            /// Set User Profile
            if let userProfile {
                database.setAccountUserProfile(account: account, userProfile: userProfile)
            }
            /// Subscribing Push Notification
            appDelegate.subscribingPushNotification(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user)
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
        }

        completion()
    }

    func deleteAccount(_ account: String, wipe: Bool = true, completion: () -> Void = {}) {
        UIApplication.shared.allSceneSessionDestructionExceptFirst()

        /// Unsubscribing Push Notification
#if !targetEnvironment(simulator)
        if let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)) {
            NCPushNotification.shared.unsubscribingNextcloudServerPushNotification(account: tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user)
        }
#endif
        /// Remove al local files
        if wipe {
            let results = database.getTableLocalFiles(predicate: NSPredicate(format: "account == %@", account), sorted: "ocId", ascending: false)
            let utilityFileSystem = NCUtilityFileSystem()
            for result in results {
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId))
            }
            /// Remove account in all database
            database.clearDatabase(account: account, removeAccount: true, removeAutoUpload: true)
        } else {
            /// Remove account
            database.clearTable(tableAccount.self, account: account)
            /// Remove autoupload
            database.clearTable(tableAutoUploadTransfer.self, account: account)
        }
        /// Remove session in NextcloudKit
        NextcloudKit.shared.removeSession(account: account)
        /// Remove session
        NCSession.shared.removeSession(account: account)
        /// Remove keychain security
        NCKeychain().setPassword(account: account, password: nil)
        NCKeychain().clearAllKeysEndToEnd(account: account)
        NCKeychain().clearAllKeysPushNotification(account: account)
        /// Remove Account Server in Error
        NCNetworking.shared.removeServerErrorAccount(account)

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

    func checkRemoteUser(account: String, controller: NCMainTabBarController?, completion: @escaping () -> Void = {}) {
        let token = NCKeychain().getPassword(account: account)
        guard let tableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", account))
        else {
            return completion()
        }

        func setAccount() {
            if let accounts = NCManageDatabase.shared.getAccounts(),
               account.count > 0,
               let account = accounts.first {
                changeAccount(account, userProfile: nil, controller: controller) { }
            } else {
                if NCBrandOptions.shared.disable_intro {
                    if let viewController = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLogin") as? NCLogin {
                        viewController.controller = controller
                        let navigationController = UINavigationController(rootViewController: viewController)
                        navigationController.modalPresentationStyle = .fullScreen
                        controller?.present(navigationController, animated: true)
                    }
                } else {
                    if let navigationController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() as? UINavigationController {
                        if let viewController = navigationController.topViewController as? NCIntroViewController {
                            viewController.controller = controller
                        }
                        navigationController.modalPresentationStyle = .fullScreen
                        controller?.present(navigationController, animated: true)
                    }
                }
            }

            completion()
        }

        NCContentPresenter().showCustomMessage(title: "", message: String(format: NSLocalizedString("_account_unauthorized_", comment: ""), account), priority: .high, delay: NCGlobal.shared.dismissAfterSecondLong, type: .error)

        NextcloudKit.shared.getRemoteWipeStatus(serverUrl: tableAccount.urlBase, token: token, account: tableAccount.account) { account, wipe, _, error in
            /// REMOVE ACCOUNT
            NCAccount().deleteAccount(account, wipe: wipe)

            if wipe {
                NextcloudKit.shared.setRemoteWipeCompletition(serverUrl: tableAccount.urlBase, token: token, account: tableAccount.account) { _, _, error in
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Set Remote Wipe Completition error code: \(error.errorCode)")
                    setAccount()
                }
            } else {
                setAccount()
            }
        }
    }
}
