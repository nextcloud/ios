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
    private var isFirstScene: Bool = true
    private let database = NCManageDatabase.shared
    private let global = NCGlobal.shared

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene)
        else {
            return
        }

        self.window = UIWindow(windowScene: windowScene)
        if !NCKeychain().appearanceAutomatic {
            self.window?.overrideUserInterfaceStyle = NCKeychain().appearanceInterfaceStyle
        }

        if let activeTableAccount = self.database.getActiveTableAccount() {
            nkLog(debug: "Account active \(activeTableAccount.account)")

            NCBrandColor.shared.settingThemingColor(account: activeTableAccount.account)
            Task {
                await NCNetworkingProcess.shared.setCurrentAccount(activeTableAccount.account)
            }
            for tblAccount in self.database.getAllTableAccount() {
                NextcloudKit.shared.appendSession(account: tblAccount.account,
                                                  urlBase: tblAccount.urlBase,
                                                  user: tblAccount.user,
                                                  userId: tblAccount.userId,
                                                  password: NCKeychain().getPassword(account: tblAccount.account),
                                                  userAgent: userAgent,
                                                  httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                                  httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                                  httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                                  groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
                Task {
                    await self.database.applyCachedCapabilitiesAsync(account: tblAccount.account)

                    try? await FileProviderDomain().ensureDomainRegistered(userId: tblAccount.userId, urlBase: tblAccount.urlBase)
                }
                NCSession.shared.appendSession(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user, userId: tblAccount.userId)
            }

            /// Main.storyboard
            if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                SceneManager.shared.register(scene: scene, withRootViewController: controller)
                /// Set the ACCOUNT
                controller.account = activeTableAccount.account
                ///
                window?.rootViewController = controller
                window?.makeKeyAndVisible()
            }
        } else {
            NCKeychain().removeAll()
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

    func sceneDidDisconnect(_ scene: UIScene) {
        print("[DEBUG] Scene did disconnect")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        let session = SceneManager.shared.getSession(scene: scene)
        let controller = SceneManager.shared.getController(scene: scene)
        guard !session.account.isEmpty else { return }

        hidePrivacyProtectionWindow()

        if let window = SceneManager.shared.getWindow(scene: scene), let controller = SceneManager.shared.getController(scene: scene) {
            window.rootViewController = controller
            if NCKeychain().presentPasscode {
                NCPasscode.shared.presentPasscode(viewController: controller, delegate: self) {
                    NCPasscode.shared.enableTouchFaceID()
                }
            } else if NCKeychain().accountRequest {
                requestedAccount(controller: controller)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Task {
                if let tableAccount = await self.database.getTableAccountAsync(account: session.account) {
                    let num = await NCAutoUpload.shared.initAutoUpload(tblAccount: tableAccount)
                    nkLog(start: "Auto upload with \(num) photo")
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NCService().startRequestServicesServer(account: session.account, controller: controller)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            Task {
                await NCNetworking.shared.verifyZombie()
            }
        }

        NotificationCenter.default.postOnMainThread(name: global.notificationCenterRichdocumentGrabFocus)

    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        let session = SceneManager.shared.getSession(scene: scene)
        guard !session.account.isEmpty else { return }

        hidePrivacyProtectionWindow()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        nkLog(debug: "Scene will resign active")

        WidgetCenter.shared.reloadAllTimelines()

        let session = SceneManager.shared.getSession(scene: scene)
        guard !session.account.isEmpty else { return }

        if NCKeychain().privacyScreenEnabled {
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
        Task {
            await database.backupTableAccountToFileAsync()
        }
        let session = SceneManager.shared.getSession(scene: scene)
        guard let tableAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) else {
            return
        }

        nkLog(info: "Auto upload in background: \(tableAccount.autoUploadStart)")
        nkLog(info: "Update in background: \(UIApplication.shared.backgroundRefreshStatus == .available)")

        if CLLocationManager().authorizationStatus == .authorizedAlways && NCKeychain().location && tableAccount.autoUploadStart {
            NCBackgroundLocationUploadManager.shared.start()
        } else {
            NCBackgroundLocationUploadManager.shared.stop()
        }

        if let error = NCAccount().updateAppsShareAccounts() {
            nkLog(error: "Create Apps share accounts \(error.localizedDescription)")
        }

        NCNetworking.shared.cancelAllTaskForGoInBackground()

        if NCKeychain().presentPasscode {
            showPrivacyProtectionWindow()
        }

        // Clear older files
        let days = NCKeychain().cleanUpDay
        let utilityFileSystem = NCUtilityFileSystem()
        utilityFileSystem.cleanUp(session: session, days: TimeInterval(days))
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let controller = SceneManager.shared.getController(scene: scene),
              let url = URLContexts.first?.url else { return }
        let scheme = url.scheme
        let action = url.host

        func getMatchedAccount(userId: String, url: String) async -> tableAccount? {
            let tblAccounts = await self.database.getAllTableAccountAsync()

            for tblAccount in tblAccounts {
                let urlBase = URL(string: tblAccount.urlBase)
                if url.contains(urlBase?.host ?? "") && userId == tblAccount.userId {
                    await NCAccount().changeAccountAsync(tblAccount.account, userProfile: nil, controller: controller)
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
                        let capabilities = NKCapabilities.shared.getCapabilitiesBlocking(for: session.account)
                        guard let creator = capabilities.directEditingCreators.first(where: { $0.editor == "text" }) else {
                            return
                        }
                        let serverUrl = controller.currentServerUrl()
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + "." + creator.ext, account: session.account, serverUrl: serverUrl)
                        let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        NCCreateDocument().createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: "text", creatorId: creator.identifier, templateId: "document", account: session.account)
                    case self.global.actionVoiceMemo:
                        NCAskAuthorization().askAuthorizationAudioRecord(viewController: controller) { hasPermission in
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

                        controller.present(alertController, animated: true, completion: { })
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
}

// MARK: - Extension

extension SceneDelegate: NCPasscodeDelegate {
    func requestedAccount(controller: UIViewController?) {
        let tableAccounts = self.database.getAllTableAccount()
        if tableAccounts.count > 1, let accountRequestVC = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {
            accountRequestVC.controller = controller
            accountRequestVC.activeAccount = (controller as? NCMainTabBarController)?.account
            accountRequestVC.accounts = tableAccounts
            accountRequestVC.enableTimerProgress = true
            accountRequestVC.enableAddAccount = false
            accountRequestVC.dismissDidEnterBackground = false
            accountRequestVC.delegate = self
            accountRequestVC.startTimer(nil)

            let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
            let numberCell = tableAccounts.count
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
        NCAccount().changeAccount(account, userProfile: nil, controller: controller as? NCMainTabBarController) { }
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
