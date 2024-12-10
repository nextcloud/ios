//
//  DataProtectionAgreementManager.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 27.11.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit
import AppTrackingTransparency
import FirebaseAnalytics
import Firebase

class DataProtectionAgreementManager {
    private(set) static var shared = DataProtectionAgreementManager()
    
    private(set) var isViewVisible = false
    private var window: UIWindow?
    private var dismissBlock: (() -> Void)?
    
    var rootViewController: UIViewController
    
    struct DataProtectionKeys {
        static let accepted = "data_protection_agreement_accepted"
    }
    
    private init?() {
        rootViewController = DataProtectionHostingController(rootView: DataProtectionAgreementScreen())
    }
    
    private func instantiateWindow() {
        guard let windowScene = UIApplication.shared.firstWindow?.windowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = UIWindow.Level.alert
        window.rootViewController = rootViewController
        
        self.window = window
    }
    
    /// Remove the window from the stack making it not visible
    func dismissView() {
        guard Thread.current.isMainThread else {
            return DispatchQueue.main.async { [weak self] in
                self?.dismissView()
            }
        }
        guard isViewVisible else {
            return
        }
        
        isViewVisible = false
        window?.isHidden = true
        dismissBlock?()
    }
    
    /// Make the window visible
    ///
    /// - Parameter dismissBlock: Block to be called when `dismissView` is called
    func showView(dismissBlock: @escaping () -> Void) {
        guard Thread.current.isMainThread else {
            return DispatchQueue.main.async { [weak self] in
                self?.showView(dismissBlock: dismissBlock)
            }
        }
        guard !isViewVisible else {
            return
        }
        
        self.dismissBlock = dismissBlock
        
        if (window == nil) {
            instantiateWindow()
        }
        
        isViewVisible = true
        
        window?.isHidden = false
        window?.makeKeyAndVisible()
    }
    
    func checkAgreement() {
        let dataProtectionAccepted = UserDefaults.standard.bool(forKey: DataProtectionKeys.accepted)
        if !dataProtectionAccepted {
            showView { [weak self] in
                self?.setupAnalyticsCollection()
            }
        }
    }
    
    func setupAnalyticsCollection(){
        let isAllowed = isAllowedAnalysisOfDataCollection()
        Analytics.setAnalyticsCollectionEnabled(isAllowed)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(isAllowed)
    }
    
    func acceptAgreement() {
        UserDefaults.standard.set(true, forKey: DataProtectionKeys.accepted)
        askForTrackingPermission { [weak self] _ in
            self?.dismissView()
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(true, forKey: DataProtectionKeys.accepted)
        dismissView()
    }
    
    func rejectAgreement() {
        UserDefaults.standard.set(true, forKey: DataProtectionKeys.accepted)
        askForTrackingPermission { [weak self] granted in
            if granted {
                self?.redirectToSettings(onCancel: nil)
            }
            else {
                self?.dismissView()
            }
        }
    }
    
    func removeAgreement() {
        UserDefaults.standard.set(false, forKey: DataProtectionKeys.accepted)
    }
    
    func allowAnalysisOfDataCollection(_ allowAnalysisOfDataCollection: Bool, completion: ((_ allowChanges: Bool) -> Void)?) {
        askForTrackingPermission { [weak self] granted in
            if granted != allowAnalysisOfDataCollection {
                self?.redirectToSettings(onCancel: { onCancel in
                    completion?(!onCancel)
                })
            }
        }
    }
    
    func isAllowedAnalysisOfDataCollection() -> Bool {
        return ATTrackingManager.trackingAuthorizationStatus == .authorized
    }
    
    private func askForTrackingPermission(completion: ((_ isPermissionGranted: Bool) -> Void)?) {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined:    handleNotDetermined(completion: completion)
        case .authorized:       completion?(true)
        case .restricted,
                .denied:        completion?(false)
        @unknown default:       return
        }
    }
    
    private func handleNotDetermined(completion: ((_ isPermissionGranted: Bool) -> Void)?) {
        ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
            self?.askForTrackingPermission(completion: completion)
        }
    }
    
    private func redirectToSettings(onCancel: ((_ onCancel: Bool) -> Void)?) {
        let alert = UIAlertController(title: "", message: NSLocalizedString("_alert_tracking_access", comment: ""), preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in onCancel?(true) }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("_settings_", comment: ""), style: .default, handler: { (_) in
            onCancel?(false)
            DispatchQueue.main.async {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                }
            }
        }))
        
        if !(window?.isHidden ?? true) {
            DispatchQueue.main.async { [weak self] in
                self?.rootViewController.present(alert, animated: false)
            }
        }
        else if let controller = UIApplication.shared.firstWindow?.rootViewController as? NCMainTabBarController{
            DispatchQueue.main.async {
                controller.presentedViewController?.present(alert, animated: false)
            }
        }
    }
}
