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

import UIKit
import NextcloudKit
import WidgetKit
import SwiftEntryKit
import TOPasscodeViewController

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let appDelegate = UIApplication.shared.delegate as? AppDelegate
    private var privacyProtectionWindow: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene),
              let appDelegate else { return }
        self.window = UIWindow(windowScene: windowScene)

        if NCManageDatabase.shared.getActiveAccount() != nil {
            if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                SceneManager.shared.register(scene: scene, withRootViewController: controller)
                window?.rootViewController = controller
                window?.makeKeyAndVisible()
            }
        } else {
            if NCBrandOptions.shared.disable_intro {
                appDelegate.openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: false, windowForRootViewController: window)
            } else {
                if let viewController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() as? NCIntroViewController {
                    let navigationController = NCLoginNavigationController(rootViewController: viewController)
                    window?.rootViewController = navigationController
                    window?.makeKeyAndVisible()
                }
            }
        }

        appDelegate.startTimerErrorNetworking(scene: scene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("[DEBUG] Scene did disconnect")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene will enter in foreground")
        guard let appDelegate else { return }

        // In Login mode is possible ONLY 1 window
        if (UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }).count > 1,
           (appDelegate.activeLogin?.view.window != nil || appDelegate.activeLoginWeb?.view.window != nil) || (UIApplication.shared.firstWindow?.rootViewController is NCLoginNavigationController) {
            UIApplication.shared.allSceneSessionDestructionExceptFirst()
            return
        }
        guard !appDelegate.account.isEmpty else { return }

        hidePrivacyProtectionWindow()
        if let window = SceneManager.shared.getWindow(scene: scene), let controller = SceneManager.shared.getController(scene: scene) {
            window.rootViewController = controller
            if NCKeychain().presentPasscode {
                NCPasscode.shared.presentPasscode(viewController: controller, delegate: self) {
                    NCPasscode.shared.enableTouchFaceID()
                }
            } else if NCKeychain().accountRequest {
                requestedAccount(viewController: controller)
            }
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRichdocumentGrabFocus)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetwork, second: 2)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene did become active")

        NCSettingsBundleHelper.setVersionAndBuildNumber()
        NCSettingsBundleHelper.checkAndExecuteSettings(delay: 0.5)

        // START TIMER UPLOAD PROCESS
        NCNetworkingProcess.shared.startTimer(scene: scene)

        hidePrivacyProtectionWindow()

        if let appDelegate {
            NCService().startRequestServicesServer(account: appDelegate.account, user: appDelegate.user, userId: appDelegate.userId)
        }
        NCAutoUpload.shared.initAutoUpload(viewController: nil) { items in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Initialize Auto upload with \(items) uploads")
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene will resign active")
        guard let appDelegate,
              !appDelegate.account.isEmpty else { return }

        // STOP TIMER UPLOAD PROCESS
        NCNetworkingProcess.shared.stopTimer()

        if NCKeychain().privacyScreenEnabled {
            if SwiftEntryKit.isCurrentlyDisplaying {
                SwiftEntryKit.dismiss {
                    self.showPrivacyProtectionWindow()
                }
            } else {
                showPrivacyProtectionWindow()
            }
        }

        // Reload Widget
        WidgetCenter.shared.reloadAllTimelines()

        // Clear older files
        let days = NCKeychain().cleanUpDay
        let utilityFileSystem = NCUtilityFileSystem()
        utilityFileSystem.cleanUp(directory: utilityFileSystem.directoryProviderStorage, days: TimeInterval(days))
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene did enter in background")
        guard let appDelegate,
              !appDelegate.account.isEmpty else { return }

        if let autoUpload = NCManageDatabase.shared.getActiveAccount()?.autoUpload, autoUpload {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Auto upload: true")
            if UIApplication.shared.backgroundRefreshStatus == .available {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Auto upload in background: true")
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Auto upload in background: false")
            }
        } else {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Auto upload: false")
        }

        if let error = appDelegate.updateShareAccounts() {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Create share accounts \(error.localizedDescription)")
        }

        appDelegate.scheduleAppRefresh()
        appDelegate.scheduleAppProcessing()

        NCNetworking.shared.cancelAllQueue()
        NCNetworking.shared.cancelDataTask()
        NCNetworking.shared.cancelDownloadTasks()
        NCNetworking.shared.cancelUploadTasks()

        if NCKeychain().presentPasscode {
            showPrivacyProtectionWindow()
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let controller = SceneManager.shared.getController(scene: scene) as? NCMainTabBarController,
              let url = URLContexts.first?.url,
              let appDelegate else { return }
        let sceneIdentifier = controller.sceneIdentifier
        let account = appDelegate.account
        let scheme = url.scheme
        let action = url.host

        func getMatchedAccount(userId: String, url: String) -> tableAccount? {
            if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
                let urlBase = URL(string: activeAccount.urlBase)
                if url.contains(urlBase?.host ?? "") && userId == activeAccount.userId {
                   return activeAccount
                } else {
                    let accounts = NCManageDatabase.shared.getAllAccount()
                    for account in accounts {
                        let urlBase = URL(string: account.urlBase)
                        if url.contains(urlBase?.host ?? "") && userId == account.userId {
                            appDelegate.changeAccount(account.account, userProfile: nil) { }
                            return account
                        }
                    }
                }
            }
            return nil
        }

        /*
         Example: nextcloud://open-action?action=create-voice-memo&&user=marinofaggiana&url=https://cloud.nextcloud.com
         */

        if !account.isEmpty && scheme == NCGlobal.shared.appScheme && action == "open-action" {

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

                    let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: appDelegate.account)
                    let directEditingCreator = directEditingCreators!.first(where: { $0.editor == NCGlobal.shared.editorText})!
                    let serverUrl = controller.currentServerUrl()

                    Task {
                        let fileName = await NCNetworking.shared.createFileName(fileNameBase: NSLocalizedString("_untitled_", comment: "") + ".md", account: appDelegate.account, serverUrl: serverUrl)
                        let fileNamePath = NCUtilityFileSystem().getFileNamePath(String(describing: fileName), serverUrl: serverUrl, urlBase: appDelegate.urlBase, userId: appDelegate.userId)

                        NCCreateDocument().createDocument(controller: controller, fileNamePath: fileNamePath, fileName: String(describing: fileName), editorId: NCGlobal.shared.editorText, creatorId: directEditingCreator.identifier, templateId: NCGlobal.shared.templateDocument)
                    }

                case NCGlobal.shared.actionVoiceMemo:

                    NCAskAuthorization().askAuthorizationAudioRecord(viewController: controller) { hasPermission in
                        if hasPermission {
                            if let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as? NCAudioRecorderViewController {
                                viewController.serverUrl = controller.currentServerUrl()
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

        else if !account.isEmpty && scheme == NCGlobal.shared.appScheme && action == "open-file" {

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

                let davFiles = NextcloudKit.shared.nkCommonInstance.dav + "/files/" + appDelegate.userId

                if pathScheme.contains("/") {
                    fileName = (pathScheme as NSString).lastPathComponent
                    serverUrl = matchedAccount.urlBase + "/" + davFiles + "/" + (pathScheme as NSString).deletingLastPathComponent
                } else {
                    fileName = pathScheme
                    serverUrl = matchedAccount.urlBase + "/" + davFiles
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NCActionCenter.shared.openFileViewInFolder(serverUrl: serverUrl, fileNameBlink: nil, fileNameOpen: fileName, sceneIdentifier: sceneIdentifier)
                }
            }
            return

        /*
         Example: nextcloud://open-and-switch-account?user=marinofaggiana&url=https://cloud.nextcloud.com
         */

        } else if !account.isEmpty && scheme == NCGlobal.shared.appScheme && action == "open-and-switch-account" {
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
        } else if !account.isEmpty, let action {
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
    func requestedAccount(viewController: UIViewController?) {
        let accounts = NCManageDatabase.shared.getAllAccount()
        if accounts.count > 1, let accountRequestVC = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {
            accountRequestVC.activeAccount = NCManageDatabase.shared.getActiveAccount()
            accountRequestVC.accounts = accounts
            accountRequestVC.enableTimerProgress = true
            accountRequestVC.enableAddAccount = false
            accountRequestVC.dismissDidEnterBackground = false
            accountRequestVC.delegate = self
            accountRequestVC.startTimer()

            let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
            let numberCell = accounts.count
            let height = min(CGFloat(numberCell * Int(accountRequestVC.heightCell) + 45), screenHeighMax)

            let popup = NCPopupViewController(contentController: accountRequestVC, popupWidth: 300, popupHeight: height + 20)
            popup.backgroundAlpha = 0.8

            viewController?.present(popup, animated: true)
        }
    }

    func passcodeReset(_ passcodeViewController: TOPasscodeViewController) {
        appDelegate?.resetApplication()
    }
}

extension SceneDelegate: NCAccountRequestDelegate {
    func accountRequestAddAccount() { }

    func accountRequestChangeAccount(account: String) {
        appDelegate?.changeAccount(account, userProfile: nil) { }
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
}
