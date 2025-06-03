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

    /// Init 
    let global = NCGlobal.shared
    let database = NCManageDatabase.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if isUiTestingEnabled {
            NCAccount().deleteAllAccounts()
        }

        let utilityFileSystem = NCUtilityFileSystem()
        let utility = NCUtility()
        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionApp())

        NCAppVersionManager.shared.checkAndUpdateInstallState()
        NCSettingsBundleHelper.checkAndExecuteSettings(delay: 0)

        UserDefaults.standard.register(defaults: ["UserAgent": userAgent])
        if !NCKeychain().disableCrashservice, !NCBrandOptions.shared.disable_crash_service {
            FirebaseApp.configure()
        }

        utilityFileSystem.createDirectoryStandard()
        utilityFileSystem.emptyTemporaryDirectory()
        utilityFileSystem.clearCacheDirectory("com.limit-point.LivePhoto")

        NCBrandColor.shared.createUserColors()

        NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup,
                                  delegate: NCNetworking.shared)

        if NCBrandOptions.shared.disable_log {
            utilityFileSystem.removeFile(atPath: NextcloudKit.shared.nkCommonInstance.filenamePathLog)
            utilityFileSystem.removeFile(atPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/" + NextcloudKit.shared.nkCommonInstance.filenameLog)
        } else {
            NextcloudKit.shared.setupLog(pathLog: utilityFileSystem.directoryGroup,
                                         levelLog: NCKeychain().logLevel,
                                         copyLogToDocumentDirectory: true)
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start session with level \(NCKeychain().logLevel) " + versionNextcloudiOS)
        }

        /// Push Notification & display notification
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
            NCKeychain().requestPasscodeAtStart = true
        }

        /// Activation singleton
        _ = NCNetworking.shared
        _ = NCDownloadAction.shared
        _ = NCNetworkingProcess.shared

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

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] bye bye")
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
            if let date = request.earliestBeginDate {
                NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Refresh task scheduled (UTC) \(date.description(with: Locale(identifier: "en_US_POSIX")))")
            }
        } catch {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Refresh task failed to submit request: \(error)")
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
            if let date = request.earliestBeginDate {
                NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Processing task scheduled (UTC) \(date.description(with: Locale(identifier: "en_US_POSIX")))")
            }
        } catch {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Processing task failed to submit request: \(error)")
        }
    }

    func handleAppRefresh(_ task: BGAppRefreshTask) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Start refresh task")
        scheduleAppRefresh()
        isAppSuspending = false

        task.expirationHandler = {
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Refresh task expiration handler")
        }

        Task {
            let numTransfers = await autoUpload(limitUpload: 1)
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Processing task with \(numTransfers) transfers")

            task.setTaskCompleted(success: true)
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Refresh task completed")
        }
    }

    func handleProcessingTask(_ task: BGProcessingTask) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Start processing task")
        scheduleAppProcessing()
        isAppSuspending = false

        task.expirationHandler = {
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Processing task expiration handler")
        }

        Task {
            let numTransfers = await autoUpload(limitUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload)
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Processing task with \(numTransfers) transfers")

            task.setTaskCompleted(success: true)
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Processing task completed")
        }
    }

    func autoUpload(limitUpload: Int) async -> Int {
        var numTransfers: Int = 0
        var counterUploading: Int = 0

        func initAutoUpload(controller: NCMainTabBarController? = nil, account: String) async -> Int {
            await withUnsafeContinuation({ continuation in
                NCAutoUpload.shared.initAutoUpload(controller: controller, account: account) { num in
                    continuation.resume(returning: num)
                }
            })
        }

        guard let tblAccount = NCManageDatabase.shared.getActiveTableAccount()
        else {
            return numTransfers
        }

        /// AUTO UPLOAD ONLY FOR NEW PHOTO
        if tblAccount.autoUploadOnlyNew {
            let newAutoUpload = await initAutoUpload(account: tblAccount.account)
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Auto upload with \(newAutoUpload) uploads")
        } else {
            return 0
        }

        /// Creation folders
        let metadatasWaitCreateFolder = await self.database.getResultsMetadatasAsync(predicate: NSPredicate(format: "status == %d AND sessionSelector == %@", self.global.metadataStatusWaitCreateFolder, self.global.selectorUploadAutoUpload), limit: nil)

        if let metadatasWaitCreateFolder {
            for metadata in metadatasWaitCreateFolder {
                let errorCreateFolder = await NCNetworking.shared.createFolder(fileName: metadata.fileName,
                                                                               serverUrl: metadata.serverUrl,
                                                                               overwrite: true,
                                                                               session: NCSession.shared.getSession(account: metadata.account),
                                                                               selector: metadata.sessionSelector)

                NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Create auto upload folder with \(errorCreateFolder.errorCode)")

                guard errorCreateFolder == .success else {
                    return numTransfers
                }

                numTransfers += 1
            }
        }

        if let metadatasUploading = await self.database.getResultsMetadatasAsync(predicate: NSPredicate(format: "status == %d", self.global.metadataStatusUploading), limit: nil) {
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Already in uploading \(String(describing: metadatasUploading.count))")

            counterUploading = metadatasUploading.count
        }
        let limitUpload = NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload - counterUploading

        if limitUpload > 0 {
            let sortDescriptors = [
                RealmSwift.SortDescriptor(keyPath: "sessionDate", ascending: true)
            ]

            if let metadatasWaitUpload = await self.database.getResultsMetadatasAsync(predicate: NSPredicate(format: "status == %d AND sessionSelector == %@ AND chunk == 0", self.global.metadataStatusWaitUpload, self.global.selectorUploadAutoUpload), sortDescriptors: sortDescriptors, limit: limitUpload) {

                NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] In wait upload \(String(describing: metadatasWaitUpload.count))")

                for metadata in metadatasWaitUpload {
                    NCNetworking.shared.upload(metadata: tableMetadata(value: metadata))
                    NextcloudKit.shared.nkCommonInstance.writeLog("Create Upload \(metadata.fileName) in \(metadata.serverUrl)")
                    numTransfers += 1
                }
            }
        } else {
            numTransfers = counterUploading
        }

        return numTransfers
    }

    // MARK: - Background Networking Session

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Handle Events For Background URLSession: \(identifier)")
        WidgetCenter.shared.reloadAllTimelines()
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
            // https://github.com/nextcloud/talk-ios/issues/691
            for tblAccount in NCManageDatabase.shared.getAllTableAccount() {
                subscribingPushNotification(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user)
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
                NCNetworking.shared.notifyAllDelegates { delegate in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        } else if let tableAccount = NCManageDatabase.shared.getAllTableAccount().first(where: { $0.account == account }),
                  let controller = UIApplication.shared.firstWindow?.rootViewController as? NCMainTabBarController {
            NCAccount().changeAccount(tableAccount.account, userProfile: nil, controller: controller) {
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
        guard let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount(),
              let currentHost = URL(string: activeTableAccount.urlBase)?.host,
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

        NCKeychain().removeAll()

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
        guard let metadatas = metadatas, !metadatas.isEmpty else { return }
        NCNetworkingProcess.shared.createProcessUploads(metadatas: metadatas)
    }
}
