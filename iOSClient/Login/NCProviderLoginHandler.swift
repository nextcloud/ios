// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct NCProviderLoginHandler {
    static func handle(callbackURL: URL) -> (urlBase: String, user: String, password: String)? {
        let callbackURLString = callbackURL.absoluteString.lowercased()
        let protocolPrefix = NCBrandOptions.shared.webLoginAutenticationProtocol.lowercased()

        guard callbackURLString.hasPrefix(protocolPrefix), callbackURLString.contains("login") else {
            return nil
        }

        var server: String = ""
        var user: String = ""
        var password: String = ""
        let keyValue = callbackURL.path.components(separatedBy: "&")

        for value in keyValue {
            if value.contains("server:") { server = value }
            if value.contains("user:") { user = value }
            if value.contains("password:") { password = value }
        }

        guard !server.isEmpty, !user.isEmpty, !password.isEmpty else {
            return nil
        }

        let serverClean = server.replacingOccurrences(of: "/server:", with: "")
        let username = user.replacingOccurrences(of: "user:", with: "").replacingOccurrences(of: "+", with: " ")
        let passwordClean = password.replacingOccurrences(of: "password:", with: "")

        return (serverClean, username, passwordClean)
    }
}
