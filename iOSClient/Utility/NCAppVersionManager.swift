// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum AppInstallState {
    case firstInstall
    case updated(from: String)
}

class NCAppVersionManager {
    static let shared = NCAppVersionManager()

    private let versionKey = "lastAppVersion"
    private let previousVersionKey = "previousVersion"
    private let defaults = UserDefaults.standard

    var version: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var previousVersion: String? {
        return defaults.string(forKey: previousVersionKey)
    }

    var currentVersion: String? {
        return defaults.string(forKey: versionKey)
    }

    var installState: AppInstallState {
        if previousVersion == nil {
            return .firstInstall
        } else {
            return .updated(from: previousVersion ?? "0.0.0")
        }
    }

    func checkAndUpdateInstallState() {
        if previousVersion == nil, (currentVersion == version || currentVersion == nil) {
            defaults.set(version, forKey: versionKey)
        } else if currentVersion != version {
            if let currentVersion {
                defaults.set(currentVersion, forKey: previousVersionKey)
            }
            defaults.set(version, forKey: versionKey)
        }
    }

    private func isNewerVersion(_ version: String, than previousVersion: String) -> Bool {
        return version.compare(previousVersion, options: .numeric) == .orderedDescending
    }
}
