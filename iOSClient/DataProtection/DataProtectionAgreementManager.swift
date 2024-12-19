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
    private var dismissBlock: (() -> Void)?

    var rootViewController: UIViewController
    
    struct DataProtectionKeys {
        static let agreementWasShown = "data_protection_agreement_was_shown"
    }
    
    private init() {
        rootViewController = DataProtectionHostingController(rootView: DataProtectionAgreementScreen())
    }
    
    func dismissView() {
        guard Thread.current.isMainThread else {
            return DispatchQueue.main.async { [weak self] in
                self?.rootViewController.dismiss(animated: false)
            }
        }
        
        rootViewController.dismiss(animated: false)
    }
    
    func showView(viewController: UIViewController, dismissBlock: @escaping () -> Void) {
        guard Thread.current.isMainThread else {
            return DispatchQueue.main.async { [weak self] in
                self?.showView(viewController: viewController, dismissBlock: dismissBlock)
            }
        }
        
        if !rootViewController.isBeingPresented {
            rootViewController.modalPresentationStyle = .fullScreen
            viewController.present(rootViewController, animated: false)
        }
    }
    
    func showAgreement(viewController: UIViewController) {
        let wasAgreementShown = UserDefaults.standard.bool(forKey: DataProtectionKeys.agreementWasShown)
        if !wasAgreementShown {
            showView(viewController: viewController) { [weak self] in
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
    
    func onAccountChanged() {
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
