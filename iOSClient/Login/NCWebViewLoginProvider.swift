// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
@preconcurrency import WebKit
import NextcloudKit
import FloatingPanel

protocol NCLoginProviderDelegate: AnyObject {
    ///
    /// Called when the back button is tapped in the login provider view.
    ///
    func onBack()
}

///
/// View which presents the web view to login at a Nextcloud instance.
///
class NCWebViewLoginProvider: UIViewController {
    var webView: WKWebView!
    var titleView: String = ""
    var initialURLString = ""
    var uiColor: UIColor = .white
    weak var delegate: NCLoginProviderDelegate?
    var controller: NCMainTabBarController?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        nkLog(debug: "Login provider view did load.")
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.customUserAgent = userAgent
        webView.isInspectable = true
        webView.navigationDelegate = self
        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        webView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        webView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

        self.webView = webView

        let navigationItemBack = UIBarButtonItem(image: UIImage(systemName: "arrow.left"), style: .plain, target: self, action: #selector(goBack(_:)))
        navigationItemBack.tintColor = uiColor
        navigationItem.leftBarButtonItem = navigationItemBack
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nkLog(debug: "Login provider appeared.")

        guard let url = URL(string: initialURLString) else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_login_url_error_")
            NCContentPresenter().showError(error: error, priority: .max)
            return
        }

        if let host = url.host {
            titleView = host

            if let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount(), NCPreferences().getPassword(account: activeTableAccount.account).isEmpty {
                titleView = NSLocalizedString("_user_", comment: "") + " " + activeTableAccount.userId + " " + NSLocalizedString("_in_", comment: "") + " " + host
            }
        }

        loadWebPage(url: url)
        self.title = titleView
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        nkLog(debug: "Login provider view did disappear.")

        NCActivityIndicator.shared.stop()
    }

    // MARK: - Navigation

    private func loadWebPage(url: URL) {
        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)

        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        webView.load(request)
    }

    ///
    /// Dismiss the login web view from the hierarchy.
    ///
    @objc func goBack(_ sender: Any?) {
        delegate?.onBack()

        if isModal {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Polling

}

// MARK: - WKNavigationDelegate

extension NCWebViewLoginProvider: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        nkLog(debug: "Web view did receive server redirect for provisional navigation.")

        guard let currentWebViewURL = webView.url else {
            nkLog(error: "Web view does not have a URL after receiving a server redirect for provisional navigation!")
            return
        }

        let currentWebViewURLString: String = currentWebViewURL.absoluteString.lowercased()

        // Prevent HTTP redirects.
        if initialURLString.lowercased().hasPrefix("https://") && currentWebViewURLString.hasPrefix("http://") {
            nkLog(error: "Web view redirect degrades session from HTTPS to HTTP and must be cancelled!")

            let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_prevent_http_redirection_", comment: ""), preferredStyle: .alert)

            alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
                _ = self.navigationController?.popViewController(animated: true)
            }))

            self.present(alertController, animated: true)

            return
        }

        // Login via provider.
        if currentWebViewURLString.hasPrefix(NCBrandOptions.shared.webLoginAutenticationProtocol) && currentWebViewURLString.contains("login") {
            nkLog(debug: "Web view redirect to provider login URL detected.")

            var server: String = ""
            var user: String = ""
            var password: String = ""
            let keyValue = currentWebViewURL.path.components(separatedBy: "&")

            for value in keyValue {
                if value.contains("server:") { server = value }
                if value.contains("user:") { user = value }
                if value.contains("password:") { password = value }
            }

            if !server.isEmpty, !user.isEmpty, !password.isEmpty {
                let server: String = server.replacingOccurrences(of: "/server:", with: "")
                let username: String = user.replacingOccurrences(of: "user:", with: "").replacingOccurrences(of: "+", with: " ")
                let password: String = password.replacingOccurrences(of: "password:", with: "")

                if self.controller == nil {
                    self.controller = UIApplication.shared.mainAppWindow?.rootViewController as? NCMainTabBarController
                }

                Task { @MainActor in
                    await NCAccount().createAccount(viewController: self, urlBase: server, user: username, password: password, controller: controller)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        nkLog(debug: "Web view did receive authentication challenge.")

        DispatchQueue.global().async {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        nkLog(debug: "Web view will allow navigation to \(navigationAction.request.url?.absoluteString ?? "nil")")
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        nkLog(debug: "Web view did start provisional navigation.")
        NCActivityIndicator.shared.startActivity(backgroundView: self.view, style: .medium, blurEffect: false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        nkLog(debug: "Web view did finish navigation to \(webView.url?.absoluteString ?? "nil")")
        NCActivityIndicator.shared.stop()
    }
}
