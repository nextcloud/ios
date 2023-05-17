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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, TOPasscodeViewControllerDelegate, NCAccountRequestDelegate, NCViewCertificateDetailsDelegate, NCUserBaseUrl {

    var backgroundSessionCompletionHandler: (() -> Void)?
    var window: UIWindow?

    @objc var account: String = ""
    @objc var urlBase: String = ""
    @objc var user: String = ""
    @objc var userId: String = ""
    @objc var password: String = ""

    var deletePasswordSession: Bool = false
    var activeLogin: NCLogin?
    var activeLoginWeb: NCLoginWeb?
    var activeServerUrl: String = ""
    @objc var activeViewController: UIViewController?
    var mainTabBar: NCMainTabBar?
    var activeMetadata: tableMetadata?

    let listFilesVC = ThreadSafeDictionary<String,NCFiles>()
    let listFavoriteVC = ThreadSafeDictionary<String,NCFavorite>()
    let listOfflineVC = ThreadSafeDictionary<String,NCOffline>()
    let listGroupfoldersVC = ThreadSafeDictionary<String,NCGroupfolders>()

    var disableSharesView: Bool = false
    var documentPickerViewController: NCDocumentPickerViewController?
    var timerErrorNetworking: Timer?

    private var privacyProtectionWindow: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        NCSettingsBundleHelper.checkAndExecuteSettings(delay: 0)

        let userAgent = CCUtility.getUserAgent() as String
        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, NCUtility.shared.getVersionApp())

        // Register initialize
        NotificationCenter.default.addObserver(self, selector: #selector(initialize), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)

        UserDefaults.standard.register(defaults: ["UserAgent": userAgent])
        if !CCUtility.getDisableCrashservice() && !NCBrandOptions.shared.disable_crash_service {
            FirebaseApp.configure()
        }

        CCUtility.createDirectoryStandard()
        CCUtility.emptyTemporaryDirectory()

        NextcloudKit.shared.setup(delegate: NCNetworking.shared)
        NextcloudKit.shared.setup(userAgent: userAgent)

        startTimerErrorNetworking()

        // LOG
        var levelLog = 0
        if let pathDirectoryGroup = CCUtility.getDirectoryGroup()?.path {
            NextcloudKit.shared.nkCommonInstance.pathLog = pathDirectoryGroup
        }

        if NCBrandOptions.shared.disable_log {

            NCUtilityFileSystem.shared.deleteFile(filePath: NextcloudKit.shared.nkCommonInstance.filenamePathLog)
            NCUtilityFileSystem.shared.deleteFile(filePath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/" + NextcloudKit.shared.nkCommonInstance.filenameLog)

        } else {

            levelLog = CCUtility.getLogLevel()
            NextcloudKit.shared.nkCommonInstance.levelLog = levelLog
            NextcloudKit.shared.nkCommonInstance.copyLogToDocumentDirectory = true
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start session with level \(levelLog) " + versionNextcloudiOS + " in state \(UIApplication.shared.applicationState.rawValue) where (0 active, 1 inactive, 2 background).")
        }

        // LOG Account
        if let account = NCManageDatabase.shared.getActiveAccount() {
            NextcloudKit.shared.nkCommonInstance.writeLog("Account active \(account.account)")
            if CCUtility.getPassword(account.account).isEmpty {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] PASSWORD NOT FOUND for \(account.account)")
            }
        }

        // Activate user account
        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {

            settingAccount(activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId, password: CCUtility.getPassword(activeAccount.account))
            NCBrandColor.shared.settingThemingColor(account: activeAccount.account)

        } else {

            CCUtility.deleteAllChainStore()
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            NCBrandColor.shared.createImagesThemingColor()
        }

        // Create user color
        NCBrandColor.shared.createUserColors()

        // Push Notification & display notification
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

        // Store review
        if !NCUtility.shared.isSimulatorOrTestFlight() {
            let review = NCStoreReview()
            review.incrementAppRuns()
            review.showStoreReview()
        }

        // Background task: register
        BGTaskScheduler.shared.register(forTaskWithIdentifier: NCGlobal.shared.refreshTask, using: nil) { task in
            self.handleRefreshTask(task)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: NCGlobal.shared.processingTask, using: nil) { task in
            self.handleProcessingTask(task)
        }

        // Intro
        if NCBrandOptions.shared.disable_intro {
            CCUtility.setIntro(true)
            if account.isEmpty {
                openLogin(viewController: nil, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }
        } else {
            if !CCUtility.getIntro() {
                if let viewController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() {
                    let navigationController = NCLoginNavigationController.init(rootViewController: viewController)
                    window?.rootViewController = navigationController
                    window?.makeKeyAndVisible()
                }
            }
        }

        // Passcode
        self.presentPasscode {
            self.enableTouchFaceID()
        }

        return true
    }

    // MARK: - Life Cycle

    // L' applicazione entrerà in attivo (sempre)
    func applicationDidBecomeActive(_ application: UIApplication) {

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Application did become active")

        NCSettingsBundleHelper.setVersionAndBuildNumber()
        NCSettingsBundleHelper.checkAndExecuteSettings(delay: 0.5)
        
        // START OBSERVE/TIMER UPLOAD PROCESS
        NCNetworkingProcessUpload.shared.observeTableMetadata()
        NCNetworkingProcessUpload.shared.startTimer()

        self.deletePasswordSession = false

        if !NCAskAuthorization.shared.isRequesting {
            hidePrivacyProtectionWindow()
        }

        if !account.isEmpty {
            NCNetworkingProcessUpload.shared.verifyUploadZombie()
        }

        // Start Auto Upload
        NCAutoUpload.shared.initAutoUpload(viewController: nil) { items in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Initialize Auto upload with \(items) uploads")
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationDidBecomeActive)
    }

    // L' applicazione entrerà in primo piano (dopo il background)
    func applicationWillEnterForeground(_ application: UIApplication) {
        guard !account.isEmpty, let activeAccount = NCManageDatabase.shared.getActiveAccount() else { return }

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Application will enter in foreground")

        if activeAccount.account != account {
            settingAccount(activeAccount.account, urlBase: activeAccount.urlBase, user: activeAccount.user, userId: activeAccount.userId, password: CCUtility.getPassword(activeAccount.account))
        } else {
            // Request Service Server Nextcloud
            NCService.shared.startRequestServicesServer()
        }

        // Required unsubscribing / subscribing
        NCPushNotification.shared().pushNotification()

        // Request TouchID, FaceID
        enableTouchFaceID()
        
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationWillEnterForeground)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRichdocumentGrabFocus)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetwork)
    }

    // L' applicazione si dimetterà dallo stato di attivo
    func applicationWillResignActive(_ application: UIApplication) {
        // Nextcloud update share accounts
        if let error = updateShareAccounts() {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Create share accounts \(error.localizedDescription)")
        }
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Application will resign active")
        guard !account.isEmpty else { return }

        // STOP OBSERVE/TIMER UPLOAD PROCESS
        NCNetworkingProcessUpload.shared.invalidateObserveTableMetadata()
        NCNetworkingProcessUpload.shared.stopTimer()

        if CCUtility.getPrivacyScreenEnabled() {
            // Privacy
            showPrivacyProtectionWindow()
        }

        // Reload Widget
        WidgetCenter.shared.reloadAllTimelines()

        // Clear operation queue
        NCOperationQueue.shared.cancelAllQueue()
        // Clear download
        NCNetworking.shared.cancelAllDownloadTransfer()

        // Clear older files
        let days = CCUtility.getCleanUpDay()
        if let directory = CCUtility.getDirectoryProviderStorage() {
            NCUtilityFileSystem.shared.cleanUp(directory: directory, days: TimeInterval(days))
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationWillResignActive)
    }

    // L' applicazione è entrata nello sfondo
    func applicationDidEnterBackground(_ application: UIApplication) {
        guard !account.isEmpty else { return }

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Application did enter in background")

        scheduleAppRefresh()
        scheduleAppProcessing()

        // Passcode
        presentPasscode { }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterApplicationDidEnterBackground)
    }

    // L'applicazione terminerà
    func applicationWillTerminate(_ application: UIApplication) {

        NCNetworking.shared.cancelAllDownloadTransfer()

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

    // MARK: -

    @objc private func initialize() {
        guard !account.isEmpty else { return }

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] initialize Main")

        // Registeration push notification
        NCPushNotification.shared().pushNotification()

        // Unlock E2EE
        NCNetworkingE2EE.shared.unlockAll(account: account)

        // Start services
        NCService.shared.startRequestServicesServer()

        // close detail
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMenuDetailClose)

        // Reload Widget
        WidgetCenter.shared.reloadAllTimelines()

        // Registeration domain File Provider
        // FileProviderDomain *fileProviderDomain = [FileProviderDomain new];
        // [fileProviderDomain removeAllDomains];
        // [fileProviderDomain registerDomains];
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
            NextcloudKit.shared.nkCommonInstance.writeLog("[SUCCESS] Refresh task success submit request 60 seconds \(request)")
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
            NextcloudKit.shared.nkCommonInstance.writeLog("[SUCCESS] Background Processing task success submit request 5 minutes \(request)")
        } catch {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Background Processing task failed to submit request: \(error)")
        }
    }

    func handleRefreshTask(_ task: BGTask) {
        scheduleAppRefresh()
        
        guard !account.isEmpty else {
            task.setTaskCompleted(success: true)
            return
        }

        NextcloudKit.shared.setup(delegate: NCNetworking.shared)

        NCAutoUpload.shared.initAutoUpload(viewController: nil) { items in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Refresh task auto upload with \(items) uploads")
            NCNetworkingProcessUpload.shared.start { items in
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Refresh task upload process with \(items) uploads")
                task.setTaskCompleted(success: true)
            }
        }
    }

    func handleProcessingTask(_ task: BGTask) {
        scheduleAppProcessing()
        
        guard !account.isEmpty else {
            task.setTaskCompleted(success: true)
            return
        }

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Processing task")
        task.setTaskCompleted(success: true)
    }

    // MARK: - Background Networking Session

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start handle Events For Background URLSession: \(identifier)")
        // Reload Widget
        WidgetCenter.shared.reloadAllTimelines()
        backgroundSessionCompletionHandler = completionHandler
    }

    // MARK: - Push Notifications

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
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
                let navigationController = NCLoginNavigationController.init(rootViewController: viewController)
                navigationController.navigationBar.barStyle = .black
                navigationController.navigationBar.tintColor = NCBrandColor.shared.customerText
                navigationController.navigationBar.barTintColor = NCBrandColor.shared.customer
                navigationController.navigationBar.isTranslucent = false
                window?.rootViewController = navigationController
                window?.makeKeyAndVisible()
            }
        } else if contextViewController is UINavigationController {
            if let contextViewController = contextViewController, let viewController = viewController {
                (contextViewController as! UINavigationController).pushViewController(viewController, animated: true)
            }
        } else {
            if let viewController = viewController, let contextViewController = contextViewController {
                let navigationController = NCLoginNavigationController.init(rootViewController: viewController)
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
        
        // check unauthorized server (401/403)
        if account != "" && CCUtility.getPassword(account)!.count == 0 {
            openLogin(viewController: window?.rootViewController, selector: NCGlobal.shared.introLogin, openLoginWeb: true)
        }
    }
    
    func trustCertificateError(host: String) {

        guard let currentHost = URL(string: self.urlBase)?.host,
              let pushNotificationServerProxyHost = URL(string: NCBrandOptions.shared.pushNotificationServerProxy)?.host,
              host != pushNotificationServerProxyHost,
              host == currentHost
        else { return }

        let certificateHostSavedPath = CCUtility.getDirectoryCerificates()! + "/" + host + ".der"
        var title = NSLocalizedString("_ssl_certificate_changed_", comment: "")

        if !FileManager.default.fileExists(atPath: certificateHostSavedPath) {
            title = NSLocalizedString("_connect_server_anyway_", comment: "")
        }

        let alertController = UIAlertController(title: title, message: NSLocalizedString("_server_is_trusted_", comment: ""), preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { action in
            NCNetworking.shared.writeCertificate(host: host)
        }))

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { action in }))

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_certificate_details_", comment: ""), style: .default, handler: { action in
            if let navigationController = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil).instantiateInitialViewController() as? UINavigationController {
                let viewController = navigationController.topViewController as! NCViewCertificateDetails
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

    @objc func settingAccount(_ account: String, urlBase: String, user: String, userId: String, password: String) {

        let accountTestBackup = self.account + "/" + self.userId
        let accountTest = account +  "/" + userId

        self.account = account
        self.urlBase = urlBase
        self.user = user
        self.userId = userId
        self.password = password

        _ = NCActionCenter.shared

        NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: urlBase)
        let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        if serverVersionMajor > 0 {
            NextcloudKit.shared.setup(nextcloudVersion: serverVersionMajor)
        }

        DispatchQueue.main.async {
            if UIApplication.shared.applicationState != .background && accountTestBackup != accountTest {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitialize, second: 0.2)
            }
        }
    }

    @objc func deleteAccount(_ account: String, wipe: Bool) {

        if let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) {
            NCPushNotification.shared().unsubscribingNextcloudServerPushNotification(account.account, urlBase: account.urlBase, user: account.user, withSubscribing: false)
        }
        
        let results = NCManageDatabase.shared.getTableLocalFiles(predicate: NSPredicate(format: "account == %@", account), sorted: "ocId", ascending: false)
        for result in results {
            CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(result.ocId))
        }
        NCManageDatabase.shared.clearDatabase(account: account, removeAccount: true)
        
        CCUtility.clearAllKeysEnd(toEnd: account)
        CCUtility.clearAllKeysPushNotification(account)
        CCUtility.setPassword(account, password: nil)

        if wipe {
            settingAccount("", urlBase: "", user: "", userId: "", password: "")
            let accounts = NCManageDatabase.shared.getAccounts()
            if accounts?.count ?? 0 > 0 {
                if let newAccount = accounts?.first {
                    self.changeAccount(newAccount)
                }
            } else {
                openLogin(viewController: window?.rootViewController, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }
        }
    }

    @objc func changeAccount(_ account: String) {

        NCManageDatabase.shared.setAccountActive(account)
        if let tableAccount = NCManageDatabase.shared.getActiveAccount() {

            NCOperationQueue.shared.cancelAllQueue()
            NCNetworking.shared.cancelAllTask()

            settingAccount(tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, userId: tableAccount.userId, password: CCUtility.getPassword(tableAccount.account))
        }
    }

    func updateShareAccounts() -> Error? {
        guard let dirGroupApps = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroupApps) else { return nil }

        let tableAccount = NCManageDatabase.shared.getAllAccount()
        var accounts = [NKShareAccounts.DataAccounts]()
        for account in tableAccount {
            let name = account.alias.isEmpty ? account.displayName : account.alias
            let userBaseUrl = account.user + "-" + (URL(string: account.urlBase)?.host ?? "")
            let avatarFileName = userBaseUrl + "-\(account.user).png"
            let pathAvatarFileName = String(CCUtility.getDirectoryUserData()) + "/" + avatarFileName
            let image = UIImage(contentsOfFile: pathAvatarFileName)
            accounts.append(NKShareAccounts.DataAccounts(withUrl: account.urlBase, user: account.user, name: name, image: image))
        }
        return NKShareAccounts().putShareAccounts(at: dirGroupApps, app: NCGlobal.shared.appScheme, dataAccounts: accounts)
    }

    // MARK: - Account Request

    func accountRequestChangeAccount(account: String) {
        changeAccount(account)
    }
    
    func requestAccount() {

        if isPasscodePresented() { return }
        if !CCUtility.getAccountRequest() { return }

        let accounts = NCManageDatabase.shared.getAllAccount()

        if accounts.count > 1 {
            
            if let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest {

                vcAccountRequest.activeAccount = NCManageDatabase.shared.getActiveAccount()
                vcAccountRequest.accounts = accounts
                vcAccountRequest.enableTimerProgress = true
                vcAccountRequest.enableAddAccount = false
                vcAccountRequest.dismissDidEnterBackground = false
                vcAccountRequest.delegate = self

                let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height/5)
                let numberCell = accounts.count
                let height = min(CGFloat(numberCell * Int(vcAccountRequest.heightCell) + 45), screenHeighMax)

                let popup = NCPopupViewController(contentController: vcAccountRequest, popupWidth: 300, popupHeight: height+20)
                popup.backgroundAlpha = 0.8

                window?.rootViewController?.present(popup, animated: true)
                
                vcAccountRequest.startTimer()
            }
        }
    }

    // MARK: - Passcode

    func presentPasscode(completion: @escaping () -> ()) {

        let laContext = LAContext()
        var error: NSError?

        defer { self.requestAccount() }

        let presentedViewController = window?.rootViewController?.presentedViewController
        guard !account.isEmpty, CCUtility.isPasscodeAtStartEnabled(), !(presentedViewController is NCLoginNavigationController) else { return }

        // Make sure we have a privacy window (in case it's not enabled)
        showPrivacyProtectionWindow()

        let passcodeViewController = TOPasscodeViewController(passcodeType: .sixDigits, allowCancel: false)
        passcodeViewController.delegate = self
        passcodeViewController.keypadButtonShowLettering = false
        if CCUtility.getEnableTouchFaceID() && laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if error == nil {
                if laContext.biometryType == .faceID  {
                    passcodeViewController.biometryType = .faceID
                } else if laContext.biometryType == .touchID  {
                    passcodeViewController.biometryType = .touchID
                }
                passcodeViewController.allowBiometricValidation = true
                passcodeViewController.automaticallyPromptForBiometricValidation = false
            }
        }

        // show passcode on top of privacy window
        privacyProtectionWindow?.rootViewController?.present(passcodeViewController, animated: true, completion: {
            completion()
        })
    }

    func isPasscodePresented() -> Bool {
        return privacyProtectionWindow?.rootViewController?.presentedViewController is TOPasscodeViewController
    }

    func enableTouchFaceID() {
        guard !account.isEmpty,
              CCUtility.getEnableTouchFaceID(),
              CCUtility.isPasscodeAtStartEnabled(),
              let passcodeViewController = privacyProtectionWindow?.rootViewController?.presentedViewController as? TOPasscodeViewController
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { (success, error) in
                if success {
                    DispatchQueue.main.async {
                        passcodeViewController.dismiss(animated: true) {
                            self.hidePrivacyProtectionWindow()
                            self.requestAccount()
                        }
                    }
                }
            }
        }
    }

    func didInputCorrectPasscode(in passcodeViewController: TOPasscodeViewController) {
        DispatchQueue.main.async {
            passcodeViewController.dismiss(animated: true) {
                self.hidePrivacyProtectionWindow()
                self.requestAccount()
            }
        }
    }

    func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {
        return code == CCUtility.getPasscode()
    }

    func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {
        enableTouchFaceID()
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
         Example:
         nextcloud://open-action?action=create-voice-memo&&user=marinofaggiana&url=https://cloud.nextcloud.com
         */

        if !account.isEmpty && scheme == NCGlobal.shared.appScheme && action == "open-action" {

            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {

                let queryItems = urlComponents.queryItems
                guard let actionScheme = CCUtility.value(forKey: "action", fromQueryItems: queryItems), let rootViewController = window?.rootViewController else { return false }
                guard let userScheme = CCUtility.value(forKey: "user", fromQueryItems: queryItems) else { return false }
                guard let urlScheme = CCUtility.value(forKey: "url", fromQueryItems: queryItems) else { return false }
                if getMatchedAccount(userId: userScheme, url: urlScheme) == nil {
                    let message = String(format: NSLocalizedString("_account_not_exists_", comment: ""), userScheme, urlScheme)

                    let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

                    window?.rootViewController?.present(alertController, animated: true, completion: { })

                    return false
                }


                switch actionScheme {
                case NCGlobal.shared.actionUploadAsset:

                    NCAskAuthorization.shared.askAuthorizationPhotoLibrary(viewController: rootViewController) { hasPermission in
                        if hasPermission {
                            NCPhotosPickerViewController.init(viewController: rootViewController, maxSelectedAssets: 0, singleSelectedMode: false)
                        }
                    }
                    
                case NCGlobal.shared.actionScanDocument:

                    NCDocumentCamera.shared.openScannerDocument(viewController: rootViewController)

                case NCGlobal.shared.actionTextDocument:
                    
                    guard let navigationController = UIStoryboard(name: "NCCreateFormUploadDocuments", bundle: nil).instantiateInitialViewController(), let directEditingCreators = NCManageDatabase.shared.getDirectEditingCreators(account: account), let directEditingCreator = directEditingCreators.first(where: { $0.editor == NCGlobal.shared.editorText}) else { return false }
                    
                    navigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet

                    let viewController = (navigationController as! UINavigationController).topViewController as! NCCreateFormUploadDocuments
                    viewController.editorId = NCGlobal.shared.editorText
                    viewController.creatorId = directEditingCreator.identifier
                    viewController.typeTemplate = NCGlobal.shared.templateDocument
                    viewController.serverUrl = activeServerUrl
                    viewController.titleForm = NSLocalizedString("_create_nextcloudtext_document_", comment: "")

                    rootViewController.present(navigationController, animated: true, completion: nil)
                    
                case NCGlobal.shared.actionVoiceMemo:
                    
                    NCAskAuthorization.shared.askAuthorizationAudioRecord(viewController: rootViewController) { hasPermission in
                        if hasPermission {
                            let fileName = CCUtility.createFileNameDate(NSLocalizedString("_voice_memo_filename_", comment: ""), extension: "m4a")!
                            let viewController = UIStoryboard(name: "NCAudioRecorderViewController", bundle: nil).instantiateInitialViewController() as! NCAudioRecorderViewController

                            viewController.delegate = self
                            viewController.createRecorder(fileName: fileName)
                            viewController.modalTransitionStyle = .crossDissolve
                            viewController.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext

                            rootViewController.present(viewController, animated: true, completion: nil)
                        }
                    }

                default:
                    print("No action")
                }
            }
            return true
        }

        /*
         Example:
         nextcloud://open-file?path=Talk/IMG_0000123.jpg&user=marinofaggiana&link=https://cloud.nextcloud.com/f/123
         */

        else if !account.isEmpty && scheme == NCGlobal.shared.appScheme && action == "open-file" {

            if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {

                let queryItems = urlComponents.queryItems
                guard let userScheme = CCUtility.value(forKey: "user", fromQueryItems: queryItems) else { return false }
                guard let pathScheme = CCUtility.value(forKey: "path", fromQueryItems: queryItems) else { return false }
                guard let linkScheme = CCUtility.value(forKey: "link", fromQueryItems: queryItems) else { return false }
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
                        changeAccount(account.account)
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

        guard
            let navigationController = UIStoryboard(name: "NCCreateFormUploadVoiceNote", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                let viewController = navigationController.topViewController as? NCCreateFormUploadVoiceNote
        else { return }
        navigationController.modalPresentationStyle = .formSheet
        viewController.setup(serverUrl: activeServerUrl, fileNamePath: NSTemporaryDirectory() + fileName, fileName: fileName)
        window?.rootViewController?.present(navigationController, animated: true)
    }

    func didFinishWithoutRecording(_ viewController: NCAudioRecorderViewController, fileName: String) {
    }
}

extension AppDelegate: NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        guard let metadatas = metadatas, !metadatas.isEmpty else { return }
        NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: metadatas) { _ in }
    }
}
