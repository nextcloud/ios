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

    private var lastSceneIdentifier: String?
        private var windowObservers: [NSKeyValueObservation] = []

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

        observeSceneFocus()
    }

    private func observeSceneFocus() {
        windowObservers.removeAll()

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                let observer = window.observe(\.isKeyWindow, options: [.new]) { [weak self] window, change in
                    guard let self = self, change.newValue == true else { return }

                    let sceneID = windowScene.session.persistentIdentifier
                    if self.lastSceneIdentifier != sceneID {
                        self.lastSceneIdentifier = sceneID
                        nkLog(debug: "🌟 Scene did focus: \(sceneID)")
                        // NotificationCenter.default.post(name: .sceneDidFocus, object: windowScene)
                    }
                }

                windowObservers.append(observer)
            }
        }
    }
}
