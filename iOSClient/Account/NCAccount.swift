// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

@MainActor
class NCAccount: NSObject {
    let database = NCManageDatabase.shared
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let global = NCGlobal.shared
    let utilityFileSystem = NCUtilityFileSystem()

    func createAccount(viewController: UIViewController, urlBase: String, user: String, password: String, controller: NCMainTabBarController?) async {
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

        let resultsGetUserProfile = await NextcloudKit.shared.getUserProfileAsync(account: account)

        guard resultsGetUserProfile.error == .success, let userProfile = resultsGetUserProfile.userProfile else {
            NextcloudKit.shared.nkCommonInstance.nksessions.remove(account: account)
            let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: resultsGetUserProfile.error.errorDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
            viewController.present(alertController, animated: true)

            return
        }

        // Login log debug
        nkLog(debug: "Got user profile, creating new account \(account) with user \(user) and userId \(userProfile.userId)")

        NextcloudKit.shared.updateSession(account: account, userId: userProfile.userId)
        NCSession.shared.appendSession(account: account, urlBase: urlBase, user: user, userId: userProfile.userId)
        await self.database.addAccountAsync(account, urlBase: urlBase, user: user, userId: userProfile.userId, password: password)

        // FPE Domains
        try? await FileProviderDomain().ensureDomainRegistered(userId: userProfile.userId, user: "\(user)", urlBase: urlBase)

        await changeAccount(account, userProfile: userProfile, controller: controller)
        nkLog(debug: "NCAccount changed user profile to \(userProfile.userId).")

        NCPreferences().setClientCertificate(account: account, p12Data: NCNetworking.shared.p12Data, p12Password: NCNetworking.shared.p12Password)

        if let controller {
            controller.account = account
            nkLog(debug: "Dismissing login provider view controller...")
            viewController.dismiss(animated: true)
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
        }
    }

    func changeAccount(_ account: String, userProfile: NKUserProfile?, controller: NCMainTabBarController?) async {
        if let tblAccount = await database.setAccountActiveAsync(account) {
            // Set account
            controller?.account = account
            // Set User Profile
            if let userProfile {
                await database.setAccountUserProfileAsync(account: account, userProfile: userProfile)
            }
            // Subscribing Push Notification
            appDelegate.subscribingPushNotification(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user)
            // Start the service
            Task(priority: .utility) {
                await NCService().startRequestServicesServer(account: account, controller: controller)
            }
            // Capabilities
            if let capabilities = await self.database.getCapabilities(account: account) {
                // set theming color
                NCBrandColor.shared.settingThemingColor(account: account, capabilities: capabilities)
            }
            // Start the auto upload
            let num = await NCAutoUpload.shared.initAutoUpload(tblAccount: tblAccount)
            nkLog(start: "Auto upload with \(num) photo")
            // Networking Process
            await NCNetworkingProcess.shared.setCurrentAccount(account)
            // Color
            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeTheming, userInfo: ["account": account])
            // Notification
            if let controller {
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeUser, userInfo: ["account": account, "controller": controller])
            } else {
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeUser, userInfo: ["account": account])
            }
        }
    }

    func deleteAccount(_ account: String, wipe: Bool = true) async {
        UIApplication.shared.allSceneSessionDestructionExceptFirst()
        let tblAccount = await database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", account))

        // Unsubscribing Push Notification & Domain
        if let tblAccount {
            NCPushNotification.shared.unsubscribingNextcloudServerPushNotification(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user)
            try? await FileProviderDomain().ensureDomainRemoved(userId: tblAccount.userId, urlBase: tblAccount.urlBase)
        }

        // Remove al local files
        if wipe {
            // Remove user domain directory
            if let tblAccount {
                let path = utilityFileSystem.getDocumentStorage(userId: tblAccount.userId, urlBase: tblAccount.urlBase)
                do {
                    try FileManager.default.removeItem(atPath: path)
                } catch {
                    print(error)
                }
            }
            // Remove account in all database
            database.clearDatabase(account: account)
        } else {
            // Remove account
            await database.clearTableAsync(tableAccount.self, account: account)
            // Remove autoupload
            await database.clearTableAsync(tableAutoUploadTransfer.self, account: account)
        }
        // Remove session in NextcloudKit
        NextcloudKit.shared.nkCommonInstance.nksessions.remove(account: account)
        // Remove session
        NCSession.shared.removeSession(account: account)
        // Remove capabilities
        await NKCapabilities.shared.removeCapabilities(for: account)
        NCNetworking.shared.capabilities.removeValue(forKey: account)
        // Remove keychain security
        NCPreferences().setPassword(account: account, password: nil)
        NCPreferences().clearAllKeysEndToEnd(account: account)
        NCPreferences().clearAllKeysPushNotification(account: account)
        // Remove Account Server in Error
        NCNetworking.shared.removeServerErrorAccount(account)
    }

    func deleteAllAccounts() async {
        if let accounts = await database.getAccountsAsync() {
            for account in accounts {
                await deleteAccount(account)
            }
        }
    }

    func updateAppsShareAccounts() async -> Error? {
        guard let dirGroupApps = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroupApps) else { return nil }
        var accounts = [NKShareAccounts.DataAccounts]()

        for account in await database.getAllTableAccountAsync() {
            let name = account.alias.isEmpty ? account.displayName : account.alias
            let fileName = NCSession.shared.getFileName(urlBase: account.urlBase, user: account.user)
            let fileNamePath = self.utilityFileSystem.createServerUrl(serverUrl: self.utilityFileSystem.directoryUserData, fileName: fileName)
            let image = UIImage(contentsOfFile: fileNamePath)
            accounts.append(NKShareAccounts.DataAccounts(withUrl: account.urlBase, user: account.user, name: name, image: image))
        }
        return NKShareAccounts().putShareAccounts(at: dirGroupApps, app: global.appScheme, dataAccounts: accounts)
    }

    func checkRemoteUser(account: String, controller: NCMainTabBarController?) async {
        let token = NCPreferences().getPassword(account: account)
        guard let tblAccount = await NCManageDatabase.shared.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", account)) else {
            return
        }

        NCContentPresenter().showCustomMessage(title: "", message: String(format: NSLocalizedString("_account_unauthorized_", comment: ""), account), priority: .high, delay: global.dismissAfterSecondLong, type: .error)

        let resultsWipe = await NextcloudKit.shared.getRemoteWipeStatusAsync(serverUrl: tblAccount.urlBase, token: token, account: account)

        // REMOVE ACCOUNT
        await NCAccount().deleteAccount(account, wipe: resultsWipe.wipe)
        if resultsWipe.wipe {
            let resultsSetWipe = await NextcloudKit.shared.setRemoteWipeCompletitionAsync(serverUrl: tblAccount.urlBase, token: token, account: tblAccount.account)
            nkLog(debug: "Set Remote Wipe Completition error code: \(resultsSetWipe.error.errorCode)")
        }

        let accounts = await NCManageDatabase.shared.getAccountsAsync()

        if let accounts,
           account.count > 0,
           let account = accounts.first {
                await changeAccount(account, userProfile: nil, controller: controller)
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
    }
}
