//
//  SceneDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/03/24.
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
import WidgetKit
import SwiftEntryKit
import TOPasscodeViewController

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let appDelegate = UIApplication.shared.delegate as? AppDelegate
    private var privacyProtectionWindow: UIWindow?
    private var isFirstScene: Bool = true

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene),
              let appDelegate else { return }
        self.window = UIWindow(windowScene: windowScene)

        if let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount() {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Account active \(activeTableAccount.account)")

            let capability = NCManageDatabase.shared.setCapabilities(account: activeTableAccount.account)
            NCBrandColor.shared.settingThemingColor(account: activeTableAccount.account)

            for tableAccount in NCManageDatabase.shared.getAllTableAccount() {
                NextcloudKit.shared.appendSession(account: tableAccount.account,
                                                  urlBase: tableAccount.urlBase,
                                                  user: tableAccount.user,
                                                  userId: tableAccount.userId,
                                                  password: NCKeychain().getPassword(account: tableAccount.account),
                                                  userAgent: userAgent,
                                                  nextcloudVersion: capability?.capabilityServerVersionMajor ?? 0,
                                                  groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
                NCSession.shared.appendSession(account: tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, userId: tableAccount.userId)
            }

            /// Main.storyboard
            if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                SceneManager.shared.register(scene: scene, withRootViewController: controller)
                window?.rootViewController = controller
                window?.makeKeyAndVisible()
                /// Set the ACCOUNT
                controller.account = activeTableAccount.account
            }
        } else {
            NCKeychain().removeAll()
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            if NCBrandOptions.shared.disable_intro {
                appDelegate.openLogin(selector: NCGlobal.shared.introLogin)
            } else {
                if let viewController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() as? NCIntroViewController {
                    let navigationController = NCLoginNavigationController(rootViewController: viewController)
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
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene will enter in foreground")
        let session = SceneManager.shared.getSession(scene: scene)

        // In Login mode is possible ONLY 1 window
        if (UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }).count > 1,
           (appDelegate?.activeLogin?.view.window != nil || appDelegate?.activeLoginWeb?.view.window != nil) || (UIApplication.shared.firstWindow?.rootViewController is NCLoginNavigationController) {
            UIApplication.shared.allSceneSessionDestructionExceptFirst()
            return
        }
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

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRichdocumentGrabFocus)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetwork, second: 2)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        let session = SceneManager.shared.getSession(scene: scene)
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene did become active")

        hidePrivacyProtectionWindow()

        NCService().startRequestServicesServer(account: session.account)

        NCAutoUpload.shared.initAutoUpload(viewController: nil, account: session.account) { num in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Initialize Auto upload with \(num) uploads")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            Task {
                await NCNetworking.shared.verifyZombie()
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene will resign active")
        /*
        NSFileProviderManager.removeAllDomains { _ in
            if !NCKeychain().disableFilesApp,
                NCManageDatabase.shared.getAllTableAccount().count > 1 {
                FileProviderDomain().registerDomains()
            }
        }
        */
        ///
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

        // Clear older files
        let days = NCKeychain().cleanUpDay
        let utilityFileSystem = NCUtilityFileSystem()
        utilityFileSystem.cleanUp(directory: utilityFileSystem.directoryProviderStorage, days: TimeInterval(days))
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene did enter in background")
        let session = SceneManager.shared.getSession(scene: scene)
        guard let tableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) else {
            return
        }

        if tableAccount.autoUpload {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Auto upload: true")
            if UIApplication.shared.backgroundRefreshStatus == .available {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Auto upload in background: true")
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Auto upload in background: false")
            }
        } else {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Auto upload: false")
        }

        if let error = NCAccount().updateAppsShareAccounts() {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Create Apps share accounts \(error.localizedDescription)")
        }

        appDelegate?.scheduleAppRefresh()
        appDelegate?.scheduleAppProcessing()

        NCNetworking.shared.cancelAllQueue()

        if NCKeychain().presentPasscode {
            showPrivacyProtectionWindow()
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let controller = SceneManager.shared.getController(scene: scene) as? NCMainTabBarController,
              let url = URLContexts.first?.url else { return }
        let scheme = url.scheme
        let action = url.host
        let session = SceneManager.shared.getSession(scene: scene)
        guard !session.account.isEmpty else { return }

        func getMatchedAccount(userId: String, url: String) -> tableAccount? {
            if let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount() {
                let urlBase = URL(string: activeTableAccount.urlBase)
                if url.contains(urlBase?.host ?? "") && userId == activeTableAccount.userId {
                   return activeTableAccount
                } else {
                    for tableAccount in NCManageDatabase.shared.getAllTableAccount() {
                        let urlBase = URL(string: tableAccount.urlBase)
                        if url.contains(urlBase?.host ?? "") && userId == tableAccount.userId {
                            NCAccount().changeAccount(tableAccount.account, userProfile: nil, controller: controller) { }
                            return tableAccount
                        }
                    }
                }
            }
            return nil
        }

        /*
         Example: nextcloud://open-action?action=create-voice-memo&&user=marinofaggiana&url=https://cloud.nextcloud.com
         */

        if scheme == NCGlobal.shared.appScheme && action == "open-action" {

            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                let queryItems = urlComponents.queryItems
                guard let actionScheme = queryItems?.filter({ $0.name == "action" }).first?.value,
                      let userScheme = queryItems?.filter({ $0.name == "user" }).first?.value,
                      let urlScheme = queryItems?.filter({ $0.name == "url" }).first?.value else { return }
                if getMatchedAccount(userId: userScheme, url: urlScheme) == nil {
                    let message = NSLocalizedString("_the_account_", comment: "") + " " + userScheme + NSLocalizedString("_of_", comment: "") + " " + urlScheme + " " + NSLocalizedString("_does_not_exist_", comment: "")
                    let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

                    controller.present(alertController, animated: true, completion: { })
                    return
                }

                switch actionScheme {
                case NCGlobal.shared.actionUploadAsset:

                    NCAskAuthorization().askAuthorizationPhotoLibrary(viewController: controller) { hasPermission in
                        if hasPermission {
                            NCPhotosPickerViewController(controller: controller, maxSelectedAssets: 0, singleSelectedMode: false)
                        }
                    }

                case NCGlobal.shared.actionScanDocument:

                    NCDocumentCamera.shared.openScannerDocument(viewController: controller)

                case NCGlobal.shared.actionTextDocument:

                    let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: session.account)
                    let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorText})!
                    let serverUrl = controller.currentServerUrl()

                    Task {
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + ".md", account: session.account, serverUrl: serverUrl)
                        let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, session: session)

                        NCCreateDocument().createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorText, creatorId: directEditingCreator.identifier, templateId: NCGlobal.shared.templateDocument, account: session.account)
                    }

                case NCGlobal.shared.actionVoiceMemo:

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
            return
        }

        /*
         Example: nextcloud://open-file?path=Talk/IMG_0000123.jpg&user=marinofaggiana&link=https://cloud.nextcloud.com/f/123
         */

        else if scheme == NCGlobal.shared.appScheme && action == "open-file" {

            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {

                var serverUrl: String = ""
                var fileName: String = ""
                let queryItems = urlComponents.queryItems
                guard let userScheme = queryItems?.filter({ $0.name == "user" }).first?.value,
                      let pathScheme = queryItems?.filter({ $0.name == "path" }).first?.value,
                      let linkScheme = queryItems?.filter({ $0.name == "link" }).first?.value else { return}

                guard let matchedAccount = getMatchedAccount(userId: userScheme, url: linkScheme) else {
                    guard let domain = URL(string: linkScheme)?.host else { return }
                    fileName = (pathScheme as NSString).lastPathComponent
                    let message = String(format: NSLocalizedString("_account_not_available_", comment: ""), userScheme, domain, fileName)
                    let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

                    controller.present(alertController, animated: true, completion: { })
                    return
                }

                let davFiles = "remote.php/dav/files/" + session.userId

                if pathScheme.contains("/") {
                    fileName = (pathScheme as NSString).lastPathComponent
                    serverUrl = matchedAccount.urlBase + "/" + davFiles + "/" + (pathScheme as NSString).deletingLastPathComponent
                } else {
                    fileName = pathScheme
                    serverUrl = matchedAccount.urlBase + "/" + davFiles
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NCActionCenter.shared.openFileViewInFolder(serverUrl: serverUrl, fileNameBlink: nil, fileNameOpen: fileName, sceneIdentifier: controller.sceneIdentifier)
                }
            }
            return

        /*
         Example: nextcloud://open-and-switch-account?user=marinofaggiana&url=https://cloud.nextcloud.com
         */

        } else if scheme == NCGlobal.shared.appScheme && action == "open-and-switch-account" {
            guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
            let queryItems = urlComponents.queryItems
            guard let userScheme = queryItems?.filter({ $0.name == "user" }).first?.value,
                  let urlScheme = queryItems?.filter({ $0.name == "url" }).first?.value else { return }
            // If the account doesn't exist, return false which will open the app without switching
            if getMatchedAccount(userId: userScheme, url: urlScheme) == nil {
                return
            }
            // Otherwise open the app and switch accounts
            return
        } else if let action {
            if DeepLink(rawValue: action) != nil {
                NCDeepLinkHandler().parseDeepLink(url, controller: controller)
            }
            return
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

        privacyProtectionWindow = UIWindow(windowScene: windowScene)
        privacyProtectionWindow?.rootViewController = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()
        privacyProtectionWindow?.windowLevel = .alert + 1
        privacyProtectionWindow?.makeKeyAndVisible()
    }

    private func hidePrivacyProtectionWindow() {
        privacyProtectionWindow?.isHidden = true
        privacyProtectionWindow = nil
    }
}

// MARK: - Extension

extension SceneDelegate: NCPasscodeDelegate {
    func requestedAccount(controller: UIViewController?) {
        let tableAccounts = NCManageDatabase.shared.getAllTableAccount()
        if tableAccounts.count > 1, let accountRequestVC = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {
            accountRequestVC.controller = controller
            accountRequestVC.activeAccount = (controller as? NCMainTabBarController)?.account
            accountRequestVC.accounts = tableAccounts
            accountRequestVC.enableTimerProgress = true
            accountRequestVC.enableAddAccount = false
            accountRequestVC.dismissDidEnterBackground = false
            accountRequestVC.delegate = self
            accountRequestVC.startTimer()

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

class SceneManager {
    static let shared = SceneManager()
    private var sceneController: [NCMainTabBarController: UIScene] = [:]

    func register(scene: UIScene, withRootViewController rootViewController: NCMainTabBarController) {
        sceneController[rootViewController] = scene
    }

    func getController(scene: UIScene?) -> UIViewController? {
        for controller in sceneController.keys {
            if sceneController[controller] == scene {
                return controller
            }
        }
        return nil
    }

    func getController(sceneIdentifier: String) -> NCMainTabBarController? {
        for controller in sceneController.keys {
            if sceneIdentifier == controller.sceneIdentifier {
                return controller
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
        let controller = SceneManager.shared.getController(scene: scene) as? NCMainTabBarController
        return NCSession.shared.getSession(controller: controller)
    }
}
