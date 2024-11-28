//
//  DataProtectionAgreementManager.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 27.11.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import UIKit

class DataProtectionAgreementManager {
    private(set) static var shared = DataProtectionAgreementManager()
    
    private(set) var isViewVisible = false
    private var window: UIWindow?
    private var dismissBlock: (() -> Void)?

    var rootViewController: UIViewController
    
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
}
