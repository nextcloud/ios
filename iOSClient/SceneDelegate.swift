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

        if appDelegate.account.isEmpty {
            if NCBrandOptions.shared.disable_intro {
                appDelegate.openLogin(viewController: nil, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            } else {
                if let viewController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() {
                    let navigationController = NCLoginNavigationController(rootViewController: viewController)
                    window?.rootViewController = navigationController
                    window?.makeKeyAndVisible()
                }
            }
        } else {
            if let tabBarController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                window?.rootViewController = tabBarController
                window?.makeKeyAndVisible()
            }
            NCPasscode.shared.presentPasscode(delegate: appDelegate) {
                NCPasscode.shared.enableTouchFaceID()
            }
        }
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
        NCNetworkingProcess.shared.startTimer()

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

        let activeAccount = NCManageDatabase.shared.getActiveAccount()

        if let autoUpload = activeAccount?.autoUpload, autoUpload {
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
        NCPasscode.shared.presentPasscode(delegate: appDelegate) { }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationDidEnterBackground)
    }
}
