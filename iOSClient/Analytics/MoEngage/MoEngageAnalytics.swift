//
//  MoEngageAnalytics.swift
//  Nextcloud
//
//  Created by Amrut Waghmare on 10/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import MoEngageSDK
import MoEngageInApps
import StoreKit
import OSLog

class MoEngageAnalytics: NSObject {
    static let shared = MoEngageAnalytics()
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MoEngage", category: "MoEngageAnalytics")
    
    // Initializer for the MoEngageAnalytics class
    override init() {
        super.init()
        
        log.debug("Initializing MoEngage SDK…")

        // Create a configuration object for MoEngage SDK with the given App ID and Data Center
        let sdkConfig = MoEngageSDKConfig(appId: "7KWWUKA6OKXGP8Q6DMCXLDX5", dataCenter: MoEngageDataCenter.data_center_02)
        
        // Disable periodic flushing of analytics data
        sdkConfig.analyticsDisablePeriodicFlush = true
        
        // Initialize the MoEngage SDK
        // Use different initialization methods for Debug and Production environments
        
#if DEBUG
        MoEngage.sharedInstance.initializeDefaultTestInstance(sdkConfig)
#else
        MoEngage.sharedInstance.initializeDefaultLiveInstance(sdkConfig)
#endif
        log.debug("MoEngage SDK initializeDefault instance set (debug: \( self._isDebugBuild() ))")

        Task { @MainActor in
            setupMoEngageInAppMessaging()
        }
        
        // Register delegate for In-App Native callbacks
        MoEngageSDKInApp.sharedInstance.setInAppDelegate(self)
        log.debug("MoEngage In-App delegate set")
    }
    
    // MARK: - Setup Helper
    /// Call this early in app lifecycle (e.g., AppDelegate didFinishLaunching or SceneDelegate willConnect)
    static func setupIfNeeded() {
        _ = MoEngageAnalytics.shared
    }

    // MARK: - UI Helpers
    private func activeWindowScene() -> UIWindowScene? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    private func topViewController(in root: UIViewController?) -> UIViewController? {
        guard let root = root else { return nil }
        if let nav = root as? UINavigationController { return topViewController(in: nav.visibleViewController) }
        if let tab = root as? UITabBarController { return topViewController(in: tab.selectedViewController) }
        if let presented = root.presentedViewController { return topViewController(in: presented) }
        return root
    }

    @MainActor
    func currentTopViewController() -> UIViewController? {
        // 1. Find the active window scene (Crucial for iPad)
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        
        // 2. Get the key window from that specific scene
        let keyWindow = activeScene?.windows.first { $0.isKeyWindow }
                        ?? activeScene?.windows.first
        
        // 3. Start from the rootViewController
        var topController = keyWindow?.rootViewController
        
        // 4. Drill down through navigation, tabs, and presented controllers
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        return topController
    }

    /// Safer wrapper that ensures visible scene and top VC before asking MoEngage to show in-apps
    @MainActor
    func displayInAppNotificationSafely(reason: String? = nil) {
        let reasonText = reason ?? "unspecified"
        
        // 1. Get all connected window scenes
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        
        // 2. Prioritize the scene that actually has the "Key Window" (Works best for iPad Split View)
        let activeScene = scenes.first { $0.windows.contains(where: { $0.isKeyWindow }) }
                          ?? scenes.first { $0.activationState == .foregroundActive }
        
        guard let scene = activeScene else {
            print("In-App not shown: No foreground window scene (reason: \(reasonText))")
            return
        }
        
        // 3. Ensure we have a valid top controller
        guard let topVC = currentTopViewController() else {
            print("In-App not shown: No top view controller available (reason: \(reasonText))")
            return
        }
        
        // 4. Trigger MoEngage
        // iPad Tip: MoEngage uses the key window to determine where to draw the UI
        if UIDevice.current.userInterfaceIdiom != .pad{
            self.triggerMoEngage()
        }
        else {
//#if targetEnvironment(simulator)
//            // Simulator: Always show fallback alert
//            print("In-App  shown: showInApp)")
//            let appID = "312838242"
//            
//            // Correct URLs with /app/id/ prefix
//            let webURLString = "https://apps.apple.com\(appID)?action=write-review"
//            
//            self.showSimulatorAlert(link: webURLString)
//#else
            // iPad Fallback: Scene might be transitioning. Retry once.
            print("iPad Scene transition detected. Retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.triggerMoEngage()
            }
//#endif
        }
    }

    private func triggerMoEngage() {
        MoEngageSDKInApp.sharedInstance.showInApp()
        MoEngageSDKInApp.sharedInstance.showNudge()
    }


    private func _isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // Method to track the App ID
    func trackAppId() {
        MoEngageSDKAnalytics.sharedInstance.trackLocale(forAppID: "312838242")
    }
    
    @MainActor func setupMoEngageInAppMessaging() {
        // MARK: MoEngage In-App messages
        log.debug("setupMoEngageInAppMessaging() — scheduling initial in-app evaluation")
        Task { @MainActor in
            displayInAppNotificationSafely(reason: "initial setup")
        }
    }

    // Helper to show the alert on the topmost view controller
    private func showSimulatorAlert(link: String) {
        let alert = UIAlertController(
            title: "Simulator Mode",
            message: "App Store links don't open in Simulator. On a real device, this would open: \(link)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Finds the current active window to present the alert
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        
        keyWindow?.rootViewController?.present(alert, animated: true)
    }

}

// AnalyticsService protocol
extension MoEngageAnalytics: AnalyticsService {
    // Method to track a specific event with optional properties
    func trackEvent(eventName: AnalyticEvents, properties: [String: Any]?) {
        let eventProperties = MoEngageProperties(withAttributes: properties)
        MoEngageSDKAnalytics.sharedInstance.trackEvent(eventName.moEngageEvent, withProperties: eventProperties)
        Task { @MainActor in
            // Re-evaluate in-app messages after trackEvent
            MoEngageAnalytics.shared.displayInAppNotificationSafely(reason: "track Event")
        }

    }
    
    // Method to track user data
    func trackUserData() {
        // Get the active user account from the database
        guard let user = NCManageDatabase.shared.getActiveTableAccount() else { return }
        
        // Set user attributes in the MoEngage SDK
        MoEngageSDKAnalytics.sharedInstance.setUniqueID(user.userId)
        MoEngageSDKAnalytics.sharedInstance.setName(user.displayName)
        MoEngageSDKAnalytics.sharedInstance.setEmailID(user.email)
        
        // Convert the user's total storage quota to a readable format and set it as a user attribute
        let storageCapacity = NCUtilityFileSystem().transformedSize(user.quotaTotal)
        MoEngageSDKAnalytics.sharedInstance.setUserAttribute(storageCapacity, withAttributeName: AnalyticEvents.USER_PROPERTIES_STORAGE_CAPACITY.rawValue)
        
        // Track whether auto-upload is enabled for the user
        trackAutoUpload(isEnable: user.autoUploadStart)
    }
    
    // Method to track the used storage data
    func trackUsedStorageData(quotaUsed: Int64) {
        MoEngageSDKAnalytics.sharedInstance.setUserAttribute(quotaUsed, withAttributeName: AnalyticEvents.USER_PROPERTIES_STORAGE_USED.rawValue)
    }
    
    // Method to track the auto-upload setting
    func trackAutoUpload(isEnable: Bool) {
        if isEnable {
            MoEngageSDKAnalytics.sharedInstance.setUserAttribute(isEnable, withAttributeName: AnalyticEvents.USER_PROPERTIES_AUTO_UPLOAD.rawValue)
        }
    }
    
    // Method to track the app version
    func trackAppVersion(oldVersion: String?) {
        // Get the app version and set it as a user attribute
        let version = NCUtility().getVersionBuild() as String
        
        // Check if a build version key is present in UserDefaults
        if let oldVersion {
            if version != oldVersion {
                MoEngageSDKAnalytics.sharedInstance.appStatus(.update)
                if let oldAppVersion = Int(oldVersion.dropLast().replacingOccurrences(of: ".", with: "")) {
                    if oldAppVersion < NCGlobal.shared.moEngageAppVersion {
                        trackUserData()
                    }
                }
            }
        } else {
            MoEngageSDKAnalytics.sharedInstance.appStatus(.install)
        }
        
        MoEngageSDKAnalytics.sharedInstance.setUserAttribute(version, withAttributeName: AnalyticEvents.USER_PROPERTIES_APP_VERSION.rawValue)
    }
    
    //Method to track user logout
    func trackLogout() {
        MoEngageSDKAnalytics.sharedInstance.resetUser()
    }
    
    //Method to track create file
    func trackCreateFile(metadata: tableMetadata) {
        let properties = MoEngageProperties()
        properties.addAttribute(getFileType(contentType: metadata.contentType), withName: AnalyticPropertyAttributes.PROPERTIES__FILE_TYPE.rawValue)
        properties.addAttribute(String(getFileSizeInMB(bytes: Int(metadata.size))), withName: AnalyticPropertyAttributes.PROPERTIES__FILE_SIZE.rawValue)
        properties.addAttribute(getDate(date: metadata.creationDate as Date), withName: AnalyticPropertyAttributes.PROPERTIES__CREATION_DATE.rawValue)
        MoEngageSDKAnalytics.sharedInstance.trackEvent(AnalyticEvents.EVENT__CREATE_FILE.rawValue, withProperties: properties)
    }
    
    //Method to track upload file
    func trackEventWithMetadata(eventName: AnalyticEvents, metadata: tableMetadata) {
        let properties = MoEngageProperties()
        properties.addAttribute(getFileType(contentType: metadata.contentType), withName: AnalyticPropertyAttributes.PROPERTIES__FILE_TYPE.rawValue)
        properties.addAttribute(String(getFileSizeInMB(bytes: Int(metadata.size))), withName: AnalyticPropertyAttributes.PROPERTIES__FILE_SIZE.rawValue)
        properties.addAttribute(getDate(date: metadata.creationDate as Date), withName: AnalyticPropertyAttributes.PROPERTIES__CREATION_DATE.rawValue)
        properties.addAttribute(getDate(date: metadata.uploadDate as Date), withName: AnalyticPropertyAttributes.PROPERTIES__UPLOAD_DATE.rawValue)
        MoEngageSDKAnalytics.sharedInstance.trackEvent(eventName.rawValue, withProperties: properties)
    }
    
    //Method to track create folder
    func trackCreateFolder(isEncrypted: Bool, creationDate: Date) {
        let properties = MoEngageProperties()
        properties.addAttribute(isEncrypted ? FolderType.FOLDER_ENCRYPTED.rawValue : FolderType.FOLDER_NORMAL.rawValue , withName: AnalyticPropertyAttributes.PROPERTIES__FILE_TYPE.rawValue)
        properties.addAttribute(getDate(date: creationDate), withName: AnalyticPropertyAttributes.PROPERTIES__CREATION_DATE.rawValue)
        MoEngageSDKAnalytics.sharedInstance.trackEvent(AnalyticEvents.EVENT__CREATE_FOLDER.rawValue, withProperties: properties)
    }
    
    //Method to track create voice memo
    func trackCreateVoiceMemo(size: Int64, date: Date) {
        let properties = MoEngageProperties()
        properties.addAttribute(FileType.AUDIO.rawValue, withName: AnalyticPropertyAttributes.PROPERTIES__FILE_TYPE.rawValue)
        properties.addAttribute(String(getFileSizeInMB(bytes: Int(size))), withName: AnalyticPropertyAttributes.PROPERTIES__FILE_SIZE.rawValue)
        properties.addAttribute(getDate(date: date), withName: AnalyticPropertyAttributes.PROPERTIES__CREATION_DATE.rawValue)
        MoEngageSDKAnalytics.sharedInstance.trackEvent(AnalyticEvents.EVENT__CREATE_VOICE_MEMO.rawValue, withProperties: properties)
    }
}

// Functions
extension MoEngageAnalytics {
    private func getFileType(contentType: String) -> String? {
        switch contentType {
        case "image/png":
            return FileType.FOTO.rawValue
        case "audio/x-m4a", "audio/mp4":
            return FileType.AUDIO.rawValue
        case "video/mp4":
            return FileType.VIDEO.rawValue
        case "application/pdf":
            return FileType.PDF.rawValue
        case "text/x-markdown","text/plain":
            return FileType.TEXT.rawValue
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return FileType.DOCX.rawValue
        case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","text/csv":
            return FileType.XLSX.rawValue
        case "application/vnd.openxmlformats-officedocument.presentationml.presentation":
            return FileType.PPT.rawValue
        default:
            return FileType.OTHER.rawValue
        }
    }
    
    private func getDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: date)
    }
    
    private func getFileSizeInMB(bytes: Int) -> Float {
        return round((Float(bytes) / Float(Size.MEGABYTE)) * 10) / 10
    }

}

// MARK: - MoEngage In-App Native Delegate
extension MoEngageAnalytics: MoEngageInAppNativeDelegate {

    // Called when user clicks an in-app with navigation action (e.g., deep link)
    func inAppClicked(withCampaignInfo inappCampaign: MoEngageInAppCampaign,
                      andNavigationActionInfo navigationAction: MoEngageInAppNavigationAction,
                      forAccountMeta accountMeta: MoEngageAccountMeta) {
        // handle navigation actions if needed
    }

    // Called when user clicks an in-app with custom action (e.g., our rating trigger)
    func inAppClicked(withCampaignInfo inappCampaign: MoEngageInAppCampaign,
                      andCustomActionInfo customAction: MoEngageInAppAction,
                      forAccountMeta accountMeta: MoEngageAccountMeta) {

        let kv = customAction.keyValuePairs
        log.debug("In-App custom action received: keyValues=\(kv)")

        if let showRating = kv["show-native-rating"] as? String,
           showRating.lowercased() == "true" {
            log.debug("User clicked Rating - Opening App Store directly")
            
            // Use the reliable direct link instead of the restricted native prompt
            ReviewManager.shared.requestReviewIfAppropriate()
        }
    }

    // Called when a "self-handled" in-app is triggered
    func selfHandledInAppTriggered(withInfo inAppCampaign: MoEngageInAppSelfHandledCampaign,
                                   forAccountMeta accountMeta: MoEngageAccountMeta) {
        log.debug("Self-handled in-app triggered: \(String(describing: inAppCampaign))")
    }

    // Optional — track impression
    func inAppShown(withCampaignInfo inappCampaign: MoEngageInAppCampaign,
                    forAccountMeta accountMeta: MoEngageAccountMeta) {
        log.debug("In-App shown: \(String(describing: inappCampaign))")
    }

    // Optional — track dismissal
    func inAppDismissed(withCampaignInfo inappCampaign: MoEngageInAppCampaign,
                        forAccountMeta accountMeta: MoEngageAccountMeta) {
        log.debug("In-App dismissed: \(String(describing: inappCampaign))")
    }
}

@MainActor // Ensures this is only called on the Main Thread
class UIHelper {
    
    static func getTopViewController() -> UIViewController? {
        // 1. Get the active scene
        let activeScene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        
        // 2. Get the root view controller from the key window
        let rootVC = activeScene?.windows
            .first { $0.isKeyWindow }?.rootViewController
            
        return findTopViewController(from: rootVC)
    }

    private static func findTopViewController(from root: UIViewController?) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return findTopViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return findTopViewController(from: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return findTopViewController(from: presented)
        }
        return root
    }
}

class ReviewManager {
    static let shared = ReviewManager()
    private let appID = "312838242"
    
    /// Requests the native system rating sheet if an active foreground scene is available.
    func requestReviewIfAppropriate() {
        // 1. Find the active, foreground UIWindowScene required by StoreKit
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            // Silently exit if no foreground view is active
//            // Fallback: If no scene is active (rare), open the App Store directly
//            self.forceOpenAppStore()
            return
        }
        
        // 2. Trigger the native system prompt overlay
        // Note: Apple will throttle this to 3 times per year maximum per user.
        SKStoreReviewController.requestReview(in: scene)
    }
    
    /// Call this function ONLY when a user explicitly taps a manual "Rate Us" button.
    func forceOpenAppStore() {
        let appStoreURLString = "itms-apps://://apple.com\(appID)?action=write-review"
        let webURLString = "https://apple.com\(appID)?action=write-review"
        
        if let url = URL(string: appStoreURLString), UIApplication.shared.canOpenURL(url) {
            // Opens the native iOS App Store app directly to your review composition page
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if let fallbackWebUrl = URL(string: webURLString) {
            // Fallback safety layer: Opens up your App Store page inside Safari
            UIApplication.shared.open(fallbackWebUrl, options: [:], completionHandler: nil)
        }
    }
}
