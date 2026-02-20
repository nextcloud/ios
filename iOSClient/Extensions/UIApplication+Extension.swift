//
//  UIApplication+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

extension UIApplication {
    /// Returns the main application window, excluding overlay windows
    /// like LucidBanner, keyboard or debug windows.
    var mainAppWindow: UIWindow? {
        let activeScenes = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let allWindows = activeScenes.flatMap { $0.windows }

        return allWindows.first { window in
            guard window.isHidden == false else { return false }

            // Filter by normal level to ignore overlays with higher levels
            guard window.windowLevel == .normal else { return false }

            // Optionally exclude LucidBanner windows by rootViewController type name
            if let root = window.rootViewController {
                let typeName = String(describing: type(of: root))
                if typeName.contains("LucidBanner") {
                    return false
                }
            }

            return true
        }
    }

    func allSceneSessionDestructionExceptFirst() {
        let windowScenes = connectedScenes.compactMap { $0 as? UIWindowScene }

        // Keep the first foregroundActive scene if possible,
        // otherwise fall back to the very first one.
        let primaryScene = windowScenes
            .first { $0.activationState == .foregroundActive } ?? windowScenes.first

        let options = UIWindowSceneDestructionRequestOptions()
        options.windowDismissalAnimation = .standard

        for windowScene in windowScenes {
            if windowScene == primaryScene { continue }
            requestSceneSessionDestruction(windowScene.session, options: options, errorHandler: nil)
        }
    }

    /// Returns all foreground-active window scenes.
    var foregroundActiveScenes: [UIWindowScene] {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
    }
}
