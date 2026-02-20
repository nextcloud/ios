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
    /// Called when the back button is tapped in the login provider view.
    ///
    func onBack()
}

///
/// Handles login authentication.
/// Uses ASWebAuthenticationSession for passkey support, with WKWebView fallback for certificate handling.
///
class NCLoginProvider: UIViewController, ASWebAuthenticationPresentationContextProviding {
    var titleView: String = ""
    var initialURLString = ""
    var uiColor: UIColor = .white
    weak var delegate: NCLoginProviderDelegate?
    var controller: NCMainTabBarController?

    /// The active authentication session.
    private var authSession: ASWebAuthenticationSession?

    /// Fallback web view for certificate handling.
    private var webView: WKWebView?

    /// Whether we're using the WKWebView fallback.
    private var isUsingWebViewFallback = false

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

        NCActivityIndicator.shared.stop()

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
    /// Falls back to WKWebView if authentication fails (e.g., for importing mTLS cert).
    ///
    private func startAuthentication(url: URL) {
        // Use custom URL scheme to handle login callbacks (e.g., nc://login/...)
        let callbackScheme = NCBrandOptions.shared.webLoginAutenticationProtocol.replacingOccurrences(of: "://", with: "")

        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
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
                    // Fall back to WKWebView for other errors (e.g., certificate issues)
                    nkLog(debug: "ASWebAuthenticationSession failed with error: \(nsError.localizedDescription). Falling back to WKWebView.")
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
            nkLog(debug: "ASWebAuthenticationSession failed to start. Falling back to WKWebView.")
            fallbackToWebView(url: url)
        }
    }

    // MARK: - WKWebView Fallback

    ///
    /// Set up and display WKWebView as a fallback for certificate handling.
    ///
    private func fallbackToWebView(url: URL) {
        guard !isUsingWebViewFallback else { return }
        isUsingWebViewFallback = true

        authSession?.cancel()
        authSession = nil

        nkLog(debug: "Setting up WKWebView fallback for URL: \(url.absoluteString)")

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
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

        self.webView = webView
        loadWebPage(url: url)
    }

    ///
    /// Load a web page in the fallback WKWebView.
    ///
    private func loadWebPage(url: URL) {
        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)

        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        webView?.load(request)
    }

    ///
    /// Handle the login callback URL from the authentication session.
    ///
    private func handleLoginCallback(url: URL) {
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

            if self.controller == nil {
                self.controller = UIApplication.shared.mainAppWindow?.rootViewController as? NCMainTabBarController
            }

            Task { @MainActor in
                await NCAccount().createAccount(viewController: self, urlBase: server, user: username, password: password, controller: self.controller)
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

// MARK: - WKNavigationDelegate

extension NCLoginProvider: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard let currentWebViewURL = webView.url else {
            return
        }

        let currentWebViewURLString: String = currentWebViewURL.absoluteString.lowercased()

        // Prevent HTTP redirects.
        if initialURLString.lowercased().hasPrefix("https://") && currentWebViewURLString.hasPrefix("http://") {
            let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_prevent_http_redirection_", comment: ""), preferredStyle: .alert)

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
                _ = self.navigationController?.popViewController(animated: true)
            }))

            self.present(alertController, animated: true)
            return
        }

        // Login via provider.
        if currentWebViewURLString.hasPrefix(NCBrandOptions.shared.webLoginAutenticationProtocol) && currentWebViewURLString.contains("login") {
            handleLoginCallback(url: currentWebViewURL)
        }
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        DispatchQueue.global().async {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        NCActivityIndicator.shared.startActivity(backgroundView: self.view, style: .medium, blurEffect: false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NCActivityIndicator.shared.stop()
    }
}

