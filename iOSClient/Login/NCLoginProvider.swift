// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import AuthenticationServices
import UIKit
@preconcurrency import WebKit
import NextcloudKit

protocol NCLoginProviderDelegate: AnyObject {
    ///
    /// Called when the authentication is cancelled or fails.
    ///
    func onBack()
}

///
/// Handles login authentication using ASWebAuthenticationSession with WKWebView fallback for mTLS.
///
class NCLoginProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    var initialURLString = ""
    weak var delegate: NCLoginProviderDelegate?
    var controller: NCMainTabBarController?

    /// The presenting view controller for the authentication session.
    weak var presentingViewController: UIViewController?

    /// The active authentication session.
    private var authSession: ASWebAuthenticationSession?

    /// Fallback web view controller for mTLS/certificate handling.
    private var webViewFallbackVC: NCLoginProviderWebViewFallback?

    ///
    /// A polling loop active in the background to check for the current status of the login flow.
    ///
    var pollingTask: Task<Void, any Error>?

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return presentingViewController?.view.window ?? UIApplication.shared.mainAppWindow ?? ASPresentationAnchor()
    }

    // MARK: - Authentication

    ///
    /// Start the authentication flow using ASWebAuthenticationSession.
    /// Falls back to WKWebView if authentication fails (e.g., certificate issues).
    ///
    func startAuthentication() {
        guard let url = URL(string: initialURLString) else {
            Task {
                await showErrorBanner(controller: self.controller, text: "_login_url_error_", errorCode: 0)
            }
            return
        }

        // Use the app's custom URL scheme to handle login callbacks (e.g., nc://login/...)
        let callbackScheme = NCBrandOptions.shared.webLoginAutenticationProtocol.replacingOccurrences(of: "://", with: "")

        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
            guard let self else { return }

            if let error = error {
                if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
                    // Only treat as user cancellation if polling hasn't succeeded yet
                    if self.pollingTask != nil {
                        Task { @MainActor in
                            self.delegate?.onBack()
                        }
                    }
                } else {
                    // Fall back to WKWebView for other errors (e.g., certificate issues)
                    Task { @MainActor in
                        self.fallbackToWebView(url: url)
                    }
                }
                return
            }

            // Handle login callback URL (e.g., nc://login/server:...&user:...&password:...)
            if let callbackURL {
                self.handleLoginCallback(url: callbackURL)
            }
        }

        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = true

        if authSession?.start() != true {
            // Fall back to WKWebView if ASWebAuthenticationSession fails to start
            fallbackToWebView(url: url)
        }
    }

    ///
    /// Cancel the authentication session and clean up.
    ///
    func cancel() {
        authSession?.cancel()
        authSession = nil

        webViewFallbackVC?.dismiss(animated: true)
        webViewFallbackVC = nil

        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - WKWebView Fallback

    ///
    /// Present WKWebView as a fallback for mTLS/certificate handling.
    ///
    private func fallbackToWebView(url: URL) {
        authSession?.cancel()
        authSession = nil

        guard let presentingVC = presentingViewController else { return }

        let fallbackVC = NCLoginProviderWebViewFallback()
        fallbackVC.initialURL = url
        fallbackVC.initialURLString = initialURLString
        fallbackVC.controller = controller
        fallbackVC.loginProvider = self

        let navController = UINavigationController(rootViewController: fallbackVC)
        navController.modalPresentationStyle = .fullScreen

        presentingVC.present(navController, animated: true)
        self.webViewFallbackVC = fallbackVC
    }

    ///
    /// Handle the login callback URL from the authentication session.
    ///
    func handleLoginCallback(url: URL) {
        let urlString = url.absoluteString.lowercased()

        // Check if this is a login callback
        guard urlString.hasPrefix(NCBrandOptions.shared.webLoginAutenticationProtocol) && urlString.contains("login") else {
            return
        }

        var server: String = ""
        var user: String = ""
        var password: String = ""
        let keyValue = url.path.components(separatedBy: "&")

        for value in keyValue {
            if value.contains("server:") { server = value }
            if value.contains("user:") { user = value }
            if value.contains("password:") { password = value }
        }

        if !server.isEmpty, !user.isEmpty, !password.isEmpty {
            let server = server.replacingOccurrences(of: "/server:", with: "")
            let username = user.replacingOccurrences(of: "user:", with: "").replacingOccurrences(of: "+", with: " ")
            let password = password.replacingOccurrences(of: "password:", with: "")

            // Stop polling since we got credentials from callback
            pollingTask?.cancel()
            pollingTask = nil

            // Dismiss fallback web view if present
            webViewFallbackVC?.dismiss(animated: true)
            webViewFallbackVC = nil

            if self.controller == nil {
                self.controller = UIApplication.shared.mainAppWindow?.rootViewController as? NCMainTabBarController
            }

            Task { @MainActor in
                guard let viewController = self.presentingViewController else { return }
                await NCAccount().createAccount(viewController: viewController, urlBase: server, user: username, password: password, controller: self.controller)
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
    func handleGrant(urlBase: String, loginName: String, appPassword: String) async {
        nkLog(debug: "Handling login grant values for \(loginName) on \(urlBase)")

        // Cancel the auth session since login was successful
        authSession?.cancel()
        authSession = nil

        // Dismiss fallback web view if present
        webViewFallbackVC?.dismiss(animated: true)
        webViewFallbackVC = nil

        if controller == nil {
            nkLog(debug: "View controller is still undefined, will resolve root view controller of first window.")
            controller = UIApplication.shared.mainAppWindow?.rootViewController as? NCMainTabBarController
        }

        guard let viewController = presentingViewController else {
            nkLog(error: "No presenting view controller available for account creation.")
            return
        }

        await NCAccount().createAccount(viewController: viewController, urlBase: urlBase, user: loginName, password: appPassword, controller: controller)
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

// MARK: - WKWebView Fallback View Controller

///
/// Fallback view controller using WKWebView for mTLS/certificate handling.
///
class NCLoginProviderWebViewFallback: UIViewController, WKNavigationDelegate {
    var initialURL: URL?
    var initialURLString = ""
    var controller: NCMainTabBarController?
    weak var loginProvider: NCLoginProvider?

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = NCBrandColor.shared.customer

        // Navigation bar
        let closeButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeTapped))
        closeButton.tintColor = .white
        navigationItem.leftBarButtonItem = closeButton

        if let host = initialURL?.host {
            title = host
        }

        // Web view setup
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = userAgent
        webView.navigationDelegate = self
        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if let url = initialURL {
            loadWebPage(url: url)
        }
    }

    @objc private func closeTapped() {
        loginProvider?.delegate?.onBack()
        dismiss(animated: true)
    }

    private func loadWebPage(url: URL) {
        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)

        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        webView.load(request)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard let currentWebViewURL = webView.url else { return }

        let currentWebViewURLString = currentWebViewURL.absoluteString.lowercased()

        // Prevent HTTP redirects
        if initialURLString.lowercased().hasPrefix("https://") && currentWebViewURLString.hasPrefix("http://") {
            let alertController = UIAlertController(
                title: NSLocalizedString("_error_", comment: ""),
                message: NSLocalizedString("_prevent_http_redirection_", comment: ""),
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { _ in
                self.dismiss(animated: true)
            })
            present(alertController, animated: true)
            return
        }

        // Login via provider
        if currentWebViewURLString.hasPrefix(NCBrandOptions.shared.webLoginAutenticationProtocol) && currentWebViewURLString.contains("login") {
            loginProvider?.handleLoginCallback(url: currentWebViewURL)
        }
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        DispatchQueue.global().async {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.useCredential, nil)
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        NCActivityIndicator.shared.startActivity(backgroundView: view, style: .medium, blurEffect: false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NCActivityIndicator.shared.stop()
    }
}
