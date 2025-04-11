// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum AppInstallState: String {
    case firstInstall
    case updated
}

class NCAppVersionManager {
    static let shared = NCAppVersionManager()

    private let versionKey = "lastAppVersion"
    private let installStateKey = "appInstallState"
    private let previousVersionKey = "previousVersion"
    private let defaults = UserDefaults.standard

    var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var previousVersion: String? {
        return defaults.string(forKey: previousVersionKey)
    }

    var installState: AppInstallState {
        get {
            if let rawValue = defaults.string(forKey: installStateKey),
               let state = AppInstallState(rawValue: rawValue) {
                return state
            }
            return .firstInstall
        }
        set {
            defaults.set(newValue.rawValue, forKey: installStateKey)
        }
    }

    func checkAndUpdateInstallState() {
        if previousVersion == nil {
            installState = .firstInstall
        } else if isNewerVersion(currentVersion, than: previousVersion!) {
            installState = .updated
            defaults.set(currentVersion, forKey: previousVersionKey)
        } else {
            installState = .updated
        }

        defaults.set(currentVersion, forKey: versionKey)
    }

    private func isNewerVersion(_ version: String, than previousVersion: String) -> Bool {
        return version.compare(previousVersion, options: .numeric) == .orderedDescending
    }
}
