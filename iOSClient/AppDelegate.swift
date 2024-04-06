//
//  AppDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 04/09/14 (19/02/21 swift).
//  Copyright (c) 2014 Marino Faggiana. All rights reserved.
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
import BackgroundTasks
import NextcloudKit
import TOPasscodeViewController
import LocalAuthentication
import Firebase
import WidgetKit
import Queuer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, NCUserBaseUrl {

    var backgroundSessionCompletionHandler: (() -> Void)?

    @objc var account: String = ""
    @objc var urlBase: String = ""
    @objc var user: String = ""
    @objc var userId: String = ""
    @objc var password: String = ""

    var activeLogin: NCLogin?
    var activeLoginWeb: NCLoginWeb?
    var activeServerUrl: String = ""
    @objc var activeViewController: UIViewController?
    var mainTabBar: NCMainTabBar?
    var activeMetadata: tableMetadata?
    let listFilesVC = ThreadSafeDictionary<String, NCFiles>()

    var disableSharesView: Bool = false
    var documentPickerViewController: NCDocumentPickerViewController?
    private var timerErrorNetworking: Timer?
    var timerErrorNetworkingDisabled: Bool = false
    var isAppRefresh: Bool = false
    var isProcessingTask: Bool = false

    var isUiTestingEnabled: Bool {
        return ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if isUiTestingEnabled {
            deleteAllAccounts()
        }
        let utilityFileSystem = NCUtilityFileSystem()
        let utility = NCUtility()

        NCSettingsBundleHelper.checkAndExecuteSettings(delay: 0)

        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionApp())

        UserDefaults.standard.register(defaults: ["UserAgent": userAgent])
        if !NCKeychain().disableCrashservice, !NCBrandOptions.shared.disable_crash_service {
            FirebaseApp.configure()
        }

        utilityFileSystem.createDirectoryStandard()
        utilityFileSystem.emptyTemporaryDirectory()
        utilityFileSystem.clearCacheDirectory("com.limit-point.LivePhoto")

        // Activated singleton
        _ = NCActionCenter.shared
        _ = NCNetworking.shared

        NextcloudKit.shared.setup(delegate: NCNetworking.shared)
        NextcloudKit.shared.setup(userAgent: userAgent)

        var levelLog = 0
        NextcloudKit.shared.nkCommonInstance.pathLog = utilityFileSystem.directoryGroup

        if NCBrandOptions.shared.disable_log {

            utilityFileSystem.removeFile(atPath: NextcloudKit.shared.nkCommonInstance.filenamePathLog)
            utilityFileSystem.removeFile(atPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/" + NextcloudKit.shared.nkCommonInstance.filenameLog)

        } else {

            levelLog = NCKeychain().logLevel
            NextcloudKit.shared.nkCommonInstance.levelLog = levelLog
            NextcloudKit.shared.nkCommonInstance.copyLogToDocumentDirectory = true
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start session with level \(levelLog) " + versionNextcloudiOS)
        }

        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Account active \(activeAccount.account)")
            if NCKeychain().getPassword(account: activeAccount.account).isEmpty {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] PASSWORD NOT FOUND for \(activeAccount.account)")
            }

            account = activeAccount.account
            urlBase = activeAccount.urlBase
            user = activeAccount.user
            userId = activeAccount.userId
            password = NCKeychain().getPassword(account: account)

            NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: urlBase)
            NCManageDatabase.shared.setCapabilities(account: account)

            NCBrandColor.shared.settingThemingColor(account: activeAccount.account)
            DispatchQueue.global().async {
                NCImageCache.shared.createMediaCache(account: self.account, withCacheSize: true)
            }

        } else {

            NCKeychain().removeAll()
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        }

        NCBrandColor.shared.createUserColors()
        NCImageCache.shared.createImagesCache()

        // Push Notification & display notification
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

        if !utility.isSimulatorOrTestFlight() {
            let review = NCStoreReview()
            review.incrementAppRuns()
            review.showStoreReview()
        }

        // Background task register
        BGTaskScheduler.shared.register(forTaskWithIdentifier: NCGlobal.shared.refreshTask, using: nil) { task in
            self.handleAppRefresh(task)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: NCGlobal.shared.processingTask, using: nil) { task in
            self.handleProcessingTask(task)
        }

        return true
    }

    // L'applicazione terminerà
    func applicationWillTerminate(_ application: UIApplication) {

        if UIApplication.shared.backgroundRefreshStatus == .available {

            let content = UNMutableNotificationContent()
            content.title = NCBrandOptions.shared.brand
            content.body = NSLocalizedString("_keep_running_", comment: "")
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.add(req)
        }

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] bye bye")
    }

    // MARK: - Background Task

    /*
    @discussion Schedule a refresh task request to ask that the system launch your app briefly so that you can download data and keep your app's contents up-to-date. The system will fulfill this request intelligently based on system conditions and app usage.
     < MAX 30 seconds >
     */
    func scheduleAppRefresh() {

        let request = BGAppRefreshTaskRequest(identifier: NCGlobal.shared.refreshTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Refresh after 60 seconds.
        do {
            try BGTaskScheduler.shared.submit(request)
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Refresh task: ok")
        } catch {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Refresh task failed to submit request: \(error)")
        }
    }

    /*
     @discussion Schedule a processing task request to ask that the system launch your app when conditions are favorable for battery life to handle deferrable, longer-running processing, such as syncing, database maintenance, or similar tasks. The system will attempt to fulfill this request to the best of its ability within the next two days as long as the user has used your app within the past week.
     < MAX over 1 minute >
     */
    func scheduleAppProcessing() {

        let request = BGProcessingTaskRequest(identifier: NCGlobal.shared.processingTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // Refresh after 5 minutes.
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Processing task: ok")
        } catch {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Background Processing task failed to submit request: \(error)")
        }
    }

    func handleAppRefresh(_ task: BGTask) {
        scheduleAppRefresh()

        if isProcessingTask {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] ProcessingTask already in progress, abort.")
            return task.setTaskCompleted(success: true)
        }
        isAppRefresh = true

        handleAppRefreshProcessingTask(taskText: "AppRefresh") {
            task.setTaskCompleted(success: true)
            self.isAppRefresh = false
        }
    }

    func handleProcessingTask(_ task: BGTask) {
        scheduleAppProcessing()

        if isAppRefresh {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] AppRefresh already in progress, abort.")
            return task.setTaskCompleted(success: true)
        }
        isProcessingTask = true

        handleAppRefreshProcessingTask(taskText: "ProcessingTask") {
            task.setTaskCompleted(success: true)
            self.isProcessingTask = false
        }
    }

    func handleAppRefreshProcessingTask(taskText: String, completion: @escaping () -> Void = {}) {
        Task {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] \(taskText) start handle")
            let items = await NCAutoUpload.shared.initAutoUpload()
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] \(taskText) auto upload with \(items) uploads")
            let results = await NCNetworkingProcess.shared.start(scene: nil)
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] \(taskText) networking process with download: \(results.counterDownloading) upload: \(results.counterUploading)")

            if taskText == "ProcessingTask",
               items == 0, results.counterDownloading == 0, results.counterUploading == 0,
               let directories = NCManageDatabase.shared.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", self.account), sorted: "offlineDate", ascending: true) {
                for directory: tableDirectory in directories {
                    // only 3 time for day
                    if let offlineDate = directory.offlineDate, offlineDate.addingTimeInterval(28800) > Date() {
                        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] \(taskText) skip synchronization for \(directory.serverUrl) in date \(offlineDate)")
                        continue
                    }
                    let results = await NCNetworking.shared.synchronization(account: self.account, serverUrl: directory.serverUrl, add: false)
                    NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] \(taskText) end synchronization for \(directory.serverUrl), errorCode: \(results.errorCode), item: \(results.items)")
                }
            }

            let counter = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "account == %@ AND (session == %@ || session == %@) AND status != %d", self.account, NCNetworking.shared.sessionDownloadBackground, NCNetworking.shared.sessionUploadBackground, NCGlobal.shared.metadataStatusNormal))?.count ?? 0
            UIApplication.shared.applicationIconBadgeNumber = counter

            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] \(taskText) completion handle")
            completion()
        }
    }

    // MARK: - Background Networking Session

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start handle Events For Background URLSession: \(identifier)")
        WidgetCenter.shared.reloadAllTimelines()
        backgroundSessionCompletionHandler = completionHandler
    }

    // MARK: - Push Notifications

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        if let pref = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroups),
           let data = pref.object(forKey: "NOTIFICATION_DATA") as? [String: AnyObject] {
            nextcloudPushNotificationAction(data: data)
            pref.set(nil, forKey: "NOTIFICATION_DATA")
        }

        completionHandler()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NCNetworking.shared.checkPushNotificationServerProxyCertificateUntrusted(viewController: UIApplication.shared.firstWindow?.rootViewController) { error in
            if error == .success {
                NCPushNotification.shared().registerForRemoteNotifications(withDeviceToken: deviceToken)
            }
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NCPushNotification.shared().applicationdidReceiveRemoteNotification(userInfo) { result in
            completionHandler(result)
        }
    }

    func nextcloudPushNotificationAction(data: [String: AnyObject]) {
        guard let data = NCApplicationHandle().nextcloudPushNotificationAction(data: data) else { return }
        var findAccount: Bool = false

        if let accountPush = data["account"] as? String {
            if accountPush == self.account {
                findAccount = true
            } else {
                let accounts = NCManageDatabase.shared.getAllAccount()
                for account in accounts {
                    if account.account == accountPush {
                        self.changeAccount(account.account, userProfile: nil)
                        findAccount = true
                    }
                }
            }
            if findAccount, let viewController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? NCNotification {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let navigationController = UINavigationController(rootViewController: viewController)
                    navigationController.modalPresentationStyle = .fullScreen
                    UIApplication.shared.firstWindow?.rootViewController?.present(navigationController, animated: true)
                }
            } else if !findAccount {
                let message = NSLocalizedString("_the_account_", comment: "") + " " + accountPush + " " + NSLocalizedString("_does_not_exist_", comment: "")
                let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                UIApplication.shared.firstWindow?.rootViewController?.present(alertController, animated: true, completion: { })
            }
        }
    }

    // MARK: - Login & checkErrorNetworking

    @objc func openLogin(viewController: UIViewController?, selector: Int, openLoginWeb: Bool, scene: UIScene? = nil) {

        // [WEBPersonalized] [AppConfig]
        if NCBrandOptions.shared.use_login_web_personalized || NCBrandOptions.shared.use_AppConfig {

            if activeLoginWeb?.view.window == nil {
                activeLoginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb
                activeLoginWeb?.scene = scene
                activeLoginWeb?.urlBase = NCBrandOptions.shared.loginBaseUrl
                showLoginViewController(activeLoginWeb, contextViewController: viewController, scene: scene)
            }
            return
        }

        // Nextcloud standard login
        if selector == NCGlobal.shared.introSignup {

            if activeLoginWeb?.view.window == nil {
                activeLoginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb
                activeLoginWeb?.scene = scene
                if selector == NCGlobal.shared.introSignup {
                    activeLoginWeb?.urlBase = NCBrandOptions.shared.linkloginPreferredProviders
                } else {
                    activeLoginWeb?.urlBase = self.urlBase
                }
                showLoginViewController(activeLoginWeb, contextViewController: viewController, scene: scene)
            }

        } else if NCBrandOptions.shared.disable_intro && NCBrandOptions.shared.disable_request_login_url {

            if activeLoginWeb?.view.window == nil {
                activeLoginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb
                activeLoginWeb?.scene = scene
                activeLoginWeb?.urlBase = NCBrandOptions.shared.loginBaseUrl
                showLoginViewController(activeLoginWeb, contextViewController: viewController, scene: scene)
            }

        } else if openLoginWeb {

            // Used also for reinsert the account (change passwd)
            if activeLoginWeb?.view.window == nil {
                activeLoginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb
                activeLoginWeb?.scene = scene
                activeLoginWeb?.urlBase = urlBase
                activeLoginWeb?.user = user
                showLoginViewController(activeLoginWeb, contextViewController: viewController, scene: scene)
            }

        } else {

            if activeLogin?.view.window == nil {
                activeLogin = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLogin") as? NCLogin
                activeLogin?.scene = scene
                showLoginViewController(activeLogin, contextViewController: viewController, scene: scene)
            }
        }
    }

    func showLoginViewController(_ viewController: UIViewController?, contextViewController: UIViewController?, scene: UIScene?) {
        if contextViewController == nil, let window = SceneManager.shared.getWindow(scene: scene) {
            if let viewController = viewController {
                let navigationController = NCLoginNavigationController(rootViewController: viewController)
                navigationController.navigationBar.barStyle = .black
                navigationController.navigationBar.tintColor = NCBrandColor.shared.customerText
                navigationController.navigationBar.barTintColor = NCBrandColor.shared.customer
                navigationController.navigationBar.isTranslucent = false
                window.rootViewController = navigationController
                window.makeKeyAndVisible()
            }
        } else if contextViewController is UINavigationController {
            if let contextViewController = contextViewController, let viewController = viewController {
                (contextViewController as? UINavigationController)?.pushViewController(viewController, animated: true)
            }
        } else {
            if let viewController = viewController, let contextViewController = contextViewController {
                let navigationController = NCLoginNavigationController(rootViewController: viewController)
                navigationController.modalPresentationStyle = .fullScreen
                navigationController.navigationBar.barStyle = .black
                navigationController.navigationBar.tintColor = NCBrandColor.shared.customerText
                navigationController.navigationBar.barTintColor = NCBrandColor.shared.customer
                navigationController.navigationBar.isTranslucent = false
                contextViewController.present(navigationController, animated: true) { }
            }
        }
    }

    @objc func startTimerErrorNetworking(scene: UIScene) {
        timerErrorNetworkingDisabled = false
        timerErrorNetworking = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(checkErrorNetworking(_:)), userInfo: ["scene": scene], repeats: true)
    }

    @objc private func checkErrorNetworking(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let scene = userInfo["scene"] as? UIScene,
              let rootViewController = SceneManager.shared.getMainTabBarController(scene: scene)
        else { return }
        guard !self.timerErrorNetworkingDisabled,
              !account.isEmpty,
              NCKeychain().getPassword(account: account).isEmpty else { return }
        openLogin(viewController: rootViewController, selector: NCGlobal.shared.introLogin, openLoginWeb: true)
    }

    func trustCertificateError(host: String) {

        guard let currentHost = URL(string: self.urlBase)?.host,
              let pushNotificationServerProxyHost = URL(string: NCBrandOptions.shared.pushNotificationServerProxy)?.host,
              host != pushNotificationServerProxyHost,
              host == currentHost
        else { return }

        let certificateHostSavedPath = NCUtilityFileSystem().directoryCertificates + "/" + host + ".der"
        var title = NSLocalizedString("_ssl_certificate_changed_", comment: "")

        if !FileManager.default.fileExists(atPath: certificateHostSavedPath) {
            title = NSLocalizedString("_connect_server_anyway_", comment: "")
        }

        let alertController = UIAlertController(title: title, message: NSLocalizedString("_server_is_trusted_", comment: ""), preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { _ in
            NCNetworking.shared.writeCertificate(host: host)
        }))

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { _ in }))

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_certificate_details_", comment: ""), style: .default, handler: { _ in
            if let navigationController = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil).instantiateInitialViewController() as? UINavigationController,
               let viewController = navigationController.topViewController as? NCViewCertificateDetails {
                viewController.delegate = self
                viewController.host = host
                UIApplication.shared.firstWindow?.rootViewController?.present(navigationController, animated: true)
            }
        }))

        UIApplication.shared.firstWindow?.rootViewController?.present(alertController, animated: true)
    }

    // MARK: - Account

    @objc func changeAccount(_ account: String, userProfile: NKUserProfile?) {

        NCNetworking.shared.cancelAllQueue()
        NCNetworking.shared.cancelDataTask()
        NCNetworking.shared.cancelDownloadTasks()
        NCNetworking.shared.cancelUploadTasks()

        guard let tableAccount = NCManageDatabase.shared.setAccountActive(account) else { return }

        if account != self.account {
            DispatchQueue.global().async {
                if NCManageDatabase.shared.getAccounts()?.count == 1 {
                    NCImageCache.shared.createMediaCache(account: account, withCacheSize: true)
                } else {
                    NCImageCache.shared.createMediaCache(account: account, withCacheSize: false)
                }
            }
        }

        self.account = tableAccount.account
        self.urlBase = tableAccount.urlBase
        self.user = tableAccount.user
        self.userId = tableAccount.userId
        self.password = NCKeychain().getPassword(account: tableAccount.account)

        NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: urlBase)
        NCManageDatabase.shared.setCapabilities(account: account)

        if let userProfile {
            NCManageDatabase.shared.setAccountUserProfile(account: account, userProfile: userProfile)
        }

        NCPushNotification.shared().pushNotification()

        NCService().startRequestServicesServer()

        NCAutoUpload.shared.initAutoUpload(viewController: nil) { items in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Initialize Auto upload with \(items) uploads")
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeUser)
    }

    @objc func deleteAccount(_ account: String, wipe: Bool) {

        if let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) {
            NCPushNotification.shared().unsubscribingNextcloudServerPushNotification(account.account, urlBase: account.urlBase, user: account.user, withSubscribing: false)
        }

        NextcloudKit.shared.deleteAppPassword(serverUrl: urlBase, username: userId, password: password) { _, error in
            print(error)
        }

        let results = NCManageDatabase.shared.getTableLocalFiles(predicate: NSPredicate(format: "account == %@", account), sorted: "ocId", ascending: false)
        let utilityFileSystem = NCUtilityFileSystem()
        for result in results {
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId))
        }
        NCManageDatabase.shared.clearDatabase(account: account, removeAccount: true)

        NCKeychain().clearAllKeysEndToEnd(account: account)
        NCKeychain().clearAllKeysPushNotification(account: account)
        NCKeychain().setPassword(account: account, password: nil)

        self.account = ""
        self.urlBase = ""
        self.user = ""
        self.userId = ""
        self.password = ""

        if wipe {
            let accounts = NCManageDatabase.shared.getAccounts()
            if accounts?.count ?? 0 > 0 {
                if let newAccount = accounts?.first {
                    self.changeAccount(newAccount, userProfile: nil)
                }
            } else {
                let viewController = UIApplication.shared.firstWindow?.rootViewController
                openLogin(viewController: viewController, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }
        }
    }

    func deleteAllAccounts() {
        let accounts = NCManageDatabase.shared.getAccounts()
        accounts?.forEach({ account in
            deleteAccount(account, wipe: true)
        })
    }

    func updateShareAccounts() -> Error? {
        guard let dirGroupApps = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroupApps) else { return nil }

        let tableAccount = NCManageDatabase.shared.getAllAccount()
        var accounts = [NKShareAccounts.DataAccounts]()
        for account in tableAccount {
            let name = account.alias.isEmpty ? account.displayName : account.alias
            let userBaseUrl = account.user + "-" + (URL(string: account.urlBase)?.host ?? "")
            let avatarFileName = userBaseUrl + "-\(account.user).png"
            let pathAvatarFileName = NCUtilityFileSystem().directoryUserData + "/" + avatarFileName
            let image = UIImage(contentsOfFile: pathAvatarFileName)
            accounts.append(NKShareAccounts.DataAccounts(withUrl: account.urlBase, user: account.user, name: name, image: image))
        }
        return NKShareAccounts().putShareAccounts(at: dirGroupApps, app: NCGlobal.shared.appScheme, dataAccounts: accounts)
    }

    // MARK: - Reset Application

    @objc func resetApplication() {

        let utilityFileSystem = NCUtilityFileSystem()

        NCNetworking.shared.cancelAllTask()

        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0

        utilityFileSystem.removeGroupDirectoryProviderStorage()
        utilityFileSystem.removeGroupApplicationSupport()
        utilityFileSystem.removeDocumentsDirectory()
        utilityFileSystem.removeTemporaryDirectory()

        NCKeychain().removeAll()
        exit(0)
    }

    // MARK: - Universal Links

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        let applicationHandle = NCApplicationHandle()
        return applicationHandle.applicationOpenUserActivity(userActivity)
    }
}

// MARK: -

extension AppDelegate: NCViewCertificateDetailsDelegate {
    func viewCertificateDetailsDismiss(host: String) {
        trustCertificateError(host: host)
    }
}

extension AppDelegate: NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        guard let metadatas = metadatas, !metadatas.isEmpty else { return }
        NCNetworkingProcess.shared.createProcessUploads(metadatas: metadatas)
    }
}

extension AppDelegate: NCPasscodeDelegate {
    func requestedAccount(viewController: UIViewController?) {
        guard NCKeychain().accountRequest else {
            return
        }

        let accounts = NCManageDatabase.shared.getAllAccount()
        if accounts.count > 1 {

            if let accountRequestVC = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {

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
    }

    func passcodeReset(_ passcodeViewController: TOPasscodeViewController) {
        resetApplication()
    }

    func showPrivacyProtectionWindow(scene: UIScene) {
        let windows = SceneManager.shared.getWindow(scene: scene)
        let currentRootViewController = windows?.rootViewController
        let presentedViewController = currentRootViewController?.presentedViewController
        if presentedViewController is TOPasscodeViewController {
            return
        }
        let viewController = UIStoryboard(name: "PrivacyProtectionScreen", bundle: nil).instantiateInitialViewController()

        windows?.rootViewController = viewController
    }

    func hidePrivacyProtectionWindow(scene: UIScene) {
        let windows = SceneManager.shared.getWindow(scene: scene)
        let currentRootViewController = windows?.rootViewController
        let rootViewController = SceneManager.shared.getMainTabBarController(scene: scene)

        if currentRootViewController is PrivacyProtectionScreen {
            windows?.rootViewController = rootViewController
        }
    }
}

extension AppDelegate: NCAccountRequestDelegate {
    func accountRequestChangeAccount(account: String) {
        changeAccount(account, userProfile: nil)
    }
}
