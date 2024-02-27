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
    var window: UIWindow?

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
    var timerErrorNetworking: Timer?
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

        startTimerErrorNetworking()

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

        if let account = NCManageDatabase.shared.getActiveAccount() {
            NextcloudKit.shared.nkCommonInstance.writeLog("Account active \(account.account)")
            if NCKeychain().getPassword(account: account.account).isEmpty {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] PASSWORD NOT FOUND for \(account.account)")
            }
        }

        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {

            account = activeAccount.account
            urlBase = activeAccount.urlBase
            user = activeAccount.user
            userId = activeAccount.userId
            password = NCKeychain().getPassword(account: account)

            NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: urlBase)
            NCManageDatabase.shared.setCapabilities(account: account)

            NCBrandColor.shared.settingThemingColor(account: activeAccount.account)

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

        if account.isEmpty {
            if NCBrandOptions.shared.disable_intro {
                openLogin(viewController: nil, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            } else {
                if let viewController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() {
                    let navigationController = NCLoginNavigationController(rootViewController: viewController)
                    window?.rootViewController = navigationController
                    window?.makeKeyAndVisible()
                }
            }
        } else {
            NCPasscode.shared.presentPasscode(delegate: self) {
                NCPasscode.shared.enableTouchFaceID()
            }
        }

        return true
    }

    // MARK: - Life Cycle

    // L' applicazione entrerà in attivo (sempre)
    func applicationDidBecomeActive(_ application: UIApplication) {

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Application did become active")

        DispatchQueue.global().async { NCImageCache.shared.createMediaCache(account: self.account, withCacheSize: true) }

        NCSettingsBundleHelper.setVersionAndBuildNumber()
        NCSettingsBundleHelper.checkAndExecuteSettings(delay: 0.5)

        // START OBSERVE/TIMER UPLOAD PROCESS
        NCNetworkingProcess.shared.observeTableMetadata()
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

    // L' applicazione si dimetterà dallo stato di attivo
    func applicationWillResignActive(_ application: UIApplication) {

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Application will resign active")

        guard !account.isEmpty else { return }

        // STOP OBSERVE/TIMER UPLOAD PROCESS
        NCNetworkingProcess.shared.invalidateObserveTableMetadata()
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

    // L' applicazione entrerà in primo piano (dopo il background)
    func applicationWillEnterForeground(_ application: UIApplication) {

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Application will enter in foreground")

        guard !account.isEmpty else { return }

        NCPasscode.shared.enableTouchFaceID()

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationWillEnterForeground)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRichdocumentGrabFocus)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetwork, second: 2)
    }

    // L' applicazione è entrata nello sfondo
    func applicationDidEnterBackground(_ application: UIApplication) {

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Application did enter in background")

        guard !account.isEmpty else { return }
        let activeAccount = NCManageDatabase.shared.getActiveAccount()

        if let autoUpload = activeAccount?.autoUpload, autoUpload {
            NextcloudKit.shared.nkCommonInstance.writeLog("- Auto upload: true")
            if UIApplication.shared.backgroundRefreshStatus == .available {
                NextcloudKit.shared.nkCommonInstance.writeLog("- Auto upload in background: true")
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("- Auto upload in background: false")
            }
        } else {
            NextcloudKit.shared.nkCommonInstance.writeLog("- Auto upload: false")
        }

        if let error = updateShareAccounts() {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Create share accounts \(error.localizedDescription)")
        }

        scheduleAppRefresh()
        scheduleAppProcessing()
        NCNetworking.shared.cancelAllQueue()
        NCNetworking.shared.cancelDownloadTasks()
        NCNetworking.shared.cancelUploadTasks()
        NCPasscode.shared.presentPasscode(delegate: self) { }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationDidEnterBackground)
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

        NextcloudKit.shared.nkCommonInstance.writeLog("bye bye")
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
            NextcloudKit.shared.nkCommonInstance.writeLog("- Refresh task: ok")
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
            NextcloudKit.shared.nkCommonInstance.writeLog("- Processing task: ok")
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
        let semaphore = DispatchSemaphore(value: 0)

        NCAutoUpload.shared.initAutoUpload(viewController: nil) { items in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] \(taskText) auto upload with \(items) uploads")

            NCNetworkingProcess.shared.start { counterDownload, counterUpload in
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] \(taskText) networking process with download: \(counterDownload) upload: \(counterUpload)")

                if taskText == "ProcessingTask",
                   items == 0, counterDownload == 0, counterUpload == 0,
                   let directories = NCManageDatabase.shared.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", self.account), sorted: "offlineDate", ascending: true) {

                    for directory: tableDirectory in directories {
                        // only 3 time for day
                        if let offlineDate = directory.offlineDate, offlineDate.addingTimeInterval(28800) > Date() {
                            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] \(taskText) skip synchronization for \(directory.serverUrl) in date \(offlineDate)")
                            continue
                        }
                        NCNetworking.shared.synchronization(account: self.account, serverUrl: directory.serverUrl, add: false) { errorCode, items in
                            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] \(taskText) end synchronization for \(directory.serverUrl), errorCode: \(errorCode), item: \(items)")
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                }
                completion()
            }
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
        NCNetworking.shared.checkPushNotificationServerProxyCertificateUntrusted(viewController: self.window?.rootViewController) { error in
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
                    self.window?.rootViewController?.present(navigationController, animated: true)
                }
            } else if !findAccount {
                let message = NSLocalizedString("_the_account_", comment: "") + " " + accountPush + " " + NSLocalizedString("_does_not_exist_", comment: "")
                let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                self.window?.rootViewController?.present(alertController, animated: true, completion: { })
            }
        }
    }

    // MARK: - Login & checkErrorNetworking

    @objc func openLogin(viewController: UIViewController?, selector: Int, openLoginWeb: Bool) {

        // [WEBPersonalized] [AppConfig]
        if NCBrandOptions.shared.use_login_web_personalized || NCBrandOptions.shared.use_AppConfig {

            if activeLoginWeb?.view.window == nil {
                activeLoginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb
                activeLoginWeb?.urlBase = NCBrandOptions.shared.loginBaseUrl
                showLoginViewController(activeLoginWeb, contextViewController: viewController)
            }
            return
        }

        // Nextcloud standard login
        if selector == NCGlobal.shared.introSignup {

            if activeLoginWeb?.view.window == nil {
                activeLoginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb
                if selector == NCGlobal.shared.introSignup {
                    activeLoginWeb?.urlBase = NCBrandOptions.shared.linkloginPreferredProviders
                } else {
                    activeLoginWeb?.urlBase = self.urlBase
                }
                showLoginViewController(activeLoginWeb, contextViewController: viewController)
            }

        } else if NCBrandOptions.shared.disable_intro && NCBrandOptions.shared.disable_request_login_url {

            if activeLoginWeb?.view.window == nil {
                activeLoginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb
                activeLoginWeb?.urlBase = NCBrandOptions.shared.loginBaseUrl
                showLoginViewController(activeLoginWeb, contextViewController: viewController)
            }

        } else if openLoginWeb {

            // Used also for reinsert the account (change passwd)
            if activeLoginWeb?.view.window == nil {
                activeLoginWeb = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginWeb") as? NCLoginWeb
                activeLoginWeb?.urlBase = urlBase
                activeLoginWeb?.user = user
                showLoginViewController(activeLoginWeb, contextViewController: viewController)
            }

        } else {

            if activeLogin?.view.window == nil {
                activeLogin = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLogin") as? NCLogin
                showLoginViewController(activeLogin, contextViewController: viewController)
            }
        }
    }

    func showLoginViewController(_ viewController: UIViewController?, contextViewController: UIViewController?) {

        if contextViewController == nil {
            if let viewController = viewController {
                let navigationController = NCLoginNavigationController(rootViewController: viewController)
                navigationController.navigationBar.barStyle = .black
                navigationController.navigationBar.tintColor = NCBrandColor.shared.customerText
                navigationController.navigationBar.barTintColor = NCBrandColor.shared.customer
                navigationController.navigationBar.isTranslucent = false
                window?.rootViewController = navigationController
                window?.makeKeyAndVisible()
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

    @objc func startTimerErrorNetworking() {
        timerErrorNetworking = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(checkErrorNetworking), userInfo: nil, repeats: true)
    }

    @objc private func checkErrorNetworking() {
        guard !account.isEmpty, NCKeychain().getPassword(account: account).isEmpty else { return }
        openLogin(viewController: window?.rootViewController, selector: NCGlobal.shared.introLogin, openLoginWeb: true)
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
                self.window?.rootViewController?.present(navigationController, animated: true)
            }
        }))

        window?.rootViewController?.present(alertController, animated: true)
    }

    // MARK: - Account

    @objc func changeAccount(_ account: String, userProfile: NKUserProfile?) {

        NCNetworking.shared.cancelAllQueue()
        NCNetworking.shared.cancelDataTask()
        NCNetworking.shared.cancelDownloadTasks()
        NCNetworking.shared.cancelUploadTasks()

        guard let tableAccount = NCManageDatabase.shared.setAccountActive(account) else { return }

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

        DispatchQueue.global().async {
            if NCManageDatabase.shared.getAccounts()?.count == 1 {
                NCImageCache.shared.createMediaCache(account: self.account, withCacheSize: true)
            } else {
                NCImageCache.shared.createMediaCache(account: self.account, withCacheSize: false)
            }
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeUser)
        }
    }

    @objc func deleteAccount(_ account: String, wipe: Bool) {

        if let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) {
            NCPushNotification.shared().unsubscribingNextcloudServerPushNotification(account.account, urlBase: account.urlBase, user: account.user, withSubscribing: false)
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
                openLogin(viewController: window?.rootViewController, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
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

    // MARK: - Scheme URL

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

        let scheme = url.scheme
        let action = url.host
        var fileName: String = ""
        var serverUrl: String = ""

        /*
         Example: nextcloud://open-action?action=create-voice-memo&&user=marinofaggiana&url=https://cloud.nextcloud.com
         */

        if !account.isEmpty && scheme == NCGlobal.shared.appScheme && action == "open-action" {

            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {

                let queryItems = urlComponents.queryItems
                guard let actionScheme = queryItems?.filter({ $0.name == "action" }).first?.value,
                      let userScheme = queryItems?.filter({ $0.name == "user" }).first?.value,
                      let urlScheme = queryItems?.filter({ $0.name == "url" }).first?.value,
                      let rootViewController = window?.rootViewController else { return false }
                if getMatchedAccount(userId: userScheme, url: urlScheme) == nil {
                    let message = NSLocalizedString("_the_account_", comment: "") + " " + userScheme + NSLocalizedString("_of_", comment: "") + " " + urlScheme + " " + NSLocalizedString("_does_not_exist_", comment: "")
                    let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

                    window?.rootViewController?.present(alertController, animated: true, completion: { })
                    return false
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
                          let viewController = (navigationController as? UINavigationController)?.topViewController as? NCCreateFormUploadDocuments else { return false }

                    navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                    viewController.editorId = NCGlobal.shared.editorText
                    viewController.creatorId = directEditingCreator.identifier
                    viewController.typeTemplate = NCGlobal.shared.templateDocument
                    viewController.serverUrl = activeServerUrl
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
            return true
        }

        /*
         Example: nextcloud://open-file?path=Talk/IMG_0000123.jpg&user=marinofaggiana&link=https://cloud.nextcloud.com/f/123
         */

        else if !account.isEmpty && scheme == NCGlobal.shared.appScheme && action == "open-file" {

            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {

                let queryItems = urlComponents.queryItems
                guard let userScheme = queryItems?.filter({ $0.name == "user" }).first?.value,
                      let pathScheme = queryItems?.filter({ $0.name == "path" }).first?.value,
                      let linkScheme = queryItems?.filter({ $0.name == "link" }).first?.value else { return false}

                guard let matchedAccount = getMatchedAccount(userId: userScheme, url: linkScheme) else {
                    guard let domain = URL(string: linkScheme)?.host else { return true }
                    fileName = (pathScheme as NSString).lastPathComponent
                    let message = String(format: NSLocalizedString("_account_not_available_", comment: ""), userScheme, domain, fileName)
                    let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

                    window?.rootViewController?.present(alertController, animated: true, completion: { })
                    return false
                }

                let davFiles = NextcloudKit.shared.nkCommonInstance.dav + "/files/" + self.userId
                if pathScheme.contains("/") {
                    fileName = (pathScheme as NSString).lastPathComponent
                    serverUrl = matchedAccount.urlBase + "/" + davFiles + "/" + (pathScheme as NSString).deletingLastPathComponent
                } else {
                    fileName = pathScheme
                    serverUrl = matchedAccount.urlBase + "/" + davFiles
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NCActionCenter.shared.openFileViewInFolder(serverUrl: serverUrl, fileNameBlink: nil, fileNameOpen: fileName)
                }
            }
            return true

        /*
         Example: nextcloud://open-and-switch-account?user=marinofaggiana&url=https://cloud.nextcloud.com
         */

        } else if !account.isEmpty && scheme == NCGlobal.shared.appScheme && action == "open-and-switch-account" {
            guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
            let queryItems = urlComponents.queryItems
            guard let userScheme = queryItems?.filter({ $0.name == "user" }).first?.value,
                  let urlScheme = queryItems?.filter({ $0.name == "url" }).first?.value else { return false}
            // If the account doesn't exist, return false which will open the app without switching
            if getMatchedAccount(userId: userScheme, url: urlScheme) == nil {
                return false
            }
            // Otherwise open the app and switch accounts
            return true
        } else {
            let applicationHandle = NCApplicationHandle()
            let isHandled = applicationHandle.applicationOpenURL(url)
            if isHandled {
                return true
            } else {
                app.open(url)
                return true
            }
        }
    }

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
                        changeAccount(account.account, userProfile: nil)
                        return account
                    }
                }
            }
        }
        return nil
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
    func requestedAccount() {
        guard !NCPasscode.shared.isPasscodePresented, NCKeychain().accountRequest else {
            return
        }

        let accounts = NCManageDatabase.shared.getAllAccount()
        if accounts.count > 1 {

            if let viewController = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {

                viewController.activeAccount = NCManageDatabase.shared.getActiveAccount()
                viewController.accounts = accounts
                viewController.enableTimerProgress = true
                viewController.enableAddAccount = false
                viewController.dismissDidEnterBackground = false
                viewController.delegate = self

                let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
                let numberCell = accounts.count
                let height = min(CGFloat(numberCell * Int(viewController.heightCell) + 45), screenHeighMax)

                let popup = NCPopupViewController(contentController: viewController, popupWidth: 300, popupHeight: height + 20)
                popup.backgroundAlpha = 0.8

                window?.rootViewController?.present(popup, animated: true)
                viewController.startTimer()
            }
        }
    }

    func passcodeReset(_ passcodeViewController: TOPasscodeViewController) {
        resetApplication()
    }
}

extension AppDelegate: NCAccountRequestDelegate {
    func accountRequestChangeAccount(account: String) {
        changeAccount(account, userProfile: nil)
    }
}
