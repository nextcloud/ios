// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum AppInstallState: String {
    case firstInstall
    case updated
    case sameVersion
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

    var installState: AppInstallState {
        get {
            if let rawValue = defaults.string(forKey: installStateKey),
               let state = AppInstallState(rawValue: rawValue) {
                return state
            }
            return .sameVersion
        }
        set {
            defaults.set(newValue.rawValue, forKey: installStateKey)
        }
    }

    var previousVersion: String? {
        return defaults.string(forKey: previousVersionKey)
    }

    func checkAndUpdateInstallState() {
        let savedVersion = defaults.string(forKey: versionKey)

        if savedVersion == nil {
            installState = .firstInstall
        } else if savedVersion != currentVersion {
            defaults.set(savedVersion, forKey: previousVersionKey)
            installState = .updated
        } else {
            installState = .sameVersion
        }

        defaults.set(currentVersion, forKey: versionKey)
    }

    func setCurrentVersion() {
        defaults.set(currentVersion, forKey: versionKey)
    }
}
