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
    var firstWindow: UIWindow? {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let firstActiveScene = windowScenes.first
        let keyWindow = firstActiveScene?.keyWindow
        return keyWindow
    }
    func allSceneSessionDestructionExceptFirst() {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let firstActiveScene = windowScenes.first
        let options = UIWindowSceneDestructionRequestOptions()
        options.windowDismissalAnimation = .standard
        for windowScene in windowScenes {
            if windowScene == firstActiveScene { continue }
            requestSceneSessionDestruction(windowScene.session, options: options, errorHandler: nil)
        }
    }
}
