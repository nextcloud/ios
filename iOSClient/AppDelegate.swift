// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2014 Marino Faggiana [Start 04/09/14]
// SPDX-FileCopyrightText: 2021 Marino Faggiana [Swift 19/02/21]
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import BackgroundTasks
import NextcloudKit
import LocalAuthentication
import Firebase
import WidgetKit
import Queuer
import EasyTipView
import SwiftUI
import RealmSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var backgroundSessionCompletionHandler: (() -> Void)?
    var isUiTestingEnabled: Bool {
        return ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }
    var notificationSettings: UNNotificationSettings?
    var pushKitToken: String?

    var loginFlowV2Token = ""
    var loginFlowV2Endpoint = ""
    var loginFlowV2Login = ""

    let backgroundQueue = DispatchQueue(label: "com.nextcloud.bgTaskQueue")
    let global = NCGlobal.shared

    var pushSubscriptionTask: Task<Void, Never>?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if isUiTestingEnabled {
            Task {
                await NCAccount().deleteAllAccounts()
            }
        }
        let utilityFileSystem = NCUtilityFileSystem()
        let utility = NCUtility()

        utilityFileSystem.createDirectoryStandard()
        utilityFileSystem.emptyTemporaryDirectory()
        utilityFileSystem.clearCacheDirectory("com.limit-point.LivePhoto")

        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionBuild())

        NCAppVersionManager.shared.checkAndUpdateInstallState()
        NCSettingsBundleHelper.checkAndExecuteSettings(delay: 0)

        UserDefaults.standard.register(defaults: ["UserAgent": userAgent])

        #if !DEBUG
        if !NCPreferences().disableCrashservice, !NCBrandOptions.shared.disable_crash_service {
            FirebaseApp.configure()
        }
        #endif

        NCBrandColor.shared.createUserColors()

        NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup,
                                  delegate: NCNetworking.shared)

        NextcloudKit.configureLogger(logLevel: (NCBrandOptions.shared.disable_log ? .disabled : NCPreferences().log))

        nkLog(start: "Start session with level \(NCPreferences().log) " + versionNextcloudiOS)

        // Push Notification & display notification
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            self.notificationSettings = settings
        }
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

#if !targetEnvironment(simulator)
        let review = NCStoreReview()
        review.incrementAppRuns()
        review.showStoreReview()
#endif

        // BACKGROUND TASK
        //
        BGTaskScheduler.shared.register(forTaskWithIdentifier: global.refreshTask, using: backgroundQueue) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAppRefresh(appRefreshTask)
        }
        scheduleAppRefresh()

        BGTaskScheduler.shared.register(forTaskWithIdentifier: global.processingTask, using: backgroundQueue) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleProcessingTask(processingTask)
        }
        scheduleAppProcessing()

        if NCBrandOptions.shared.enforce_passcode_lock {
            NCPreferences().requestPasscodeAtStart = true
        }

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        if self.notificationSettings?.authorizationStatus != .denied && UIApplication.shared.backgroundRefreshStatus == .available {
            let content = UNMutableNotificationContent()
            content.title = NCBrandOptions.shared.brand
            content.body = NSLocalizedString("_keep_running_", comment: "")
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.add(req)
        }

        nkLog(debug: "bye bye")
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Background Task

    /*
    @discussion Schedule a refresh task request to ask that the system launch your app briefly so that you can download data and keep your app's contents up-to-date. The system will fulfill this request intelligently based on system conditions and app usage.
     */
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: global.refreshTask)

        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Refresh after 60 seconds.

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            nkLog(tag: self.global.logTagTask, emoji: .error, message: "Refresh task failed to submit request: \(error)")
        }
    }

    /*
     @discussion Schedule a processing task request to ask that the system launch your app when conditions are favorable for battery life to handle deferrable, longer-running processing, such as syncing, database maintenance, or similar tasks. The system will attempt to fulfill this request to the best of its ability within the next two days as long as the user has used your app within the past week.
     */
    func scheduleAppProcessing() {
        let request = BGProcessingTaskRequest(identifier: global.processingTask)

        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // Refresh after 5 minutes.
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            nkLog(tag: self.global.logTagTask, emoji: .error, message: "Processing task failed to submit request: \(error)")
        }
    }

    func handleAppRefresh(_ task: BGAppRefreshTask) {
        nkLog(tag: self.global.logTagTask, emoji: .start, message: "Start refresh task")

        var didComplete = false

        task.expirationHandler = {
            nkLog(tag: self.global.logTagTask, emoji: .warning, message: "Refresh task expiration handler")
            if !didComplete {
                task.setTaskCompleted(success: false)
                didComplete = true
            }
        }

        guard NCManageDatabase.shared.openRealmBackground() else {
            nkLog(tag: self.global.logTagTask, emoji: .error, message: "Failed to open Realm in background")
            task.setTaskCompleted(success: false)
            return
        }

        // Schedule next refresh
        scheduleAppRefresh()

        Task {
            defer {
                if !didComplete {
                    task.setTaskCompleted(success: true)
                    didComplete = true
                }
            }

            guard let tblAccount = await NCManageDatabase.shared.getActiveTableAccountAsync() else {
                nkLog(tag: self.global.logTagTask, emoji: .info, message: "No active account or background task already running")
                return
            }

            let numTransfers = await backgroundSync(tblAccount: tblAccount)
            nkLog(tag: self.global.logTagTask, emoji: .success, message: "Refresh task completed with \(numTransfers) transfers")
        }
    }

    func handleProcessingTask(_ task: BGProcessingTask) {
        nkLog(tag: self.global.logTagTask, emoji: .start, message: "Start processing task")

        var didComplete = false

        task.expirationHandler = {
            nkLog(tag: self.global.logTagTask, emoji: .warning, message: "Processing task expiration handler")
            if !didComplete {
                task.setTaskCompleted(success: false)
                didComplete = true
            }
        }

        guard NCManageDatabase.shared.openRealmBackground() else {
            nkLog(tag: self.global.logTagTask, emoji: .error, message: "Failed to open Realm in background")
            task.setTaskCompleted(success: false)
            return
        }

        // Schedule next processing task
        scheduleAppProcessing()

       Task {
           defer {
               if !didComplete {
                   task.setTaskCompleted(success: true)
                   didComplete = true
               }
           }

           guard let tblAccount = await NCManageDatabase.shared.getActiveTableAccountAsync() else {
               nkLog(tag: self.global.logTagTask, emoji: .info, message: "No active account or background task already running")
               return
           }

           let numTransfers = await backgroundSync(tblAccount: tblAccount)
           nkLog(tag: self.global.logTagTask, emoji: .success, message: "Processing task completed with \(numTransfers) transfers of auto upload")
       }
    }

    func backgroundSync(tblAccount: tableAccount) async -> Int {
        var numTransfers: Int = 0
        let sortDescriptors = [
            RealmSwift.SortDescriptor(keyPath: "sessionDate", ascending: true)
        ]

        // DOWNLOAD
        let predicateDownload = NSPredicate(format: "status == %d", self.global.metadataStatusWaitDownload)
        let metadatasWaitDownlod = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicateDownload,
                                                                                   withSort: sortDescriptors,
                                                                                   withLimit: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload)

        if let metadatasWaitDownlod,
           !metadatasWaitDownlod.isEmpty {
            for metadata in metadatasWaitDownlod {
                let error = await NCNetworking.shared.downloadFileInBackground(metadata: metadata)

                if error == .success {
                    nkLog(tag: self.global.logTagBgSync, message: "Create new download \(metadata.fileName) in \(metadata.serverUrl)")
                } else {
                    nkLog(tag: self.global.logTagBgSync, emoji: .error, message: "Download failure \(metadata.fileName) in \(metadata.serverUrl) with error \(error.errorDescription)")
                }

                numTransfers += 1
            }
        }

        if numTransfers >= NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload {
            return numTransfers
        }

        // AUTO UPLOAD  for get new photo
        let num = await NCAutoUpload.shared.initAutoUpload(tblAccount: tblAccount)
        nkLog(tag: self.global.logTagBgSync, emoji: .start, message: "Auto upload with \(num) new photo for \(tblAccount.account)")

        // CREATION FOLDERS
        let predicateCreateFolder = NSPredicate(format: "status == %d AND sessionSelector == %@", self.global.metadataStatusWaitCreateFolder, self.global.selectorUploadAutoUpload)
        let metadatasWaitCreateFolder = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicateCreateFolder,
                                                                                        withLimit: NCBrandOptions.shared.httpMaximumConnectionsPerHost)

        if let metadatasWaitCreateFolder,
            !metadatasWaitCreateFolder.isEmpty {
            var successCountCreateFolder: Int = 0
            for metadata in metadatasWaitCreateFolder {
                let serverUrl = NCUtilityFileSystem().createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
                let resultsCreateFolder = await NCNetworking.shared.createFolder(fileName: metadata.fileName,
                                                                                 serverUrl: metadata.serverUrl,
                                                                                 overwrite: true,
                                                                                 session: NCSession.shared.getSession(account: metadata.account),
                                                                                 selector: metadata.sessionSelector)

                guard resultsCreateFolder.error == .success else {
                    nkLog(tag: self.global.logTagBgSync, emoji: .error, message: "Auto upload create folder \(serverUrl) with error: \(resultsCreateFolder.error.errorCode)")

                    return numTransfers
                }

                nkLog(tag: self.global.logTagBgSync, message: "Auto upload create folder \(serverUrl)")

                if resultsCreateFolder.serverExists == false {
                    numTransfers += 1
                    successCountCreateFolder += 1
                }
            }

            // Exit until there are no more folders to create
            if successCountCreateFolder == metadatasWaitCreateFolder.count {
                return numTransfers
            }
        }

        if numTransfers >= NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload {
            return numTransfers
        }

        // UPLOAD
        let predicateUpload = NSPredicate(format: "status == %d AND sessionSelector == %@ AND chunk == 0", self.global.metadataStatusWaitUpload, self.global.selectorUploadAutoUpload)
        let metadatasWaitUpload = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicateUpload,
                                                                                  withSort: sortDescriptors,
                                                                                  withLimit: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload)

        if let metadatasWaitUpload,
           !metadatasWaitUpload.isEmpty {

            let metadatas = await NCCameraRoll().extractCameraRoll(from: metadatasWaitUpload)

            for metadata in metadatas {
                let error = await NCNetworking.shared.uploadFileInBackground(metadata: metadata.detachedCopy())
                if error == .success {
                    nkLog(tag: self.global.logTagBgSync, message: "Create new upload \(metadata.fileName) in \(metadata.serverUrl)")
                } else {
                    nkLog(tag: self.global.logTagBgSync, emoji: .error, message: "Upload failure \(metadata.fileName) in \(metadata.serverUrl) with error \(error.errorDescription)")
                }

                numTransfers += 1
            }
        }

        return numTransfers
    }

    // MARK: - Background Networking Session

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        nkLog(debug: "Handle events For background URLSession: \(identifier)")

        if NCManageDatabase.shared.openRealmBackground() {
            WidgetCenter.shared.reloadAllTimelines()
        }

        backgroundSessionCompletionHandler = completionHandler
    }

    // MARK: - Push Notifications

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let pref = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup),
           let data = pref.object(forKey: "NOTIFICATION_DATA") as? [String: AnyObject] {
            nextcloudPushNotificationAction(data: data)
            pref.set(nil, forKey: "NOTIFICATION_DATA")
        }

        completionHandler()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        if let pushKitToken = NCPushNotificationEncryption.shared().string(withDeviceToken: deviceToken) {
            self.pushKitToken = pushKitToken
            pushSubscriptionTask = Task.detached { [weak self] in
                guard let self else { return }

                // Wait bounded time for maintenance to be OFF
                let canProceed = await NCAppStateManager.shared.waitForMaintenanceOffAsync()
                guard canProceed else {
                    nkLog(error: "[PUSH] Skipping subscription: maintenance mode still ON after timeout")
                    return
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)

                let tblAccounts = await NCManageDatabase.shared.getAllTableAccountAsync()
                for tblAccount in tblAccounts {
                    await self.subscribingPushNotification(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user)
                }
            }
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NCPushNotification.shared.applicationdidReceiveRemoteNotification(userInfo: userInfo) { result in
            completionHandler(result)
        }
    }

    func subscribingPushNotification(account: String, urlBase: String, user: String) {
#if !targetEnvironment(simulator)
        NCNetworking.shared.checkPushNotificationServerProxyCertificateUntrusted(viewController: UIApplication.shared.firstWindow?.rootViewController) { error in
            if error == .success {
                NCPushNotification.shared.subscribingNextcloudServerPushNotification(account: account, urlBase: urlBase, user: user, pushKitToken: self.pushKitToken)
            }
        }
#endif
    }

    func nextcloudPushNotificationAction(data: [String: AnyObject]) {
        guard let data = NCApplicationHandle().nextcloudPushNotificationAction(data: data)
        else {
            return
        }
        let account = data["account"] as? String ?? "unavailable"
        let app = data["app"] as? String

        func openNotification(controller: NCMainTabBarController) {
            if app == NCGlobal.shared.termsOfServiceName {
                Task {
                    await NCNetworking.shared.transferDispatcher.notifyAllDelegatesAsync { delegate in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        delegate.transferRequestData(serverUrl: nil)
                    }
                }
            } else if let navigationController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? UINavigationController,
                      let viewController = navigationController.topViewController as? NCNotification {
                viewController.modalPresentationStyle = .pageSheet
                viewController.session = NCSession.shared.getSession(account: account)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    controller.present(navigationController, animated: true, completion: nil)
                }
            }
        }

        if let controller = SceneManager.shared.getControllers().first(where: { $0.account == account }) {
            openNotification(controller: controller)
        } else if let tblAccount = NCManageDatabase.shared.getAllTableAccount().first(where: { $0.account == account }),
                  let controller = UIApplication.shared.firstWindow?.rootViewController as? NCMainTabBarController {
            Task { @MainActor in
                await NCAccount().changeAccount(tblAccount.account, userProfile: nil, controller: controller)
                openNotification(controller: controller)
            }
        } else {
            let message = NSLocalizedString("_the_account_", comment: "") + " " + account + " " + NSLocalizedString("_does_not_exist_", comment: "")
            let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
            UIApplication.shared.firstWindow?.rootViewController?.present(alertController, animated: true, completion: { })
        }
    }

    // MARK: -

    func trustCertificateError(host: String) {
        guard let activeTblAccount = NCManageDatabase.shared.getActiveTableAccount(),
              let currentHost = URL(string: activeTblAccount.urlBase)?.host,
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

    // MARK: - Reset Application

    func resetApplication() {
        let utilityFileSystem = NCUtilityFileSystem()

        NCNetworking.shared.cancelAllTask()

        URLCache.shared.removeAllCachedResponses()

        utilityFileSystem.removeGroupDirectoryProviderStorage()
        utilityFileSystem.removeGroupApplicationSupport()
        utilityFileSystem.removeDocumentsDirectory()
        utilityFileSystem.removeTemporaryDirectory()

        NCPreferences().removeAll()

        exit(0)
    }

    // MARK: - Universal Links

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        let applicationHandle = NCApplicationHandle()
        return applicationHandle.applicationOpenUserActivity(userActivity)
    }
}

// MARK: - Extension

extension AppDelegate: NCViewCertificateDetailsDelegate {
    func viewCertificateDetailsDismiss(host: String) {
        trustCertificateError(host: host)
    }
}

extension AppDelegate: NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        if let metadatas {
            Task {
                await NCManageDatabase.shared.addMetadatasAsync(metadatas)
            }
        }
    }
}
