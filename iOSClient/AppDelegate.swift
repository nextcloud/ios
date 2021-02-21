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
import NCCommunication
import TOPasscodeViewController
import LocalAuthentication
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, TOPasscodeViewControllerDelegate {

    var backgroundSessionCompletionHandler: (() -> Void)?
    var window: UIWindow?

    @objc var account: String = ""
    @objc var urlBase: String = ""
    @objc var user: String = ""
    @objc var userID: String = ""
    @objc var password: String = ""
    
    var activeFavorite: NCFavorite?
    var activeFiles: NCFiles?
    var activeFileViewInFolder: NCFileViewInFolder?
    var activeLogin: CCLogin?
    var activeLoginWeb: NCLoginWeb?
    @objc var activeMedia: NCMedia?
    var activeMore: NCMore?
    var activeOffline: NCOffline?
    var activeRecent: NCRecent?
    var activeServerUrl: String = ""
    var activeShares: NCShares?
    var activeTransfers: NCTransfers?
    var activeTrash: NCTrash?
    var activeViewController: UIViewController?
    var activeViewerVideo: NCViewerVideo?
    
    struct progressType {
        var progress: Float
        var totalBytes: Int64
        var totalBytesExpected: Int64
    }
    
    var listFilesVC: [String:NCFiles] = [:]
    var listFavoriteVC: [String:NCFavorite] = [:]
    var listOfflineVC: [String:NCOffline] = [:]
    var listProgress: [String:progressType] = [:]
    
    var disableSharesView: Bool = false
    var documentPickerViewController: NCDocumentPickerViewController?
    var networkingAutoUpload: NCNetworkingAutoUpload?
    var passcodeViewController: TOPasscodeViewController?
    var pasteboardOcIds: [String] = []
    var shares: [tableShare] = []
    var ncUserDefaults: UserDefaults?
    @objc var timerErrorNetworking: Timer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let userAgent = CCUtility.getUserAgent() as String
        let isSimulatorOrTestFlight = NCUtility.shared.isSimulatorOrTestFlight()
        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, NCUtility.shared.getVersionApp())

        UserDefaults.standard.register(defaults: ["UserAgent" : userAgent])
        if !CCUtility.getDisableCrashservice() && !NCBrandOptions.shared.disable_crash_service == false {
            FirebaseApp.configure()
        }
        
        CCUtility.createDirectoryStandard()
        CCUtility.emptyTemporaryDirectory()
        
        NCCommunicationCommon.shared.setup(delegate: NCNetworking.shared)
        NCCommunicationCommon.shared.setup(userAgent: userAgent)
        
        startTimerErrorNetworking()

        // LOG
        let levelLog = CCUtility.getLogLevel()
        NCCommunicationCommon.shared.levelLog = levelLog
        if let pathDirectoryGroup = CCUtility.getDirectoryGroup()?.path {
            NCCommunicationCommon.shared.pathLog = pathDirectoryGroup
        }
        NCCommunicationCommon.shared.copyLogToDocumentDirectory = true
        if isSimulatorOrTestFlight {
            NCCommunicationCommon.shared.writeLog("Start session with level \(levelLog) " + versionNextcloudiOS + " (Simulator / TestFlight)")
        } else {
            NCCommunicationCommon.shared.writeLog("Start session with level \(levelLog) " + versionNextcloudiOS)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(initializeMain(notification:)), name: NSNotification.Name(rawValue: NCBrandGlobal.shared.notificationCenterInitializeMain), object: nil)
        
        if let tableAccount = NCManageDatabase.shared.getAccountActive() {
            
            // FIX 3.0.5 lost urlbase
            if tableAccount.urlBase.count == 0 {
                let user = tableAccount.user + " "
                let urlBase = tableAccount.account.replacingOccurrences(of: user, with: "")
                tableAccount.urlBase = urlBase
                NCManageDatabase.shared.updateAccount(tableAccount)
            }
            
            settingAccount(tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, userID: tableAccount.userID, password: CCUtility.getPassword(tableAccount.account))
            
        } else {
            
            CCUtility.deleteAllChainStore()
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        }
        
        ncUserDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroups)
        
        // Push Notification
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (_, _) in }

        // AV
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(error)
        }
        application.beginReceivingRemoteControlEvents()
                
        // Store review
        if !NCUtility.shared.isSimulatorOrTestFlight() {
            let review = NCStoreReview()
            review.incrementAppRuns()
            review.showStoreReview()
        }
        
        // Detect Dark mode
        if #available(iOS 13.0, *) {
            if CCUtility.getDarkModeDetect() {
                if UITraitCollection.current.userInterfaceStyle == .dark {
                    CCUtility.setDarkMode(true)
                } else {
                    CCUtility.setDarkMode(false)
                }
            }
        }
        
        if NCBrandOptions.shared.disable_intro {
            CCUtility.setIntro(true)
            if account == "" {
                openLogin(viewController: nil, selector: NCBrandGlobal.shared.introLogin, openLoginWeb: false)
            }
        } else {
            if !CCUtility.getIntro() {
                if let introViewController = UIStoryboard(name: "NCIntro", bundle: nil).instantiateInitialViewController() {
                    let navController = UINavigationController(rootViewController: introViewController)
                    window?.rootViewController = navController
                    window?.makeKeyAndVisible()
                }
            }
        }
        
        // init home
        NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationCenterInitializeMain)

        // Passcode
        DispatchQueue.global().async {
            self.passcodeWithAutomaticallyPromptForBiometricValidation(true)
        }
                
        // Auto upload
        networkingAutoUpload = NCNetworkingAutoUpload.init()
        
        // Background task: register
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: NCBrandGlobal.shared.refreshTask, using: nil) { task in
                self.handleRefreshTask(task)
            }
            BGTaskScheduler.shared.register(forTaskWithIdentifier: NCBrandGlobal.shared.processingTask, using: nil) { task in
                self.handleProcessingTask(task)
            }
        } else {
            application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        }
        
        return true
    }

    // L' applicazione entrerà in primo piano (attivo sempre)
    func applicationDidBecomeActive(_ application: UIApplication) {
        NCSettingsBundleHelper.setVersionAndBuildNumber()
        if account == "" { return}

        NCNetworking.shared.verifyUploadZombie()
    }
    
    // L' applicazione entrerà in primo piano (attivo solo dopo il background)
    func applicationWillEnterForeground(_ application: UIApplication) {
        if account == "" { return}

        NCCommunicationCommon.shared.writeLog("Application will enter in foreground")
        
        // Request Passcode
        passcodeWithAutomaticallyPromptForBiometricValidation(true)
        
        // Initialize Auto upload
        NCAutoUpload.shared.initAutoUpload(viewController: nil) { (_) in }
                
        // Required unsubscribing / subscribing
        NCPushNotification.shared().pushNotification()
        
        // Request Service Server Nextcloud
        NCService.shared.startRequestServicesServer()
        
        NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationCenterApplicationWillEnterForeground)
        NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationCenterRichdocumentGrabFocus)
        NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationCenterReloadDataSourceNetworkForced)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        if account == "" { return}
        
        if activeFileViewInFolder != nil {
            activeFileViewInFolder?.dismiss(animated: false, completion: {
                self.activeFileViewInFolder = nil
            })
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        if account == "" { return}
        
        NCCommunicationCommon.shared.writeLog("Application did enter in background")
        NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationCenterApplicationDidEnterBackground)
        passcodeWithAutomaticallyPromptForBiometricValidation(false)
        
        if #available(iOS 13.0, *) {
            scheduleAppRefresh()
            scheduleBackgroundProcessing()
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        NCCommunicationCommon.shared.writeLog("bye bye")
    }
    
    // MARK: -

    @objc func initializeMain(notification: NSNotification) {
        
        if account == "" { return}

        NCCommunicationCommon.shared.writeLog("initialize Main")
        
        // Clear error certificate
        CCUtility.setCertificateError(account, error: false)
        
        // Registeration push notification
        NCPushNotification.shared().pushNotification()
        
        // Setting Theming
        NCBrandColor.shared.settingThemingColor(account: account)
        
        // Start Auto Upload
        NCAutoUpload.shared.initAutoUpload(viewController: nil) { (_) in }
        
        // Start services
        NCService.shared.startRequestServicesServer()
        
        // close detail
        NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationCenterMenuDetailClose)

        // Registeration domain File Provider
        //FileProviderDomain *fileProviderDomain = [FileProviderDomain new];
        //[fileProviderDomain removeAllDomains];
        //[fileProviderDomain registerDomains];
    }
  
    // MARK: - Background Task
    
    @available(iOS 13.0, *)
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest.init(identifier: NCBrandGlobal.shared.refreshTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // Refresh after 5 minutes.
        do {
            try BGTaskScheduler.shared.submit(request)
            NCCommunicationCommon.shared.writeLog("Refresh task success submit request \(request)")
        } catch {
            NCCommunicationCommon.shared.writeLog("Refresh task failed to submit request: \(error)")
        }
    }
    
    @available(iOS 13.0, *)
    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest.init(identifier: NCBrandGlobal.shared.processingTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // Refresh after 5 minutes.
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
            NCCommunicationCommon.shared.writeLog("Background Processing task success submit request \(request)")
        } catch {
            NCCommunicationCommon.shared.writeLog("Background Processing task failed to submit request: \(error)")
        }
    }
    
    @available(iOS 13.0, *)
    func handleRefreshTask(_ task: BGTask) {
        if account == "" {
            task.setTaskCompleted(success: true)
            return
        }
        NCCommunicationCommon.shared.writeLog("Start handler refresh task [Auto upload]")
        NCAutoUpload.shared.initAutoUpload(viewController: nil) { (items) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                NCCommunicationCommon.shared.writeLog("Completition handler refresh task with %lu uploads [Auto upload]")
                task.setTaskCompleted(success: true)
            }
        }
    }
    
    @available(iOS 13.0, *)
    func handleProcessingTask(_ task: BGTask) {
        if account == "" {
            task.setTaskCompleted(success: true)
            return
        }
        NCCommunicationCommon.shared.writeLog("Start handler processing task [Synchronize Favorite & Offline]")
        NCNetworking.shared.listingFavoritescompletion(selector: NCBrandGlobal.shared.selectorReadFile) { (account, metadatas, errorCode, errorDescription) in
            NCCommunicationCommon.shared.writeLog("Completition listing favorite with error: \(errorCode)")
        }
        NCService.shared.synchronizeOffline(account: account)
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            NCCommunicationCommon.shared.writeLog("Completition handler processing task [Synchronize Favorite & Offline]")
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - Fetch

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if account == "" {
            completionHandler(UIBackgroundFetchResult.noData)
            return
        }
        NCCommunicationCommon.shared.writeLog("Start perform Fetch [Auto upload]")
        NCAutoUpload.shared.initAutoUpload(viewController: nil) { (items) in
            NCCommunicationCommon.shared.writeLog("Completition perform Fetch with \(items) uploads [Auto upload]")
            if items == 0 {
                completionHandler(UIBackgroundFetchResult.noData)
            } else {
                completionHandler(UIBackgroundFetchResult.newData)
            }
        }
    }
    
    // MARK: - Background Networking Session

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        NCCommunicationCommon.shared.writeLog("Start handle Events For Background URLSession: \(identifier)")
        backgroundSessionCompletionHandler = completionHandler
    }
    
    // MARK: - Push Notifications
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(UNNotificationPresentationOptions.alert)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NCPushNotification.shared().registerForRemoteNotifications(withDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NCPushNotification.shared().applicationdidReceiveRemoteNotification(userInfo) { (result) in
            completionHandler(result)
        }
    }
        
    // MARK: - Login & checkErrorNetworking

    @objc func openLogin(viewController: UIViewController?, selector: Int, openLoginWeb: Bool) {
        
    }

    @objc func startTimerErrorNetworking() {
        timerErrorNetworking = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(checkErrorNetworking), userInfo: nil, repeats: true)
    }
    
    @objc func checkErrorNetworking() {
        
        if account == "" { return }
        
        // check unauthorized server (401)
        if CCUtility.getPasscode()?.count == 0 {
            openLogin(viewController: window?.rootViewController, selector: NCBrandGlobal.shared.introLogin, openLoginWeb: true)
        }
        
        // check certificate untrusted (-1202)
        if CCUtility.getCertificateError(account) {
            
            let alertController = UIAlertController(title: NSLocalizedString("_ssl_certificate_untrusted_", comment: ""), message: NSLocalizedString("_connect_server_anyway_", comment: ""), preferredStyle: .alert)
                        
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { action in
                NCNetworking.shared.writeCertificate(directoryCertificate: CCUtility.getDirectoryCerificates())
                self.startTimerErrorNetworking()
            }))
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { action in
                self.startTimerErrorNetworking()
            }))
            
            window?.rootViewController?.present(alertController, animated: true, completion: {
                self.timerErrorNetworking?.invalidate()
            })
        }
    }
    
    // MARK: - Account & Communication
    
    @objc func settingAccount(_ account: String, urlBase: String, user: String, userID: String, password: String) {
        
        self.account = account
        self.urlBase = urlBase
        self.user = user
        self.userID = userID
        self.password = password
        
        _ = NCNetworkingNotificationCenter.shared
        
        NCCommunicationCommon.shared.setup(account: account, user: user, userId: userID, password: password, urlBase: urlBase)
        NCCommunicationCommon.shared.setup(webDav: NCUtilityFileSystem.shared.getWebDAV(account: account))
        NCCommunicationCommon.shared.setup(dav: NCUtilityFileSystem.shared.getDAV())
        let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        if serverVersionMajor > 0 {
            NCCommunicationCommon.shared.setup(nextcloudVersion: serverVersionMajor)
        }
    }
    
    @objc func deleteAccount(_ account: String, wipe: Bool) {
        
        // Push Notification
        if let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) {
            NCPushNotification.shared().unsubscribingNextcloudServerPushNotification(account.account, urlBase: account.urlBase, user: account.user, withSubscribing: false)
        }
        
        settingAccount("", urlBase: "", user: "", userID: "", password: "")
        
        let results = NCManageDatabase.shared.getTableLocalFiles(predicate: NSPredicate(format: "account == %@", account), sorted: "ocId", ascending: false)
        for result in results {
            CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(result.ocId))
        }
        NCManageDatabase.shared.clearDatabase(account: account, removeAccount: true)
        
        CCUtility.clearAllKeysEnd(toEnd: account)
        CCUtility.clearAllKeysPushNotification(account)
        CCUtility.setCertificateError(account, error: false)
        CCUtility.setPassword(account, password: nil)
        
        if wipe {
            let accounts = NCManageDatabase.shared.getAccounts()
            if accounts?.count ?? 0 > 0 {
                if let newAccount = accounts?.first {
                    if let account = NCManageDatabase.shared.setAccountActive(newAccount) {
                        settingAccount(account.account, urlBase: account.urlBase, user: account.user, userID: account.userID, password: CCUtility.getPassword(account.account))
                        NotificationCenter.default.postOnMainThread(name: NCBrandGlobal.shared.notificationCenterInitializeMain)
                    }
                }
            } else {
                openLogin(viewController: window?.rootViewController, selector: NCBrandGlobal.shared.introLogin, openLoginWeb: false)
            }
        }
    }
    
    // MARK: - TOPasscodeViewController
    
    func passcodeWithAutomaticallyPromptForBiometricValidation(_ automaticallyPromptForBiometricValidation: Bool) {
        
        let laContext = LAContext()
        var error: NSError?
        
        if CCUtility.getPasscode()?.count == 0 || account == "" || CCUtility.getNotPasscodeAtStart() { return }
        if passcodeViewController == nil {
            passcodeViewController = TOPasscodeViewController.init(style: .translucentLight, passcodeType: .sixDigits)
            if #available(iOS 13.0, *) {
                if UITraitCollection.current.userInterfaceStyle == .dark {
                    passcodeViewController?.style = .translucentDark
                }
            }
            passcodeViewController?.delegate = self
            passcodeViewController?.keypadButtonShowLettering = false
            if CCUtility.getEnableTouchFaceID() && laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                if error == nil {
                    if laContext.biometryType == .faceID  {
                        passcodeViewController?.biometryType = .faceID
                        passcodeViewController?.allowBiometricValidation = true
                    } else if laContext.biometryType == .touchID  {
                        passcodeViewController?.biometryType = .touchID
                        passcodeViewController?.allowBiometricValidation = true
                    }
                }
            }
            if let passcodeViewController = self.passcodeViewController {
                window?.rootViewController?.present(passcodeViewController, animated: true, completion: {
                    self.enableTouchFaceID(automaticallyPromptForBiometricValidation)
                })
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.enableTouchFaceID(automaticallyPromptForBiometricValidation)
            }
        }
    }
        
    func didInputCorrectPasscode(in passcodeViewController: TOPasscodeViewController) {
        passcodeViewController.dismiss(animated: true) {
            self.passcodeViewController = nil
        }
    }
    
    func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {
        return code == CCUtility.getPasscode()
    }
    
    func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {
        LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { (success, error) in
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    passcodeViewController.dismiss(animated: true) {
                        self.passcodeViewController = nil
                    }
                }
            }
        }
    }
    
    func enableTouchFaceID(_ automaticallyPromptForBiometricValidation: Bool) {
        if CCUtility.getEnableTouchFaceID() && automaticallyPromptForBiometricValidation && passcodeViewController?.view.window != nil {
            LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { (success, error) in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.passcodeViewController?.dismiss(animated: true) {
                            self.passcodeViewController = nil
                        }
                    }
                }
            }
        }
    }
}

