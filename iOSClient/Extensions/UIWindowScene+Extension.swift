// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

extension UIWindowScene {
    var resolvedWindow: UIWindow? {
        windows.first(where: \.isKeyWindow) ??
        windows.first(where: { !$0.isHidden && $0.alpha > 0 && $0.windowScene === self }) ??
        windows.first(where: { !$0.isHidden && $0.windowScene === self }) ??
        windows.first
    }
}
