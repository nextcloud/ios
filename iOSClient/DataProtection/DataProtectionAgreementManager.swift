//
//  DataProtectionAgreementManager.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 27.11.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit
import AppTrackingTransparency

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
        self.rootViewController = DataProtectionHostingController(rootView: DataProtectionAgreementScreen())
    }

    private func instantiateWindow() {
        guard let windowScene = UIApplication.shared.firstWindow?.windowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = UIWindow.Level.alert
        window.rootViewController = self.rootViewController

        self.window = window
    }

    /// Remove the window from the stack making it not visible
    func dismissView() {
        guard (Thread.current.isMainThread == true) else {
            return DispatchQueue.main.sync {
                self.dismissView()
            }
        }
        guard (self.isViewVisible == true) else {
            return
        }

        self.isViewVisible = false
        self.window?.isHidden = true
        self.dismissBlock?()
    }

    /// Make the window visible
    ///
    /// - Parameter dismissBlock: Block to be called when `dismissView` is called
    func showView(dismissBlock: @escaping () -> Void) {
        guard (Thread.current.isMainThread == true) else {
            return DispatchQueue.main.sync {
                self.showView(dismissBlock: dismissBlock)
            }
        }
        guard (self.isViewVisible == false) else {
            return
        }

        self.dismissBlock = dismissBlock

        if (self.window == nil) {
            self.instantiateWindow()
        }

        self.isViewVisible = true

        self.window?.isHidden = false
        self.window?.makeKeyAndVisible()
    }
    
    func checkAgreement() {
        if !UserDefaults.standard.bool(forKey: DataProtectionKeys.accepted) {
            showView { }
        }
    }
    
    func acceptAgreement() {
        self.askForTrackingPermission { [weak self] granted in
            UserDefaults.standard.set(granted, forKey: DataProtectionKeys.accepted)
            self?.dismissView()
        }
    }
    
    func rejectAgreement() {
        UserDefaults.standard.set(false, forKey: DataProtectionKeys.accepted)
        dismissView()
    }
    
    func removeAgreement(){
        UserDefaults.standard.set(false, forKey: DataProtectionKeys.accepted)
    }
    
    private func askForTrackingPermission(completion: ((_ isPermissionGranted: Bool) -> Void)?) {
        
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined:    self.handleNotDetermined(completion: completion)
        case .authorized:        completion?(true)
        case .restricted,
                .denied:            completion?(false)
        @unknown default:        return
        }
    }
    
    private func handleNotDetermined(completion: ((_ isPermissionGranted: Bool) -> Void)?) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                self.askForTrackingPermission(completion: completion)
            }
    }
}
