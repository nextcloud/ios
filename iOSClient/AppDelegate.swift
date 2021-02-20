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
import NCCommunication
import TOPasscodeViewController

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, TOPasscodeViewControllerDelegate {

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
    @objc var timerErrorNetworking: Timer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
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
            
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        NCCommunicationCommon.shared.writeLog("bye bye")
    }
    
    // MARK: -

    func initializeMain(notification: NSNotification) {
        
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
  
    // MARK: Push Notifications
    
    // MARK: Login & checkErrorNetworking

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
    
    // MARK: Account & Communication
    
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
        
    }
    
    // MARK: - Passcode & Delegate
    
    func passcodeWithAutomaticallyPromptForBiometricValidation(_ automaticallyPromptForBiometricValidation: Bool) {
        
    }
}

