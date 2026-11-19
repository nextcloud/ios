// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import AuthenticationServices
import NextcloudKit
import NextcloudKitUI
import UIKit

/// Signs up with a provider in the browser, which redirects to the login callback URL with the new account's credentials.
@MainActor
final class NCProviderSignUp: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let coordinator: NCLoginCoordinator
    private var session: ASWebAuthenticationSession?

    init(coordinator: NCLoginCoordinator) {
        self.coordinator = coordinator
    }

    func start(url: URL) {
        let scheme = NCBrandOptions.shared.webLoginAutenticationProtocol.replacingOccurrences(of: "://", with: "")

        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callbackURL, error in
            Task { @MainActor in
                await self?.finish(callbackURL: callbackURL, error: error, scheme: scheme)
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        self.session = session

        session.start()
    }

    private func finish(callbackURL: URL?, error: Error?, scheme: String) async {
        session = nil

        let windowScene = coordinator.presenter?.view.window?.windowScene

        if let error {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                await showErrorBanner(windowScene: windowScene, error: NKError(error: error))
            }

            return
        }

        guard let callbackURL else { return }

        do {
            let credentials = try LoginCallbackParser.parse(callbackURL, scheme: scheme)

            try await coordinator.addAccount(host: credentials.host, user: credentials.user, password: credentials.password)
        } catch let error as NKError {
            await showErrorBanner(windowScene: windowScene, error: error)
        } catch {
            await showErrorBanner(windowScene: windowScene, text: error.localizedDescription)
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            coordinator.presenter?.view.window ?? UIApplication.shared.mainAppWindow ?? ASPresentationAnchor()
        }
    }
}
