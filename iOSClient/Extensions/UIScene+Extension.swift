// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI

// 1) Type-erasure: vale per QUALSIASI UIHostingController<Content>
protocol AnyHostingController {
    var anyRootView: Any { get }
}
extension UIHostingController: AnyHostingController {
    var anyRootView: Any { rootView }
}

// 2) Utility
@MainActor
extension UIScene {
    /// Returns the root controller if it is a UIHostingController (type-erased).
    func rootHostingController() -> (UIViewController & AnyHostingController)? {
        guard let windowScene = self as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
              let rootVC = keyWindow.rootViewController else {
            return nil
        }
        return rootVC as? (UIViewController & AnyHostingController)
    }
}
