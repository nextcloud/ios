// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Testing
@testable import Nextcloud

@Suite("Login server error classification")
struct NCLoginServerErrorClassifierTests {
    private let httpsURL = URL(string: "https://cloud.example.com:8443/nextcloud/")!

    @Test("Certificate errors ask to trust the certificate", arguments: [
        NSURLErrorServerCertificateUntrusted,
        NSURLErrorServerCertificateHasBadDate,
        NSURLErrorServerCertificateHasUnknownRoot,
        NSURLErrorServerCertificateNotYetValid
    ])
    func untrustedCertificate(errorCode: Int) {
        let resolution = NCLoginServerErrorClassifier.classify(NKError(errorCode: errorCode), serverURL: httpsURL)

        #expect(resolution == .untrustedCertificate(host: "cloud.example.com"))
    }

    @Test("Other https failures offer http with the same port and path", arguments: [NSURLErrorCannotConnectToHost, NSURLErrorSecureConnectionFailed, 404])
    func insecureFallback(errorCode: Int) {
        let resolution = NCLoginServerErrorClassifier.classify(NKError(errorCode: errorCode), serverURL: httpsURL)

        #expect(resolution == .insecureFallback(URL(string: "http://cloud.example.com:8443/nextcloud/")!))
    }

    @Test("No network, an unknown host or a cancellation is shown, as http can't help", arguments: [NSURLErrorNotConnectedToInternet, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed, NSURLErrorCancelled])
    func unreachable(errorCode: Int) {
        #expect(NCLoginServerErrorClassifier.classify(NKError(errorCode: errorCode), serverURL: httpsURL) == .generic)
    }

    @Test("Failures over http are shown")
    func httpFailure() {
        let httpURL = URL(string: "http://cloud.example.com/")!

        #expect(NCLoginServerErrorClassifier.classify(NKError(errorCode: NSURLErrorCannotConnectToHost), serverURL: httpURL) == .generic)
    }
}
