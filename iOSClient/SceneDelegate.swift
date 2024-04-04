//
//  SceneDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import NextcloudKit
import WidgetKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let appDelegate = UIApplication.shared.delegate as? AppDelegate

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene),
              let appDelegate else { return }
        self.window = UIWindow(windowScene: windowScene)

        if NCManageDatabase.shared.getActiveAccount() != nil {
            if let tabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                SceneManager.shared.register(scene: scene, withRootViewController: tabBarController)
                window?.rootViewController = tabBarController
                window?.makeKeyAndVisible()
            }
            if let viewController = window?.rootViewController {
                NCPasscode.shared.presentPasscode(viewController: viewController, delegate: appDelegate) {
                    NCPasscode.shared.enableTouchFaceID()
                }
            }
        } else {
            if NCBrandOptions.shared.disable_intro {
                appDelegate.openLogin(viewController: nil, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            } else {
                if let viewController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() as? NCIntroViewController {
                    viewController.scene = scene
                    let navigationController = NCLoginNavigationController(rootViewController: viewController)
                    window?.rootViewController = navigationController
                    window?.makeKeyAndVisible()
                }
            }
        }

        appDelegate.startTimerErrorNetworking(scene: scene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene did disconnect")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene will enter in foreground")
        guard let appDelegate,
              !appDelegate.account.isEmpty else { return }

        NCPasscode.shared.enableTouchFaceID()

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationWillEnterForeground)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRichdocumentGrabFocus)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetwork, second: 2)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene did become active")

        NCSettingsBundleHelper.setVersionAndBuildNumber()
        NCSettingsBundleHelper.checkAndExecuteSettings(delay: 0.5)

        // START TIMER UPLOAD PROCESS
        NCNetworkingProcess.shared.startTimer(scene: scene)

        if !NCAskAuthorization().isRequesting {
            NCPasscode.shared.hidePrivacyProtectionWindow()
        }

        NCService().startRequestServicesServer()

        NCAutoUpload.shared.initAutoUpload(viewController: nil) { items in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Initialize Auto upload with \(items) uploads")
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationDidBecomeActive)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene will resign active")
        guard let appDelegate,
              !appDelegate.account.isEmpty else { return }

        // STOP TIMER UPLOAD PROCESS
        NCNetworkingProcess.shared.stopTimer()

        if NCKeychain().privacyScreenEnabled {
            NCPasscode.shared.showPrivacyProtectionWindow()
        }

        // Reload Widget
        WidgetCenter.shared.reloadAllTimelines()

        // Clear older files
        let days = NCKeychain().cleanUpDay
        let utilityFileSystem = NCUtilityFileSystem()
        utilityFileSystem.cleanUp(directory: utilityFileSystem.directoryProviderStorage, days: TimeInterval(days))

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationWillResignActive)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Scene did enter in background")
        guard let appDelegate,
              !appDelegate.account.isEmpty else { return }

        if let viewController = SceneManager.shared.getRootViewController(scene: scene) {
            NCPasscode.shared.presentPasscode(viewController: viewController, delegate: appDelegate) { }
        }

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
        NCNetworking.shared.cancelDownloadTasks()
        NCNetworking.shared.cancelUploadTasks()

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationDidEnterBackground)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let rootViewController = SceneManager.shared.getRootViewController(scene: scene) as? NCMainTabBarController,
              let url = URLContexts.first?.url,
              let appDelegate else { return }
        let sceneIdentifier = rootViewController.sceneIdentifier
        let account = appDelegate.account
        let scheme = url.scheme
        let action = url.host
        var fileName: String = ""
        var serverUrl: String = ""

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
                            appDelegate.changeAccount(account.account, userProfile: nil)
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

                    rootViewController.present(alertController, animated: true, completion: { })
                    return
                }

                switch actionScheme {
                case NCGlobal.shared.actionUploadAsset:

                    NCAskAuthorization().askAuthorizationPhotoLibrary(viewController: rootViewController) { hasPermission in
                        if hasPermission {
                            NCPhotosPickerViewController(viewController: rootViewController, maxSelectedAssets: 0, singleSelectedMode: false)
                        }
                    }

                case NCGlobal.shared.actionScanDocument:

                    NCDocumentCamera.shared.openScannerDocument(viewController: rootViewController)

                case NCGlobal.shared.actionTextDocument:

                    guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController(),
                          let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: account),
                          let directEditingCreator = directEditingCreators.first(where: { $0.editor == NCGlobal.shared.editorText}),
                          let viewController = (navigationController as? UINavigationController)?.topViewController as? NCCreateFormUploadDocuments else { return }

                    navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                    viewController.editorId = NCGlobal.shared.editorText
                    viewController.creatorId = directEditingCreator.identifier
                    viewController.typeTemplate = NCGlobal.shared.templateDocument
                    viewController.serverUrl = appDelegate.activeServerUrl
                    viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")

                    rootViewController.present(navigationController, animated: true, completion: nil)

                case NCGlobal.shared.actionVoiceMemo:

                    NCAskAuthorization().askAuthorizationAudioRecord(viewController: rootViewController) { hasPermission in
                        if hasPermission {
                            if let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as? NCAudioRecorderViewController {
                                viewController.modalTransitionStyle = .crossDissolve
                                viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
                                rootViewController.present(viewController, animated: true, completion: nil)
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

                    rootViewController.present(alertController, animated: true, completion: { })
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
}

class SceneManager {
    static let shared = SceneManager()
    private var sceneRootViewController: [NCMainTabBarController: UIScene] = [:]

    func getRootViewController(scene: UIScene?) -> UIViewController? {
        return (scene as? UIWindowScene)?.keyWindow?.rootViewController
    }

    func register(scene: UIScene, withRootViewController rootViewController: NCMainTabBarController) {
        sceneRootViewController[rootViewController] = scene
    }

    func getSceneIdentifier() -> [String] {
        var results: [String] = []
        for mainTabBarController in sceneRootViewController.keys {
            results.append(mainTabBarController.sceneIdentifier)
        }
        return results
    }

    func getMainTabBarController(sceneIdentifier: String) -> NCMainTabBarController? {
        for mainTabBarController in sceneRootViewController.keys {
            if sceneIdentifier == mainTabBarController.sceneIdentifier {
                return mainTabBarController
            }
        }
        return nil
    }
}
