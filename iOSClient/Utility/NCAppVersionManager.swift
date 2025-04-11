// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum AppInstallState: String {
    case firstInstall
    case updatedNewerVersion
    case updated
}

class NCAppVersionManager {
    static let shared = NCAppVersionManager()

    private let versionKey = "lastAppVersion"
    private let previousVersionKey = "previousVersion"
    private let defaults = UserDefaults.standard

    var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var previousVersion: String? {
        return defaults.string(forKey: previousVersionKey)
    }

    var installState: AppInstallState {
        guard let previousVersion else {
            return .firstInstall
        }

        if previousVersion == currentVersion {
            return .firstInstall
        }

        if isNewerVersion(currentVersion, than: previousVersion) {
            return .updatedNewerVersion
        }

        return .updated
    }

    func checkAndUpdateInstallState() {
        if previousVersion == nil || previousVersion == currentVersion {
            defaults.set(currentVersion, forKey: previousVersionKey)
        }

        defaults.set(currentVersion, forKey: versionKey)
    }

    private func isNewerVersion(_ version: String, than previousVersion: String) -> Bool {
        return version.compare(previousVersion, options: .numeric) == .orderedDescending
    }
}
