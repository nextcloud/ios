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
    private(set) var activeScene: UIWindowScene?

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

        NotificationCenter.default.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { notification in
            if let scene = notification.object as? UIWindowScene {
                self.activeScene = scene
                nkLog(debug: "Scene did activate: \(scene.session.persistentIdentifier)")
            }
        }
    }

    private func updateActiveScene() {
        let active = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            self.activeScene = active
        }

    func isSceneFocused(_ scene: UIWindowScene?) -> Bool {
        return scene == activeScene
    }
}
