// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

/// Global flag indicating whether the app has ever become active since launch.
var hasBecomeActiveOnce: Bool = false

/// Global flag indicating whether the app is currently in background mode.
var isAppInBackground: Bool = true

/// Singleton responsible for monitoring and managing app state transitions.
///
/// This class observes system notifications related to app lifecycle events and updates global flags accordingly:
///
/// - `hasBecomeActiveOnce`: set to `true` the first time the app enters foreground.
/// - `isAppInBackground`: indicates whether the app is currently running in background.
///
/// Additionally, it logs lifecycle transitions using `nkLog(debug:)`.
final class NCAppStateManager {
    static let shared = NCAppStateManager()

    private init() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
            hasBecomeActiveOnce = true
            isAppInBackground = false

            nkLog(debug: "Application will enter in foreground")
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            nkLog(debug: "Application did become active")
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            isAppInBackground = true

            nkLog(debug: "Application did enter in background")
        }
    }
}
