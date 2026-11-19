// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

/// Decides how the login reacts to a failed server status check.
enum NCLoginServerErrorClassifier {
    enum Resolution: Equatable {
        case untrustedCertificate(host: String)
        case insecureFallback(URL)
        case generic
    }

    private static let certificateErrorCodes = [
        NSURLErrorServerCertificateUntrusted,
        NSURLErrorServerCertificateHasBadDate,
        NSURLErrorServerCertificateHasUnknownRoot,
        NSURLErrorServerCertificateNotYetValid
    ]

    static func classify(_ error: NKError, serverURL: URL) -> Resolution {
        if certificateErrorCodes.contains(error.errorCode), let host = serverURL.host {
            return .untrustedCertificate(host: host)
        }

        // Any other failed https attempt may fall back to plain http.
        guard error.kind != .cancelled,
              serverURL.scheme?.lowercased() == "https",
              var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else {
            return .generic
        }

        components.scheme = "http"

        guard let httpURL = components.url else { return .generic }

        return .insecureFallback(httpURL)
    }
}
