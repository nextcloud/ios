// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import WidgetKit
import SwiftEntryKit
import SwiftUI
import CoreLocation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let appDelegate = UIApplication.shared.delegate as? AppDelegate
    private var privacyProtectionWindow: UIWindow?
    private let global = NCGlobal.shared
    private let alreadyMigratedMultiDomains = UserDefaults.standard.bool(forKey: NCGlobal.shared.udMigrationMultiDomains)

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }
        let versionApp = NCUtility().getVersionMaintenance()
        var lastVersion: String?

        if let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup) {
            lastVersion = groupDefaults.string(forKey: NCGlobal.shared.udLastVersion)
            groupDefaults.set(versionApp, forKey: global.udLastVersion)
        }
        UserDefaults.standard.set(true, forKey: global.udMigrationMultiDomains)

        self.window = UIWindow(windowScene: windowScene)
        if !NCPreferences().appearanceAutomatic {
            self.window?.overrideUserInterfaceStyle = NCPreferences().appearanceInterfaceStyle
        }

        // in Debug write all UserDefaults.standard
        #if DEBUG
        print("UserDefaults: ---------------------------")
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            print("\(key) = \(value)")
        }
        print("UserDefaults Group: ---------------------")
        if let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup) {
            for (key, value) in groupDefaults.dictionaryRepresentation() {
                print("\(key) = \(value)")
            }
        }
        print("-----------------------------------------")
        #endif

        if lastVersion != versionApp {
            // Suspending Database for blocked the realm access (better be sure 100%)
            isSuspendingDatabaseOperation = true
            maintenanceMode = true
            window?.rootViewController = UIHostingController(rootView: Maintenance(onCompleted: {
                isSuspendingDatabaseOperation = false
                maintenanceMode = false
                // Start App
                self.startNextcloud(scene: scene, withActivateSceneForAccount: true)
            }))
            window?.makeKeyAndVisible()
        } else {
            self.startNextcloud(scene: scene, withActivateSceneForAccount: false)
        }
    }

    private func startNextcloud(scene: UIScene, withActivateSceneForAccount activateSceneForAccount: Bool) {
        // App not in background
        isAppInBackground = false
        // Open Realm
        NCManageDatabase.shared.openRealm()
        // Table account
        var activeTblAccount = NCManageDatabase.shared.getActiveTableAccount()

        // Try to restore accounts
        if activeTblAccount == nil {
            NCManageDatabase.shared.restoreTableAccountFromFile()
            activeTblAccount = NCManageDatabase.shared.getActiveTableAccount()
        }

        // Activation singleton
        _ = NCAppStateManager.shared
        _ = NCNetworking.shared
        _ = NCDownloadAction.shared
        _ = NCNetworkingProcess.shared

        if let activeTblAccount, !alreadyMigratedMultiDomains {
            //
            // Migration Multi Domains
            //
            window?.rootViewController = UIHostingController(rootView: MigrationMultiDomains(onCompleted: {
                //
                // Start Main
                //
                self.launchMainInterface(scene: scene, activeTblAccount: activeTblAccount, withActivateSceneForAccount: activateSceneForAccount)
            }))
            window?.makeKeyAndVisible()

        } else if let activeTblAccount {
            //
            // Start Main
            //
            self.launchMainInterface(scene: scene, activeTblAccount: activeTblAccount, withActivateSceneForAccount: activateSceneForAccount)

        } else {
            //
            // NO account found, start with the Login
            //
            NCPreferences().removeAll()

            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }

            if NCBrandOptions.shared.disable_intro {
                if let viewController = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLogin") as? NCLogin {
                    let navigationController = UINavigationController(rootViewController: viewController)
                    window?.rootViewController = navigationController
                    window?.makeKeyAndVisible()
                }
            } else {
                if let navigationController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() as? UINavigationController {
                    window?.rootViewController = navigationController
                    window?.makeKeyAndVisible()
                }
            }
        }
    }

    private func launchMainInterface(scene: UIScene,
                                     activeTblAccount: tableAccount,
                                     withActivateSceneForAccount activateSceneForAccount: Bool) {
        nkLog(debug: "Account active \(activeTblAccount.account)")

        // Networking Certificate
        NCNetworking.shared.activeAccountCertificate(account: activeTblAccount.account)

        Task {
            if let capabilities = await NCManageDatabase.shared.getCapabilities(account: activeTblAccount.account) {
                // set theming color
                NCBrandColor.shared.settingThemingColor(account: activeTblAccount.account, capabilities: capabilities)
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterChangeTheming, userInfo: ["account": activeTblAccount.account])
            }

            // Set up networking session
            await NCNetworkingProcess.shared.setCurrentAccount(activeTblAccount.account)
        }

        // Set up networking session for all configured accounts
        for tblAccount in NCManageDatabase.shared.getAllTableAccount() {
            // Append account to NextcloudKit shared session
            NextcloudKit.shared.appendSession(account: tblAccount.account,
                                              urlBase: tblAccount.urlBase,
                                              user: tblAccount.user,
                                              userId: tblAccount.userId,
                                              password: NCPreferences().getPassword(account: tblAccount.account),
                                              userAgent: userAgent,
                                              httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                              httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                              httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                              groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

            // Perform async setup: restore capabilities and ensure file provider domain
            Task {
                await NCManageDatabase.shared.getCapabilities(account: tblAccount.account)
                try? await FileProviderDomain().ensureDomainRegistered(userId: tblAccount.userId, user: tblAccount.user, urlBase: tblAccount.urlBase)
            }

            // Append session to internal session manager
            NCSession.shared.appendSession(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user, userId: tblAccount.userId)
        }

        // Load Main.storyboard
        if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
            SceneManager.shared.register(scene: scene, withRootViewController: controller)
            // Set the ACCOUNT
            controller.account = activeTblAccount.account
            //
            window?.rootViewController = controller
            window?.makeKeyAndVisible()
            //
            if activateSceneForAccount {
                self.activateSceneForAccount(scene, account: activeTblAccount.account, controller: controller)
            }
        }

        // Clean orphaned FP Domains
        Task {
            await FileProviderDomain().cleanOrphanedFileProviderDomains()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("[DEBUG] Scene did disconnect")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        hidePrivacyProtectionWindow()

        if let rootHostingController = scene.rootHostingController() {
            if rootHostingController.anyRootView is Maintenance {
                return
            }
        }
        let session = SceneManager.shared.getSession(scene: scene)
        let controller = SceneManager.shared.getController(scene: scene)

        activateSceneForAccount(scene, account: session.account, controller: controller)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        hidePrivacyProtectionWindow()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        nkLog(debug: "Scene will resign active")

        let session = SceneManager.shared.getSession(scene: scene)
        guard !session.account.isEmpty else {
            return
        }

        if NCPreferences().privacyScreenEnabled {
            if SwiftEntryKit.isCurrentlyDisplaying {
                SwiftEntryKit.dismiss {
                    self.showPrivacyProtectionWindow()
                }
            } else {
                showPrivacyProtectionWindow()
            }
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        let app = UIApplication.shared
        var bgID: UIBackgroundTaskIdentifier = .invalid
        let isBackgroundRefreshStatus = (UIApplication.shared.backgroundRefreshStatus == .available)
        let session = SceneManager.shared.getSession(scene: scene)
        guard let tblAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) else {
            return
        }
        bgID = app.beginBackgroundTask(withName: "FlushBeforeSuspend") {
            app.endBackgroundTask(bgID); bgID = .invalid
        }

        Task {
            Task { @MainActor in
                if NCPreferences().presentPasscode {
                    showPrivacyProtectionWindow()
                }
            }
            defer {
                app.endBackgroundTask(bgID); bgID = .invalid
            }
            // Timeout auto
            let didFinish = await withTaskGroup(of: Bool.self) { group -> Bool in
                group.addTask {
                    // TRANSFERS SUCCESS
                    await NCNetworking.shared.metadataTranfersSuccess.flush()
                    // BACKUP
                    await NCManageDatabase.shared.backupTableAccountToFileAsync()
                    // QUEUE
                    NCNetworking.shared.cancelAllQueue()
                    // LOG
                    nkLog(info: "Auto upload in background: \(tblAccount.autoUploadStart)")
                    nkLog(info: "Update in background: \(isBackgroundRefreshStatus)")
                    // LOCATION MANAGER
                    if CLLocationManager().authorizationStatus == .authorizedAlways && NCPreferences().location && tblAccount.autoUploadStart {
                        NCBackgroundLocationUploadManager.shared.start()
                    } else {
                        NCBackgroundLocationUploadManager.shared.stop()
                    }
                    // UPDATE SHARE GROUP ACCOUNTS
                    if let error = await NCAccount().updateAppsShareAccounts() {
                        nkLog(error: "Create Apps share accounts \(error.localizedDescription)")
                    }
                    // CLEAR OLDER FILES
                    await NCManageDatabase.shared.cleanTablesOcIds(account: tblAccount.account, userId: tblAccount.userId, urlBase: tblAccount.urlBase)
                    await NCUtilityFileSystem().cleanUpAsync()

                    return true
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 25 * 1_000_000_000) // ~25s
                    return false
                }
                return await group.next() ?? false
            }

            if !didFinish {
                nkLog(debug: "Flush timed out, will continue next launch")
            }
        }


    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let controller = SceneManager.shared.getController(scene: scene),
              let url = URLContexts.first?.url else { return }
        let scheme = url.scheme
        let action = url.host
        let versionApp = NCUtility().getVersionMaintenance()

        // Test version
        guard let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup),
              let lastVersion = groupDefaults.string(forKey: NCGlobal.shared.udLastVersion),
              lastVersion == versionApp else {
            return
        }

        func getMatchedAccount(userId: String, url: String) async -> tableAccount? {
            let tblAccounts = await NCManageDatabase.shared.getAllTableAccountAsync()

            for tblAccount in tblAccounts {
                let urlBase = URL(string: tblAccount.urlBase)
                if url.contains(urlBase?.host ?? "") && userId == tblAccount.userId {
                    await NCAccount().changeAccount(tblAccount.account, userProfile: nil, controller: controller)
                    // wait switch account
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    return tblAccount
                }
            }
            return nil
        }

        /*
         Example: nextcloud://open-action?action=create-voice-memo&&user=marinofaggiana&url=https://cloud.nextcloud.com
         */

        if scheme == global.appScheme && action == "open-action" {
            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                let queryItems = urlComponents.queryItems
                guard let actionScheme = queryItems?.filter({ $0.name == "action" }).first?.value,
                      let userScheme = queryItems?.filter({ $0.name == "user" }).first?.value,
                      let urlScheme = queryItems?.filter({ $0.name == "url" }).first?.value else {
                    return
                }

                Task {
                    if await getMatchedAccount(userId: userScheme, url: urlScheme) == nil {
                        let message = NSLocalizedString("_the_account_", comment: "") + " " + userScheme + NSLocalizedString("_of_", comment: "") + " " + urlScheme + " " + NSLocalizedString("_does_not_exist_", comment: "")
                        let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

                        controller.present(alertController, animated: true, completion: { })
                        return
                    }

                    switch actionScheme {
                    case self.global.actionUploadAsset:
                        NCAskAuthorization().askAuthorizationPhotoLibrary(controller: controller) { hasPermission in
                            if hasPermission {
                                NCPhotosPickerViewController(controller: controller, maxSelectedAssets: 0, singleSelectedMode: false)
                            }
                        }
                    case self.global.actionScanDocument:
                        NCDocumentCamera.shared.openScannerDocument(viewController: controller)
                    case self.global.actionTextDocument:
                        let session = SceneManager.shared.getSession(scene: scene)
                        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
                        guard let creator = capabilities.directEditingCreators.first(where: { $0.editor == "text" }) else {
                            return
                        }
                        let serverUrl = controller.currentServerUrl()
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + creator.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        await NCCreateDocument().createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "text", creatorId: creator.identifier, templateId: "document", account: session.account)
                    case self.global.actionVoiceMemo:
                        NCAskAuthorization().askAuthorizationAudioRecord(controller: controller) { hasPermission in
                            if hasPermission {
                                if let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as? NCAudioRecorderViewController {
                                    viewController.controller = controller
                                    viewController.modalTransitionStyle = .crossDissolve
                                    viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
                                    controller.present(viewController, animated: true, completion: nil)
                                }
                            }
                        }
                    default:
                        print("No action")
                    }
                }
            }
        }

        /*
         Example: nextcloud://open-file?path=Talk/IMG_0000123.jpg&user=marinofaggiana&link=https://cloud.nextcloud.com/f/123
         */

        else if scheme == self.global.appScheme && action == "open-file" {
            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var serverUrl: String = ""
                var fileName: String = ""
                let queryItems = urlComponents.queryItems
                guard let userScheme = queryItems?.filter({ $0.name == "user" }).first?.value,
                      let pathScheme = queryItems?.filter({ $0.name == "path" }).first?.value,
                      let linkScheme = queryItems?.filter({ $0.name == "link" }).first?.value else { return}

                Task {
                    guard let tblAccount = await getMatchedAccount(userId: userScheme, url: linkScheme) else {
                        guard let domain = URL(string: linkScheme)?.host else { return }

                        fileName = (pathScheme as NSString).lastPathComponent
                        let message = String(format: NSLocalizedString("_account_not_available_", comment: ""), userScheme, domain, fileName)
                        let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

                        controller.present(alertController, animated: true)
                        return
                    }
                    let davFiles = "remote.php/dav/files/" + tblAccount.userId

                    if pathScheme.contains("/") {
                        fileName = (pathScheme as NSString).lastPathComponent
                        serverUrl = tblAccount.urlBase + "/" + davFiles + "/" + (pathScheme as NSString).deletingLastPathComponent
                    } else {
                        fileName = pathScheme
                        serverUrl = tblAccount.urlBase + "/" + davFiles
                    }

                    NCDownloadAction.shared.openFileViewInFolder(serverUrl: serverUrl, fileNameBlink: nil, fileNameOpen: fileName, sceneIdentifier: controller.sceneIdentifier)
                }
            }

        /*
         Example: nextcloud://open-and-switch-account?user=marinofaggiana&url=https://cloud.nextcloud.com
         */

        } else if scheme == self.global.appScheme && action == "open-and-switch-account" {
            guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return
            }
            let queryItems = urlComponents.queryItems
            guard let userScheme = queryItems?.filter({ $0.name == "user" }).first?.value,
                  let urlScheme = queryItems?.filter({ $0.name == "url" }).first?.value else {
                return
            }

            Task {
                _ = await getMatchedAccount(userId: userScheme, url: urlScheme)
            }
        } else if let action {
            if DeepLink(rawValue: action) != nil {
                NCDeepLinkHandler().parseDeepLink(url, controller: controller)
            }
        } else {
            let applicationHandle = NCApplicationHandle()
            let isHandled = applicationHandle.applicationOpenURL(url)
            if isHandled {
                return
            } else {
                scene.open(url, options: nil)
            }
        }
    }

    private func showPrivacyProtectionWindow() {
        guard let windowScene = self.window?.windowScene else {
            return
        }

        self.privacyProtectionWindow = UIWindow(windowScene: windowScene)
        self.privacyProtectionWindow?.rootViewController = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()
        self.privacyProtectionWindow?.windowLevel = .alert + 1
        self.privacyProtectionWindow?.makeKeyAndVisible()
    }

    private func hidePrivacyProtectionWindow() {
        privacyProtectionWindow?.isHidden = true
        privacyProtectionWindow = nil
    }

    private func activateSceneForAccount(_ scene: UIScene,
                                         account: String,
                                         controller: NCMainTabBarController?) {
        guard !account.isEmpty else {
            return
        }

        if let window = SceneManager.shared.getWindow(scene: scene),
           let controller = SceneManager.shared.getController(scene: scene) {
            window.rootViewController = controller
            if NCPreferences().presentPasscode {
                NCPasscode.shared.presentPasscode(viewController: controller, delegate: self) {
                    NCPasscode.shared.enableTouchFaceID()
                }
            } else if NCPreferences().accountRequest {
                requestedAccount(controller: controller)
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            let num = await NCAutoUpload.shared.initAutoUpload()
            nkLog(start: "Auto upload with \(num) photo")

            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await NCService().startRequestServicesServer(account: account, controller: controller)

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await NCNetworking.shared.verifyZombie()
        }

        NotificationCenter.default.postOnMainThread(name: global.notificationCenterRichdocumentGrabFocus)
    }
}

// MARK: - Extension

extension SceneDelegate: NCPasscodeDelegate {
    func requestedAccount(controller: UIViewController?) {
        let tblAccounts = NCManageDatabase.shared.getAllTableAccount()
        if tblAccounts.count > 1, let accountRequestVC = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {
            accountRequestVC.controller = controller
            accountRequestVC.activeAccount = (controller as? NCMainTabBarController)?.account
            accountRequestVC.accounts = tblAccounts
            accountRequestVC.enableTimerProgress = true
            accountRequestVC.enableAddAccount = false
            accountRequestVC.dismissDidEnterBackground = false
            accountRequestVC.delegate = self
            accountRequestVC.startTimer(nil)

            let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
            let numberCell = tblAccounts.count
            let height = min(CGFloat(numberCell * Int(accountRequestVC.heightCell) + 45), screenHeighMax)

            let popup = NCPopupViewController(contentController: accountRequestVC, popupWidth: 300, popupHeight: height + 20)
            popup.backgroundAlpha = 0.8

            controller?.present(popup, animated: true)
        }
    }

    func passcodeReset(_ passcodeViewController: TOPasscodeViewController) {
        appDelegate?.resetApplication()
    }
}

extension SceneDelegate: NCAccountRequestDelegate {
    func accountRequestAddAccount() { }

    func accountRequestChangeAccount(account: String, controller: UIViewController?) {
        Task {
            await NCAccount().changeAccount(account, userProfile: nil, controller: controller as? NCMainTabBarController)
        }
    }
}

// MARK: - Scene Manager

final class SceneManager: @unchecked Sendable {
    static let shared = SceneManager()
    private var sceneController: [NCMainTabBarController: UIScene] = [:]

    func register(scene: UIScene, withRootViewController rootViewController: NCMainTabBarController) {
        sceneController[rootViewController] = scene
    }

    func getController(scene: UIScene?) -> NCMainTabBarController? {
        for controller in sceneController.keys {
            if sceneController[controller] == scene {
                return controller
            }
        }
        return nil
    }

    func getController(sceneIdentifier: String?) -> NCMainTabBarController? {
        if let sceneIdentifier {
            for controller in sceneController.keys {
                if sceneIdentifier == controller.sceneIdentifier {
                    return controller
                }
            }
        }
        return nil
    }

    func getControllers() -> [NCMainTabBarController] {
        return Array(sceneController.keys)
    }

    func getWindow(scene: UIScene?) -> UIWindow? {
        return (scene as? UIWindowScene)?.keyWindow
    }

    func getWindow(controller: NCMainTabBarController?) -> UIWindow? {
        guard let controller,
              let scene = sceneController[controller] else { return nil }
        return getWindow(scene: scene)
    }

    func getSceneIdentifier() -> [String] {
        var results: [String] = []
        for controller in sceneController.keys {
            results.append(controller.sceneIdentifier)
        }
        return results
    }

    func getSession(scene: UIScene?) -> NCSession.Session {
        let controller = SceneManager.shared.getController(scene: scene)
        return NCSession.shared.getSession(controller: controller)
    }
}
