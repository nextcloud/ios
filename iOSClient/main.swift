// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    NSStringFromClass(NCApplication.self),
    NSStringFromClass(AppDelegate.self)
)

final class NCApplication: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)
        UserInteractionMonitor.shared.handle(event: event)
    }
}

final class UserInteractionMonitor {
    static let shared = UserInteractionMonitor()

    private init() {}

    func handle(event: UIEvent) {
        guard event.type == .touches else { return }
        guard let touches = event.allTouches, !touches.isEmpty else { return }

        let allEnded = touches.allSatisfy {
            $0.phase == .ended || $0.phase == .cancelled
        }

        if allEnded {
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUserInteractionMonitor), object: nil, userInfo: nil)
        }
    }
}
