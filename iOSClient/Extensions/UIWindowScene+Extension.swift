// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

extension UIWindowScene {
    @MainActor
    var resolvedWindow: UIWindow? {
        if let window = resolvedWindow(in: [self]) {
            return window
        }

#if !EXTENSION
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        if let window = resolvedWindow(
            in: scenes.filter { $0.activationState == .foregroundActive }
        ) {
            return window
        }

        if let window = resolvedWindow(
            in: scenes.filter { $0.activationState == .foregroundInactive }
        ) {
            return window
        }

        return resolvedWindow(in: scenes)
#else
        return nil
#endif
    }

    @MainActor
    private func resolvedWindow(in scenes: [UIWindowScene]) -> UIWindow? {
        let windows = scenes.flatMap { $0.windows }

        return windows.first(where: \.isKeyWindow) ??
            windows.first(where: { !$0.isHidden && $0.alpha > 0 }) ??
            windows.first(where: { !$0.isHidden }) ??
            windows.first
    }
}
