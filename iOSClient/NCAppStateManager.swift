// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

// Global flag indicating whether the app has ever become active since launch.
var hasBecomeActiveOnce: Bool = false

// Global flag used to control Realm write/read operations during app suspension.
var isAppSuspending: Bool = false

// Global flag indicating whether the app is currently in background mode.
var isAppInBackground: Bool = true

// Global flag indicating whether the app is in maintenanceMode.
var maintenanceMode: Bool = false

/// Singleton responsible for monitoring and managing app state transitions.
///
/// This class observes system notifications related to app lifecycle events and updates global flags accordingly:
///
/// - `hasBecomeActiveOnce`: set to `true` the first time the app enters foreground.
/// - `isAppSuspending`: set to `true` when the app enters background (useful to safely close Realm writes).
/// - `isAppInBackground`: indicates whether the app is currently running in background.
///
/// Additionally, it logs lifecycle transitions using `nkLog(debug:)`.
final class NCAppStateManager {
    static let shared = NCAppStateManager()

    private init() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
            hasBecomeActiveOnce = true
            isAppSuspending = false
            isAppInBackground = false

            nkLog(debug: "Application will enter in foreground")
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            nkLog(debug: "Application did become active")
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            isAppSuspending = true
            isAppInBackground = true

            nkLog(debug: "Application did enter in background")
        }
    }

    /// Waits for `maintenanceMode` to become false with a bounded timeout.
    /// Returns `true` if maintenance is OFF within the timeout, otherwise `false`.
    /// Total max wait 10 sec.
    func waitForMaintenanceOffAsync(maxWaitSeconds: UInt64 = 10, pollIntervalMilliseconds: UInt64 = 250) async -> Bool {
        // Fast-path: immediately proceed if maintenance is already OFF
        if !maintenanceMode {
            return true
        }

        var waitedNs: UInt64 = 0
        let maxWaitNs = maxWaitSeconds * 1_000_000_000
        let pollNs = pollIntervalMilliseconds * 1_000_000

        while waitedNs < maxWaitNs {
            if Task.isCancelled {
                return false
            } // respect cancellation
            try? await Task.sleep(nanoseconds: pollNs)
            waitedNs += pollNs
            print("[Polling Maintenance state]")
            if !maintenanceMode {
                return true
            }
        }
        return false
    }
}
