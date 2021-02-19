//
//  AppDelegate.swift
//

import UIKit
import NCCommunication
import TOPasscodeViewController

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var backgroundSessionCompletionHandler: (() -> Void)?

    var account: String = ""
    var urlBase: String = ""
    var user: String = ""
    var userID: String = ""
    var password: String = ""
    
    var activeFavorite: NCFavorite?
    var activeFiles: NCFiles?
    var activeFileViewInFolder: NCFileViewInFolder?
    var activeLogin: CCLogin?
    var activeLoginWeb: NCLoginWeb?
    var activeMedia: NCMedia?
    var activeMore: NCMore?
    var activeOffline: NCOffline?
    var activeRecent: NCRecent?
    var activeServerUrl: String = ""
    var activeShares: NCShares?
    var activeTransfers: NCTransfers?
    var activeTrash: NCTrash?
    var activeViewController: UIViewController?
    var activeViewerVideo: NCViewerVideo?
    
    var listFilesVC: [String:NCFiles] = [:]
    var listFavoriteVC: [String:NCFavorite] = [:]
    var listOfflineVC: [String:NCOffline] = [:]
    var listProgressMetadata: [String:tableMetadata] = [:]
    
    var disableSharesView: Bool = false
    var documentPickerViewController: NCDocumentPickerViewController?
    var networkingAutoUpload: NCNetworkingAutoUpload?
    var passcodeViewController: TOPasscodeViewController?
    var pasteboardOcIds: [String] = []
    var shares: [tableShare] = []
    var timerErrorNetworking: Timer?

    /*
    @property (nonatomic) UIUserInterfaceStyle preferredUserInterfaceStyle API_AVAILABLE(ios(12.0));
    @property (nonatomic, strong) NSUserDefaults *ncUserDefaults;
*/
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    // MARK: -

    func openLoginView(viewController: UIViewController?, selector: Int, openLoginWeb: Bool) {
        
    }

    func startTimerErrorNetworking() {
        timerErrorNetworking = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(checkErrorNetworking), userInfo: nil, repeats: true)
    }
    
    @objc func checkErrorNetworking() {
        
        if account == "" { return }
        
        // check unauthorized server (401)
        if CCUtility.getPasscode()?.count == 0 {
            openLoginView(viewController: window?.rootViewController, selector: NCBrandGlobal.shared.introLogin, openLoginWeb: true)
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
    
    // MARK: -
    
    func settingAccount(_ account: String, urlBase: String, user: String, userID: String, password: String) {
        
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
    
    func deleteAccount(_ account: String, wipe: Bool) {
        
    }
}

