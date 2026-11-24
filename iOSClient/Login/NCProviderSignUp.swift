// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import NextcloudKitUI
import UIKit
@preconcurrency import WebKit

/// Signs up with a provider and adds the new account from the login callback URL the sign-up ends on.
///
/// A web view instead of a browser session, because the sign-up page only hands over credentials to page loads with the OCS API header.
final class NCProviderSignUp: UIViewController, WKNavigationDelegate {
    private static let apiHeader = "OCS-APIRequest"

    private let url: URL
    private let coordinator: NCLoginCoordinator
    private let scheme = NCBrandOptions.shared.webLoginAutenticationProtocol.replacingOccurrences(of: "://", with: "").lowercased()
    private let webView: WKWebView
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var loadingObservation: NSKeyValueObservation?
    private var reissuedURLs: Set<URL> = []
    private var requestedURL: URL?
    private var hasAppeared = false
    private var hasReloadedAfterTermination = false
    private var isFinished = false

    init(url: URL, coordinator: NCLoginCoordinator) {
        self.url = url
        self.coordinator = coordinator

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = url.host
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        webView.frame = view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.customUserAgent = userAgent
        webView.navigationDelegate = self
        view.addSubview(webView)

        activityIndicator.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        activityIndicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        view.addSubview(activityIndicator)

        loadingObservation = webView.observe(\.isLoading) { [weak self] webView, _ in
            if webView.isLoading {
                self?.activityIndicator.startAnimating()
            } else {
                self?.activityIndicator.stopAnimating()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Not while the screen slides in, which would drop the alert of a load that fails right away.
        guard !hasAppeared else { return }

        hasAppeared = true
        webView.load(Self.apiRequest(for: Self.uncachedURL(url)))
    }

    /// nextcloud.com serves its sign-up page from a cache that ignores the header, unless the address has a query.
    private static func uncachedURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }

        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "ocsapi", value: "1")]

        return components.url ?? url
    }

    /// Fails after 20 seconds without data instead of a minute, so an unreachable server is reported soon.
    private static func apiRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("true", forHTTPHeaderField: apiHeader)

        return request
    }

    /// The page that failed, or the sign-up page when none has been requested yet.
    private func reload() {
        reissuedURLs.removeAll()
        webView.load(Self.apiRequest(for: requestedURL ?? Self.uncachedURL(url)))
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request

        guard let url = request.url else {
            decisionHandler(.cancel)
            return
        }

        if url.scheme?.lowercased() == scheme {
            decisionHandler(.cancel)
            finish(callbackURL: url)
            return
        }

        if navigationAction.targetFrame?.isMainFrame == true, request.httpMethod == "GET" {
            // Redirects and links lose the header, so such page loads are started again with it, once per page.
            if request.value(forHTTPHeaderField: Self.apiHeader) == nil, reissuedURLs.insert(url).inserted {
                decisionHandler(.cancel)
                webView.load(Self.apiRequest(for: url))
                return
            }

            requestedURL = url
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.isForMainFrame else {
            decisionHandler(.allow)
            return
        }

        // Error pages and empty responses would otherwise load as if nothing went wrong.
        if let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
            decisionHandler(.cancel)
            showLoadError(Self.error(forStatusCode: response.statusCode), in: webView)
            return
        }

        if !navigationResponse.canShowMIMEType || navigationResponse.response.expectedContentLength == 0 {
            decisionHandler(.cancel)
            showLoadError(NKError.invalidResponseError, in: webView)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard let url = webView.url, url.scheme?.lowercased() == scheme else { return }

        finish(callbackURL: url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        reissuedURLs.removeAll()
        hasReloadedAfterTermination = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showLoadError(error, in: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadError(error, in: webView)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // WebKit stops reloading by itself once this is implemented, so reload once and report a repeat.
        guard hasReloadedAfterTermination else {
            hasReloadedAfterTermination = true
            reload()
            return
        }

        showLoadError(NKError(errorCode: WKError.Code.webContentProcessTerminated.rawValue, errorDescription: "Web content process terminated", kind: .unknown), in: webView)
    }

    // MARK: - Errors

    /// Picks a kind whose NextcloudKit text fits a web page, unlike the file-related ones for 403 or 404.
    private static func error(forStatusCode statusCode: Int) -> NKError {
        let kind: NKError.Kind

        switch statusCode {
        case 408, 504:
            kind = .timeout
        case 429:
            kind = .rateLimited
        case 503:
            kind = .unavailable
        case 500, 501, 505...599:
            kind = .serverError
        default:
            kind = .serverUnreachable
        }

        return NKError(errorCode: statusCode, errorDescription: HTTPURLResponse.localizedString(forStatusCode: statusCode), kind: kind)
    }

    private func showLoadError(_ error: Error, in webView: WKWebView) {
        // Page loads this class replaces end as interrupted or cancelled.
        let nsError = error as NSError
        let isInterrupted = nsError.domain == "WebKitErrorDomain" && nsError.code == 102
        let nkError = error as? NKError ?? NKError(error: error)

        guard !isFinished, !isInterrupted, presentedViewController == nil,
              let message = nkError.userFriendlyMessage() else { return }

        let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: NSLocalizedString("_close_", comment: ""), style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("_retry_", comment: ""), style: .default) { [weak self] _ in
            self?.reload()
        })

        present(alert, animated: true)
    }

    // MARK: - Account

    private func finish(callbackURL: URL) {
        guard !isFinished else { return }

        isFinished = true

        // The presenter is off screen behind this full screen page, so its scene would be nil.
        let windowScene = view.window?.windowScene

        Task {
            await withCheckedContinuation { continuation in
                dismiss(animated: true) {
                    continuation.resume()
                }
            }

            do {
                let credentials = try LoginCallbackParser.parse(callbackURL, scheme: scheme)

                try await coordinator.addAccount(host: credentials.host, user: credentials.user, password: credentials.password)
            } catch let error as NKError {
                await showErrorBanner(windowScene: windowScene, error: error, context: .login)
            } catch {
                await showErrorBanner(windowScene: windowScene, title: NCErrorContext.login.failureTitle ?? "_error_", text: error.localizedDescription)
            }
        }
    }
}
