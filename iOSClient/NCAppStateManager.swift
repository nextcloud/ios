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

    private var gestureRecognizers: [String: UIGestureRecognizer] = [:]
    private var gestureDelegates: [String: SceneTapInterceptor] = [:]

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
                self.installSceneFocusTapMonitor(scene: scene)
            }
        }
    }

    private func installSceneFocusTapMonitor(scene: UIWindowScene) {
            guard let window = scene.windows.first else { return }

            let sceneID = scene.session.persistentIdentifier
            if gestureRecognizers[sceneID] != nil { return } // già installato

            let interceptor = SceneTapInterceptor()
            let tapRecognizer = UITapGestureRecognizer(target: Self.self, action: #selector(handleSceneTap(_:)))
            tapRecognizer.name = "SceneFocusTapMonitor"
            tapRecognizer.cancelsTouchesInView = false
            tapRecognizer.delegate = interceptor

            window.addGestureRecognizer(tapRecognizer)

            // 🔒 Manteniamo vivi i riferimenti
            gestureRecognizers[sceneID] = tapRecognizer
            gestureDelegates[sceneID] = interceptor
        }

        @objc func handleSceneTap(_ recognizer: UITapGestureRecognizer) {
            guard let window = recognizer.view as? UIWindow,
                  let scene = window.windowScene else { return }

            nkLog(debug: "🟢 Scene tapped / focused: \(scene.session.persistentIdentifier)")
            NotificationCenter.default.post(name: .sceneDidReceiveUserTap, object: scene)
        }
}

/// Allows tap recognizer to work across all UI.
private class SceneTapInterceptor: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return true
    }
}


extension Notification.Name {
    static let sceneDidReceiveUserTap = Notification.Name("sceneDidReceiveUserTap")
}

