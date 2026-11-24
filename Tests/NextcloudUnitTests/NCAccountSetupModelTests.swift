// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import NextcloudKitUI
import Testing
@testable import Nextcloud

@MainActor
@Suite("Account setup prompts")
struct NCAccountSetupModelTests {
    private let serverURL = URL(string: "https://cloud.example.com/")!
    private let untrustedCertificate = NKError(errorCode: NSURLErrorServerCertificateUntrusted)

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)

        while condition() == false {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for the condition.")
                return
            }

            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test("Declining the certificate prompt cancels the login")
    func decliningCancels() async throws {
        let model = NCAccountSetupModel(controller: nil)
        let recovery = Task { await model.recover(from: untrustedCertificate, serverURL: serverURL) }

        try await waitUntil { model.isPresentingCertificatePrompt }

        #expect(model.certificateHost == "cloud.example.com")

        model.answer(false)

        guard case .cancel = await recovery.value else {
            Issue.record("The login must be cancelled.")
            return
        }

        #expect(model.isPresentingCertificatePrompt == false)
    }

    @Test("Closing the certificate details asks again")
    func certificateDetailsAskAgain() async throws {
        let model = NCAccountSetupModel(controller: nil)
        let recovery = Task { await model.recover(from: untrustedCertificate, serverURL: serverURL) }

        try await waitUntil { model.isPresentingCertificatePrompt }

        // The alert closes itself when one of its buttons is tapped.
        model.isPresentingCertificatePrompt = false
        model.presentCertificateDetails()
        model.certificateDetailsDidClose()

        #expect(model.isPresentingCertificateDetails == false)
        #expect(model.isPresentingCertificatePrompt)

        model.answer(false)
        _ = await recovery.value

        model.certificateDetailsDidClose()

        #expect(model.isPresentingCertificatePrompt == false)
    }

    @Test("Errors https can't avoid are shown")
    func otherErrorsAreShown() async {
        let model = NCAccountSetupModel(controller: nil)

        guard case .presentError = await model.recover(from: NKError(errorCode: NSURLErrorNotConnectedToInternet), serverURL: serverURL) else {
            Issue.record("The error must be shown.")
            return
        }

        #expect(model.isPresentingCertificatePrompt == false)
        #expect(model.isPresentingInsecureConnectionPrompt == false)
    }
}
