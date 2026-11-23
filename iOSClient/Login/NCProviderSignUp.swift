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
    private var reissuedURL: URL?
    private var isFinished = false

    init(url: URL, coordinator: NCLoginCoordinator) {
        self.url = url
        self.coordinator = coordinator

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

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.customUserAgent = userAgent
        webView.navigationDelegate = self
        view.addSubview(webView)

        webView.load(Self.apiRequest(for: Self.uncachedURL(url)))
    }

    /// nextcloud.com serves its sign-up page from a cache that ignores the header, unless the address has a query.
    private static func uncachedURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }

        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "ocsapi", value: "1")]

        return components.url ?? url
    }

    private static func apiRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("true", forHTTPHeaderField: apiHeader)

        return request
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

        // Redirects and links lose the header, so such page loads are started again with it, once.
        if navigationAction.targetFrame?.isMainFrame == true, request.httpMethod == "GET" {
            if request.value(forHTTPHeaderField: Self.apiHeader) != nil {
                reissuedURL = nil
            } else if url != reissuedURL {
                reissuedURL = url
                decisionHandler(.cancel)
                webView.load(Self.apiRequest(for: url))
                return
            }
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard let url = webView.url, url.scheme?.lowercased() == scheme else { return }

        finish(callbackURL: url)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        NCActivityIndicator.shared.startActivity(backgroundView: view, style: .medium, blurEffect: false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NCActivityIndicator.shared.stop()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showLoadError(error, in: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadError(error, in: webView)
    }

    // MARK: - Errors

    private func showLoadError(_ error: Error, in webView: WKWebView) {
        NCActivityIndicator.shared.stop()

        // Page loads this class replaces end as interrupted or cancelled.
        let nsError = error as NSError
        let isInterrupted = nsError.domain == "WebKitErrorDomain" && nsError.code == 102

        guard !isFinished, !isInterrupted, presentedViewController == nil,
              let message = NKError(error: error).userFriendlyMessage() else { return }

        let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: NSLocalizedString("_close_", comment: ""), style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("_retry_", comment: ""), style: .default) { [weak self, weak webView] _ in
            guard let self, let webView else { return }

            if webView.backForwardList.currentItem == nil {
                webView.load(Self.apiRequest(for: Self.uncachedURL(url)))
            } else {
                webView.reload()
            }
        })

        present(alert, animated: true)
    }

    // MARK: - Account

    private func finish(callbackURL: URL) {
        guard !isFinished else { return }

        isFinished = true
        NCActivityIndicator.shared.stop()

        Task {
            let windowScene = coordinator.presenter?.view.window?.windowScene

            await withCheckedContinuation { continuation in
                dismiss(animated: true) {
                    continuation.resume()
                }
            }

            do {
                let credentials = try LoginCallbackParser.parse(callbackURL, scheme: scheme)

                try await coordinator.addAccount(host: credentials.host, user: credentials.user, password: credentials.password)
            } catch let error as NKError {
                await showErrorBanner(windowScene: windowScene, error: error)
            } catch {
                await showErrorBanner(windowScene: windowScene, text: error.localizedDescription)
            }
        }
    }
}
