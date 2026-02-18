// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import AuthenticationServices
import UIKit
import NextcloudKit

protocol NCLoginProviderDelegate: AnyObject {
    ///
    /// Called when the back button is tapped in the login provider view.
    ///
    func onBack()
}

///
/// View controller that handles login authentication using ASWebAuthenticationSession.
///
class NCLoginProvider: UIViewController, ASWebAuthenticationPresentationContextProviding {
    var titleView: String = ""
    var initialURLString = ""
    var uiColor: UIColor = .white
    weak var delegate: NCLoginProviderDelegate?
    var controller: NCMainTabBarController?

    /// The active authentication session.
    private var authSession: ASWebAuthenticationSession?

    ///
    /// A polling loop active in the background to check for the current status of the login flow.
    ///
    var pollingTask: Task<Void, any Error>?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        nkLog(debug: "Login provider view did load.")

        view.backgroundColor = NCBrandColor.shared.customer

        let navigationItemBack = UIBarButtonItem(image: UIImage(systemName: "arrow.left"), style: .plain, target: self, action: #selector(goBack(_:)))
        navigationItemBack.tintColor = uiColor
        navigationItem.leftBarButtonItem = navigationItemBack
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nkLog(debug: "Login provider appeared.")

        guard let url = URL(string: initialURLString) else {
            Task {
                await showErrorBanner(controller: self.controller, text: "_login_url_error_", errorCode: 0)
            }
            return
        }

        if let host = url.host {
            titleView = host

            if let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount(), NCPreferences().getPassword(account: activeTableAccount.account).isEmpty {
                titleView = NSLocalizedString("_user_", comment: "") + " " + activeTableAccount.userId + " " + NSLocalizedString("_in_", comment: "") + " " + host
            }
        }

        self.title = titleView
        startAuthentication(url: url)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        nkLog(debug: "Login provider view did disappear.")

        authSession?.cancel()
        authSession = nil

        guard pollingTask != nil else {
            return
        }

        nkLog(debug: "Cancelling existing polling task because view did disappear...")
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window ?? ASPresentationAnchor()
    }

    // MARK: - Navigation

    ///
    /// Dismiss the login view from the hierarchy.
    ///
    @objc func goBack(_ sender: Any?) {
        delegate?.onBack()

        if isModal {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Authentication

    ///
    /// Start the authentication flow using ASWebAuthenticationSession.
    ///
    private func startAuthentication(url: URL) {
        // Use nil callback scheme - we rely on polling to detect successful login.
        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: nil) { [weak self] _, error in
            guard let self else { return }

            if let error = error {
                let nsError = error as NSError

                if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
                    // Only treat as user cancellation if polling hasn't succeeded yet
                    if self.pollingTask != nil {
                        Task { @MainActor in
                            self.goBack(nil)
                        }
                    }
                } else {
                    Task { @MainActor in
                        await showErrorBanner(controller: self.controller, text: "_login_error_", errorCode: nsError.code)
                        self.goBack(nil)
                    }
                }
                return
            }
        }

        authSession?.presentationContextProvider = self
        // Use non-ephemeral session to access system-trusted certificates
        authSession?.prefersEphemeralWebBrowserSession = false

        if authSession?.start() != true {
            Task { @MainActor in
                await showErrorBanner(controller: self.controller, text: "_login_error_", errorCode: 0)
                self.goBack(nil)
            }
        }
    }

    // MARK: - Polling

    ///
    /// Start checking the status of the login flow in the background periodically.
    ///
    func startPolling(loginFlowV2Token: String, loginFlowV2Endpoint: String, loginFlowV2Login: String) {
        nkLog(start: "Starting polling at \(loginFlowV2Endpoint) with token \(loginFlowV2Token)")
        pollingTask = createPollingTask(token: loginFlowV2Token, endpoint: loginFlowV2Endpoint)
        nkLog(debug: "Polling task created.")
    }

    ///
    /// Fetch the server response and process it.
    ///
    private func poll(token: String, endpoint: String, options: NKRequestOptions) async -> (urlBase: String, loginName: String, appPassword: String)? {
        await withCheckedContinuation { continuation in
            NextcloudKit.shared.getLoginFlowV2Poll(token: token, endpoint: endpoint, options: options) { server, loginName, appPassword, _, error in

                guard error == .success else {
                    nkLog(error: "Login poll result for token \"\(token)\" is not successful!")
                    continuation.resume(returning: nil)
                    return
                }

                guard let urlBase = server else {
                    nkLog(error: "Login poll response field for server for token \"\(token)\" is nil!")
                    continuation.resume(returning: nil)
                    return
                }

                guard let user = loginName else {
                    nkLog(error: "Login poll response field for user name for token \"\(token)\" is nil!")
                    continuation.resume(returning: nil)
                    return
                }

                guard let appPassword = appPassword else {
                    nkLog(error: "Login poll response field for app password for token \"\(token)\" is nil!")
                    continuation.resume(returning: nil)
                    return
                }

                nkLog(debug: "Returning login poll response for \"\(user)\" on \"\(urlBase)\" for token \"\(token)\".")
                continuation.resume(returning: (urlBase, user, appPassword))
            }
        }
    }

    ///
    /// Handle the values acquired by polling successfully.
    ///
    private func handleGrant(urlBase: String, loginName: String, appPassword: String) async {
        nkLog(debug: "Handling login grant values for \(loginName) on \(urlBase)")

        // Cancel the auth session since login was successful
        authSession?.cancel()
        authSession = nil

        if controller == nil {
            nkLog(debug: "View controller is still undefined, will resolve root view controller of first window.")
            controller = UIApplication.shared.mainAppWindow?.rootViewController as? NCMainTabBarController
        }

        await NCAccount().createAccount(viewController: self, urlBase: urlBase, user: loginName, password: appPassword, controller: controller)
        nkLog(debug: "Account creation for \(loginName) on \(urlBase) completed based on login grant values.")
    }

    ///
    /// Set up the `Task` which frequently checks the server.
    ///
    private func createPollingTask(token: String, endpoint: String) -> Task<Void, any Error> {
        let options = NKRequestOptions(customUserAgent: userAgent)
        var grantValues: (urlBase: String, loginName: String, appPassword: String)?

        return Task { @MainActor in
            repeat {
                try Task.checkCancellation()

                grantValues = await poll(token: token, endpoint: endpoint, options: options)
                try await Task.sleep(for: .seconds(1))
            } while grantValues == nil

            guard let grantValues else {
                return
            }

            // Clear the polling task before handling grant to prevent cancellation callback
            self.pollingTask = nil

            await handleGrant(urlBase: grantValues.urlBase, loginName: grantValues.loginName, appPassword: grantValues.appPassword)
            nkLog(debug: "Polling task completed.")
        }
    }
}

