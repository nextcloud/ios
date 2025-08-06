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

    private var lastSceneID: String?
    private var isRunning = false

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

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.startMonitoring()
        }
    }

    @MainActor
    func startMonitoring() async {
            while true {
                if let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                   let _ = scene.keyWindow {

                    let id = scene.session.persistentIdentifier
                    if id != lastSceneID {
                        lastSceneID = id
                        print("\(id)")
                        /*
                        await MainActor.run {
                            NotificationCenter.default.post(name: .sceneDidFocus, object: scene)
                        }
                        */
                    }
                }

                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
        }
}
