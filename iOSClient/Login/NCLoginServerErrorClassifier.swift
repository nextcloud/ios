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

    /// The host name does not exist, which plain http can't change.
    private static let unknownHostErrorCodes = [
        NSURLErrorCannotFindHost,
        NSURLErrorDNSLookupFailed
    ]

    static func classify(_ error: NKError, serverURL: URL) -> Resolution {
        if certificateErrorCodes.contains(error.errorCode), let host = serverURL.host {
            return .untrustedCertificate(host: host)
        }

        // Other failed https attempts may fall back to plain http, unless there is no network or no such host.
        guard error.kind != .cancelled,
              error.kind != .offline,
              !unknownHostErrorCodes.contains(error.errorCode),
              serverURL.scheme?.lowercased() == "https",
              var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else {
            return .generic
        }

        components.scheme = "http"

        guard let httpURL = components.url else { return .generic }

        return .insecureFallback(httpURL)
    }
}
