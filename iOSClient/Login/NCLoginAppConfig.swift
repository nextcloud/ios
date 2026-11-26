// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Login values from the managed app configuration (MDM).
enum NCLoginAppConfig {
    enum Action: Equatable {
        case createAccount(serverURL: String, user: String, appPassword: String)
        case requestAppPassword(serverURL: String, user: String, password: String)
        case prefill(serverURL: String)
    }

    static func action(managed: [String: Any]?, useAppConfig: Bool, disableMultiaccount: Bool, accountCount: Int) -> Action? {
        guard useAppConfig,
              let managed,
              disableMultiaccount == false || accountCount == 0 else {
            return nil
        }

        let global = NCGlobal.shared

        guard let serverURL = value(in: managed, for: global.configuration_serverUrl, placeholder: nil) else { return nil }

        let user = value(in: managed, for: global.configuration_username, placeholder: "username")
        let password = value(in: managed, for: global.configuration_password, placeholder: "password", trimming: false)
        let appPassword = value(in: managed, for: global.configuration_apppassword, placeholder: "apppassword")

        if let user, let appPassword {
            return .createAccount(serverURL: serverURL, user: user, appPassword: appPassword)
        }

        if let user, let password {
            return .requestAppPassword(serverURL: serverURL, user: user, password: password)
        }

        return .prefill(serverURL: serverURL)
    }

    /// MDM templates ship the key name as a placeholder value. Only passwords keep surrounding whitespace.
    private static func value(in managed: [String: Any], for key: String, placeholder: String?, trimming: Bool = true) -> String? {
        guard var value = managed[key] as? String else { return nil }

        if trimming {
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !value.isEmpty, value.lowercased() != placeholder else { return nil }

        return value
    }
}
