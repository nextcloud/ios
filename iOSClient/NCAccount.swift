// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

class NCAccount: NSObject {
    let database = NCManageDatabase.shared
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let global = NCGlobal.shared

    func createAccount(viewController: UIViewController,
                       urlBase: String,
                       user: String,
                       password: String,
                       controller: NCMainTabBarController?,
                       completion: @escaping () -> Void = {}) {
        nkLog(debug: "Creating account...")

        var urlBase = urlBase
        if urlBase.last == "/" { urlBase = String(urlBase.dropLast()) }
        let account: String = "\(user) \(urlBase)"

        // Remove Account Server in Error
        NCNetworking.shared.removeServerErrorAccount(account)

        NextcloudKit.shared.appendSession(account: account,
                                          urlBase: urlBase,
                                          user: user,
                                          userId: user,
                                          password: password,
                                          userAgent: userAgent,
                                          httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                          httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                          httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                          groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

        NextcloudKit.shared.getUserProfile(account: account) { account, userProfile, _, error in
            if error == .success, let userProfile {
                // Login log debug
                nkLog(debug: "Got user profile, creating new account \(account) with user \(user) and userId \(userProfile.userId)")
                //
                NextcloudKit.shared.updateSession(account: account, userId: userProfile.userId)
                NCSession.shared.appendSession(account: account, urlBase: urlBase, user: user, userId: userProfile.userId)
                self.database.addAccount(account, urlBase: urlBase, user: user, userId: userProfile.userId, password: password)

                self.changeAccount(account, userProfile: userProfile, controller: controller) {
                    nkLog(debug: "NCAccount changed user profile to \(userProfile.userId).")
                    NCKeychain().setClientCertificate(account: account, p12Data: NCNetworking.shared.p12Data, p12Password: NCNetworking.shared.p12Password)

                    if let controller {
                        controller.account = account
                        nkLog(debug: "Dismissing login provider view controller...")
                        viewController.dismiss(animated: true)

                        completion()
                    } else if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                        nkLog(debug: "Presenting initial view controller from main storyboard...")
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
                NextcloudKit.shared.nkCommonInstance.nksessions.remove(account: account)
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
            // Set account
            controller?.account = account
            // Set User Profile
            if let userProfile {
                database.setAccountUserProfile(account: account, userProfile: userProfile)
            }
            // Subscribing Push Notification
            appDelegate.subscribingPushNotification(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user)
            // Start the service
            NCService().startRequestServicesServer(account: account, controller: controller)
            // Start the auto upload
            Task {
                let num = await NCAutoUpload.shared.initAutoUpload(tblAccount: tblAccount)
                nkLog(start: "Auto upload with \(num) photo")

                // Networking Process
                await NCNetworkingProcess.shared.setCurrentAccount(account)
            }

            // Color
            NCBrandColor.shared.settingThemingColor(account: account)
            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeTheming, userInfo: ["account": account])
            // Notification
            if let controller {
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeUser, userInfo: ["account": account, "controller": controller])
            } else {
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeUser, userInfo: ["account": account])
            }
        }

        completion()
    }

    func changeAccountAsync(_ account: String,
                            userProfile: NKUserProfile?,
                            controller: NCMainTabBarController?) async {
        await withCheckedContinuation { continuation in
            changeAccount(account, userProfile: userProfile, controller: controller) {
                continuation.resume()
            }
        }
    }

    func deleteAccount(_ account: String, wipe: Bool = true, completion: () -> Void = {}) {
        UIApplication.shared.allSceneSessionDestructionExceptFirst()

        // Unsubscribing Push Notification
#if !targetEnvironment(simulator)
        if let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)) {
            NCPushNotification.shared.unsubscribingNextcloudServerPushNotification(account: tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user)
        }
#endif
        // Remove al local files
        if wipe {
            let results = database.getTableLocalFiles(predicate: NSPredicate(format: "account == %@", account), sorted: "ocId", ascending: false)
            let utilityFileSystem = NCUtilityFileSystem()
            for result in results {
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId))
            }
            // Remove account in all database
            database.clearDatabase(account: account, removeAccount: true, removeAutoUpload: true)
        } else {
            // Remove account
            database.clearTable(tableAccount.self, account: account)
            // Remove autoupload
            database.clearTable(tableAutoUploadTransfer.self, account: account)
        }
        // Remove session in NextcloudKit
        NextcloudKit.shared.nkCommonInstance.nksessions.remove(account: account)
        // Remove session
        NCSession.shared.removeSession(account: account)
        // Remove keychain security
        NCKeychain().setPassword(account: account, password: nil)
        NCKeychain().clearAllKeysEndToEnd(account: account)
        NCKeychain().clearAllKeysPushNotification(account: account)
        // Remove Account Server in Error
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
        return NKShareAccounts().putShareAccounts(at: dirGroupApps, app: global.appScheme, dataAccounts: accounts)
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

        NCContentPresenter().showCustomMessage(title: "", message: String(format: NSLocalizedString("_account_unauthorized_", comment: ""), account), priority: .high, delay: global.dismissAfterSecondLong, type: .error)

        NextcloudKit.shared.getRemoteWipeStatus(serverUrl: tableAccount.urlBase, token: token, account: tableAccount.account) { account, wipe, _, error in
            // REMOVE ACCOUNT
            NCAccount().deleteAccount(account, wipe: wipe)

            if wipe {
                NextcloudKit.shared.setRemoteWipeCompletition(serverUrl: tableAccount.urlBase, token: token, account: tableAccount.account) { _, _, error in
                    nkLog(debug: "Set Remote Wipe Completition error code: \(error.errorCode)")
                    setAccount()
                }
            } else {
                setAccount()
            }
        }
    }
}
