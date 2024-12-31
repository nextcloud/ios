//
//  DataProtectionAgreementManager.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 27.11.2024.
//  Copyright © 2024 STRATO AG
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
        static let agreementWasShown = "data_protection_agreement_was_shown"
    }
    
    private init() {
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
    
    func showAgreement() {
        let wasAgreementShown = UserDefaults.standard.bool(forKey: DataProtectionKeys.agreementWasShown)
        if !wasAgreementShown {
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
        agreementWasShown(true)
        askForTrackingPermission { [weak self] _ in
            self?.dismissView()
        }
    }
    
    func saveSettings() {
        agreementWasShown(true)
        dismissView()
    }
    
    func rejectAgreement() {
        agreementWasShown(true)
        askForTrackingPermission { [weak self] granted in
            if granted {
                self?.redirectToSettings()
            }
            else {
                self?.dismissView()
            }
        }
    }
    
    func onAccountDeleted() {
        agreementWasShown(false)
    }
    
    private func agreementWasShown(_ wasShown: Bool) {
        UserDefaults.standard.set(wasShown, forKey: DataProtectionKeys.agreementWasShown)
    }
    
    func allowAnalysisOfDataCollection(_ allowAnalysisOfDataCollection: Bool, redirectToSettings: (() -> Void)?) {
        askForTrackingPermission { granted in
            if granted != allowAnalysisOfDataCollection {
                redirectToSettings?()
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
    
    private func redirectToSettings() {
        let alert = UIAlertController(title: NSLocalizedString("_alert_tracking_access", comment: ""), message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("_settings_", comment: ""), style: .default, handler: { (_) in
            DispatchQueue.main.async {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                }
            }
        }))
        
        DispatchQueue.main.async { [weak self] in
            self?.rootViewController.present(alert, animated: false)
        }
    }
}
