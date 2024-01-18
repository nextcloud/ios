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
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, TOPasscodeViewControllerDelegate, NCAccountRequestDelegate, NCViewCertificateDetailsDelegate, NCUserBaseUrl {

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
    private var privacyProtectionWindow: UIWindow?
    var isAppRefresh: Bool = false
    var isAppProcessing: Bool = false

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

        // Intro
        if NCBrandOptions.shared.disable_intro {
            if account.isEmpty {
                openLogin(viewController: nil, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }
        } else {
            if !NCKeychain().intro {
                if let viewController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() {
                    let navigationController = NCLoginNavigationController(rootViewController: viewController)
                    window?.rootViewController = navigationController
                    window?.makeKeyAndVisible()
                }
            }
        }

        self.presentPasscode {
            self.enableTouchFaceID()
        }

        return true
    }

    // MARK: - Life Cycle

    // L' applicazione entrerà in attivo (sempre)
    func applicationDidBecomeActive(_ application: UIApplication) {

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Application did become active")

        DispatchQueue.global().async { NCImageCache.shared.createMediaCache(account: self.account) }

        NCSettingsBundleHelper.setVersionAndBuildNumber()
        NCSettingsBundleHelper.checkAndExecuteSettings(delay: 0.5)

        // START OBSERVE/TIMER UPLOAD PROCESS
        NCNetworkingProcessUpload.shared.observeTableMetadata()
        NCNetworkingProcessUpload.shared.startTimer()

        if !NCAskAuthorization().isRequesting {
            hidePrivacyProtectionWindow()
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
        NCNetworkingProcessUpload.shared.invalidateObserveTableMetadata()
        NCNetworkingProcessUpload.shared.stopTimer()

        if NCKeychain().privacyScreenEnabled {
            showPrivacyProtectionWindow()
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

        enableTouchFaceID()

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
        NCNetworking.shared.cancelDataTask()
        NCNetworking.shared.cancelDownloadTasks()
        presentPasscode { }

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

        if isAppProcessing {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Processing task already in progress, abort.")
            task.setTaskCompleted(success: true)
            return
        }
        isAppRefresh = true

        NCAutoUpload.shared.initAutoUpload(viewController: nil) { items in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Refresh task auto upload with \(items) uploads")
            NCNetworkingProcessUpload.shared.start { items in
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Refresh task upload process with \(items) uploads")
                task.setTaskCompleted(success: true)
                self.isAppRefresh = false
            }
        }
    }

    func handleProcessingTask(_ task: BGTask) {
        scheduleAppProcessing()

        if isAppRefresh {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Refresh task already in progress, abort.")
            task.setTaskCompleted(success: true)
            return
        }
        isAppProcessing = true

        NCAutoUpload.shared.initAutoUpload(viewController: nil) { items in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Processing task auto upload with \(items) uploads")
            NCNetworkingProcessUpload.shared.start { items in
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Processing task upload process with \(items) uploads")
                task.setTaskCompleted(success: true)
                self.isAppProcessing = false
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

    func viewCertificateDetailsDismiss(host: String) {
        trustCertificateError(host: host)
    }

    // MARK: - Account

    @objc func changeAccount(_ account: String, userProfile: NKUserProfile?) {

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
            NCImageCache.shared.createMediaCache(account: self.account)
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

    // MARK: - Account Request

    func accountRequestChangeAccount(account: String) {
        changeAccount(account, userProfile: nil)
    }

    func requestAccount() {

        if isPasscodePresented { return }
        if !NCKeychain().accountRequest { return }

        let accounts = NCManageDatabase.shared.getAllAccount()

        if accounts.count > 1 {

            if let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {

                vcAccountRequest.activeAccount = NCManageDatabase.shared.getActiveAccount()
                vcAccountRequest.accounts = accounts
                vcAccountRequest.enableTimerProgress = true
                vcAccountRequest.enableAddAccount = false
                vcAccountRequest.dismissDidEnterBackground = false
                vcAccountRequest.delegate = self

                let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
                let numberCell = accounts.count
                let height = min(CGFloat(numberCell * Int(vcAccountRequest.heightCell) + 45), screenHeighMax)

                let popup = NCPopupViewController(contentController: vcAccountRequest, popupWidth: 300, popupHeight: height + 20)
                popup.backgroundAlpha = 0.8

                window?.rootViewController?.present(popup, animated: true)

                vcAccountRequest.startTimer()
            }
        }
    }

    // MARK: - Passcode

    var isPasscodeReset: Bool {
        let passcodeCounterFailReset = NCKeychain().passcodeCounterFailReset
        return NCKeychain().resetAppCounterFail && passcodeCounterFailReset >= NCBrandOptions.shared.resetAppPasscodeAttempts
    }

    var isPasscodeFail: Bool {
        let passcodeCounterFail = NCKeychain().passcodeCounterFail
        return passcodeCounterFail > 0 && passcodeCounterFail.isMultiple(of: 3)
    }

    var isPasscodePresented: Bool {
        return privacyProtectionWindow?.rootViewController?.presentedViewController is TOPasscodeViewController
    }

    func presentPasscode(completion: @escaping () -> Void) {

        var error: NSError?
        defer { self.requestAccount() }

        let presentedViewController = window?.rootViewController?.presentedViewController
        guard !account.isEmpty, NCKeychain().passcode != nil, NCKeychain().requestPasscodeAtStart, !(presentedViewController is NCLoginNavigationController) else { return }

        // Make sure we have a privacy window (in case it's not enabled)
        showPrivacyProtectionWindow()

        let passcodeViewController = TOPasscodeViewController(passcodeType: .sixDigits, allowCancel: false)
        passcodeViewController.delegate = self
        passcodeViewController.keypadButtonShowLettering = false
        if NCKeychain().touchFaceID, LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if error == nil {
                if LAContext().biometryType == .faceID {
                    passcodeViewController.biometryType = .faceID
                } else if LAContext().biometryType == .touchID {
                    passcodeViewController.biometryType = .touchID
                }
                passcodeViewController.allowBiometricValidation = true
                passcodeViewController.automaticallyPromptForBiometricValidation = false
            }
        }

        // show passcode on top of privacy window
        privacyProtectionWindow?.rootViewController?.present(passcodeViewController, animated: true, completion: {
            self.openAlert(passcodeViewController: passcodeViewController)
            completion()
        })
    }

    func enableTouchFaceID() {
        guard !account.isEmpty,
              NCKeychain().touchFaceID,
              NCKeychain().passcode != nil,
              NCKeychain().requestPasscodeAtStart,
              !isPasscodeFail,
              !isPasscodeReset,
              let passcodeViewController = privacyProtectionWindow?.rootViewController?.presentedViewController as? TOPasscodeViewController
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {

            LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { success, evaluateError in
                if success {
                    DispatchQueue.main.async {
                        passcodeViewController.dismiss(animated: true) {
                            NCKeychain().passcodeCounterFail = 0
                            NCKeychain().passcodeCounterFailReset = 0
                            self.hidePrivacyProtectionWindow()
                            self.requestAccount()
                        }
                    }
                } else {
                    if let error = evaluateError {
                        switch error._code {
                        case LAError.userFallback.rawValue, LAError.authenticationFailed.rawValue:
                            if LAContext().biometryType == .faceID {
                                NCKeychain().passcodeCounterFail = 2
                                NCKeychain().passcodeCounterFailReset += 2
                            } else {
                                NCKeychain().passcodeCounterFail = 3
                                NCKeychain().passcodeCounterFailReset += 3
                            }
                            self.openAlert(passcodeViewController: passcodeViewController)
                        case LAError.biometryLockout.rawValue:
                            LAContext().evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: NSLocalizedString("_deviceOwnerAuthentication_", comment: ""), reply: { success, _ in
                                if success {
                                    DispatchQueue.main.async {
                                        NCKeychain().passcodeCounterFail = 0
                                        self.enableTouchFaceID()
                                    }
                                }
                            })
                        case LAError.userCancel.rawValue:
                            NCKeychain().passcodeCounterFail += 1
                            NCKeychain().passcodeCounterFailReset += 1
                        default:
                            break
                        }
                    }
                }
            }
        }
    }

    func didInputCorrectPasscode(in passcodeViewController: TOPasscodeViewController) {
        DispatchQueue.main.async {
            passcodeViewController.dismiss(animated: true) {
                NCKeychain().passcodeCounterFail = 0
                NCKeychain().passcodeCounterFailReset = 0
                self.hidePrivacyProtectionWindow()
                self.requestAccount()
            }
        }
    }

    func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {
        if code == NCKeychain().passcode {
            return true
        } else {
            NCKeychain().passcodeCounterFail += 1
            NCKeychain().passcodeCounterFailReset += 1
            openAlert(passcodeViewController: passcodeViewController)
            return false
        }
    }

    func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {
        enableTouchFaceID()
    }

    func openAlert(passcodeViewController: TOPasscodeViewController) {

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {

            if self.isPasscodeReset {

                passcodeViewController.setContentHidden(true, animated: true)

                let alertController = UIAlertController(title: NSLocalizedString("_reset_wrong_passcode_", comment: ""), message: nil, preferredStyle: .alert)
                passcodeViewController.present(alertController, animated: true, completion: { })

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.resetApplication()
                }

            } else if self.isPasscodeFail {

                passcodeViewController.setContentHidden(true, animated: true)

                let alertController = UIAlertController(title: NSLocalizedString("_passcode_counter_fail_", comment: ""), message: nil, preferredStyle: .alert)
                passcodeViewController.present(alertController, animated: true, completion: { })

                var seconds = NCBrandOptions.shared.passcodeSecondsFail
                _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    alertController.message = "\(seconds) " + NSLocalizedString("_seconds_", comment: "")
                    seconds -= 1
                    if seconds < 0 {
                        timer.invalidate()
                        alertController.dismiss(animated: true)
                        passcodeViewController.setContentHidden(false, animated: true)
                        NCKeychain().passcodeCounterFail = 0
                        self.enableTouchFaceID()
                    }
                }
            }
        }
    }

    // MARK: - Reset Application

    @objc func resetApplication() {

        let utilityFileSystem = NCUtilityFileSystem()

        NCNetworking.shared.cancelDataTask()
        NCNetworking.shared.cancelDownloadTasks()
        NCNetworking.shared.cancelUploadTasks()
        NCNetworking.shared.cancelUploadBackgroundTask()

        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0

        utilityFileSystem.removeGroupDirectoryProviderStorage()
        utilityFileSystem.removeGroupApplicationSupport()
        utilityFileSystem.removeDocumentsDirectory()
        utilityFileSystem.removeTemporaryDirectory()

        NCKeychain().removeAll()
        exit(0)
    }

    // MARK: - Privacy Protection

    private func showPrivacyProtectionWindow() {
        guard privacyProtectionWindow == nil else {
            privacyProtectionWindow?.isHidden = false
            return
        }

        privacyProtectionWindow = UIWindow(frame: UIScreen.main.bounds)

        let storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
        let initialViewController = storyboard.instantiateInitialViewController()

        self.privacyProtectionWindow?.rootViewController = initialViewController

        privacyProtectionWindow?.windowLevel = .alert + 1
        privacyProtectionWindow?.makeKeyAndVisible()
    }

    func hidePrivacyProtectionWindow() {
        guard !(privacyProtectionWindow?.rootViewController?.presentedViewController is TOPasscodeViewController) else { return }
        UIWindow.animate(withDuration: 0.25) {
            self.privacyProtectionWindow?.alpha = 0
        } completion: { _ in
            self.privacyProtectionWindow?.isHidden = true
            self.privacyProtectionWindow = nil
        }
    }

    // MARK: - Queue

    @objc func cancelAllQueue() {
        NCNetworking.shared.downloadQueue.cancelAll()
        NCNetworking.shared.downloadThumbnailQueue.cancelAll()
        NCNetworking.shared.downloadThumbnailActivityQueue.cancelAll()
        NCNetworking.shared.downloadAvatarQueue.cancelAll()
        NCNetworking.shared.unifiedSearchQueue.cancelAll()
        NCNetworking.shared.saveLivePhotoQueue.cancelAll()
        NCNetworking.shared.convertLivePhotoQueue.cancelAll()
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
                            let fileName = NCUtilityFileSystem().createFileNameDate(NSLocalizedString("_voice_memo_filename_", comment: ""), ext: "m4a")
                            if let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as? NCAudioRecorderViewController {

                                viewController.delegate = self
                                viewController.createRecorder(fileName: fileName)
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

// MARK: - NCAudioRecorder ViewController Delegate

extension AppDelegate: NCAudioRecorderViewControllerDelegate {

    func didFinishRecording(_ viewController: NCAudioRecorderViewController, fileName: String) {

        guard let navigationController = UIStoryboard(name: "NCCreateFormUploadVoiceNote", bundle: nil).instantiateInitialViewController() as? UINavigationController,
              let viewController = navigationController.topViewController as? NCCreateFormUploadVoiceNote else { return }
        navigationController.modalPresentationStyle = .formSheet
        viewController.setup(serverUrl: activeServerUrl, fileNamePath: NSTemporaryDirectory() + fileName, fileName: fileName)
        window?.rootViewController?.present(navigationController, animated: true)
    }

    func didFinishWithoutRecording(_ viewController: NCAudioRecorderViewController, fileName: String) { }
}

extension AppDelegate: NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        guard let metadatas = metadatas, !metadatas.isEmpty else { return }
        NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: metadatas) { _ in }
    }
}
