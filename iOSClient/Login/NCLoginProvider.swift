// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
@preconcurrency import WebKit
import NextcloudKit
import FloatingPanel

class NCLoginProvider: UIViewController {
    var webView: WKWebView?
    let utility = NCUtility()
    var titleView: String = ""
    var urlBase = ""
    var uiColor: UIColor = .white
    var pollTimer: DispatchSourceTimer?
    weak var delegate: NCLoginProviderDelegate?
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        webView = WKWebView(frame: CGRect.zero, configuration: WKWebViewConfiguration())
        if let webView {
            webView.navigationDelegate = self
            view.addSubview(webView)

            webView.translatesAutoresizingMaskIntoConstraints = false
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
            webView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
            webView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        }

        let navigationItemBack = UIBarButtonItem(image: UIImage(systemName: "arrow.left"), style: .done, target: self, action: #selector(goBack))
        navigationItemBack.tintColor = uiColor
        navigationItem.leftBarButtonItem = navigationItemBack
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let url = URL(string: urlBase),
           let webView {
            HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

            WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records, completionHandler: {
                    self.loadWebPage(webView: webView, url: url)
                })
            }
        } else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_login_url_error_")
            NCContentPresenter().showError(error: error, priority: .max)
        }

        if let host = URL(string: urlBase)?.host {
            titleView = host
            if let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount(), NCKeychain().getPassword(account: activeTableAccount.account).isEmpty {
                titleView = NSLocalizedString("_user_", comment: "") + " " + activeTableAccount.userId + " " + NSLocalizedString("_in_", comment: "") + " " + host
            }
        }

        self.title = titleView
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NCActivityIndicator.shared.stop()

        pollTimer?.cancel()
        pollTimer = nil
    }

    func loadWebPage(webView: WKWebView, url: URL) {
        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)

        if let deviceName = "\(UIDevice.current.name) (\(NCBrandOptions.shared.brand) iOS)".cString(using: .utf8),
           let deviceUserAgent = String(cString: deviceName, encoding: .ascii) {
            webView.customUserAgent = deviceUserAgent
        } else {
            webView.customUserAgent = userAgent
        }

        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        webView.load(request)
    }

    @objc func goBack() {
        delegate?.onBack()
        navigationController?.popViewController(animated: true)
    }

    func poll(loginFlowV2Token: String, loginFlowV2Endpoint: String, loginFlowV2Login: String) {
        let queue = DispatchQueue.global(qos: .background)
        pollTimer = DispatchSource.makeTimerSource(queue: queue)

        guard let timer = pollTimer else { return }

        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .seconds(1))
        timer.setEventHandler(handler: {
            DispatchQueue.main.async {
                let controller = UIApplication.shared.firstWindow?.rootViewController as? NCMainTabBarController
                let loginOptions = NKRequestOptions(customUserAgent: userAgent)
                NextcloudKit.shared.getLoginFlowV2Poll(token: loginFlowV2Token, endpoint: loginFlowV2Endpoint, options: loginOptions) { server, loginName, appPassword, _, error in
                    if error == .success, let urlBase = server, let user = loginName, let appPassword {
                        NCAccount().createAccount(urlBase: urlBase, user: user, password: appPassword, controller: controller) { account, error in

                            if error == .success {
                                let window = UIApplication.shared.firstWindow
                                if let controller = window?.rootViewController as? NCMainTabBarController {
                                    controller.account = account
                                    controller.dismiss(animated: true, completion: nil)
                                } else {
                                    if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                                        controller.account = account
                                        controller.modalPresentationStyle = .fullScreen
                                        controller.view.alpha = 0

                                        window?.rootViewController = controller
                                        window?.makeKeyAndVisible()

                                        if let scene = window?.windowScene {
                                            SceneManager.shared.register(scene: scene, withRootViewController: controller)
                                        }

                                        UIView.animate(withDuration: 0.5) {
                                            controller.view.alpha = 1
                                        }
                                    }
                                }

                                timer.cancel()
                            }
                        }
                    }
                }
            }
        })

        timer.resume()
    }
}

extension NCLoginProvider: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        let urlString: String = url.absoluteString.lowercased()

        // prevent http redirection
        if urlBase.lowercased().hasPrefix("https://") && urlString.lowercased().hasPrefix("http://") {
            let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_prevent_http_redirection_", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
                _ = self.navigationController?.popViewController(animated: true)
            }))
            self.present(alertController, animated: true)
            return
        }

        // Login via provider
        if urlString.hasPrefix(NCBrandOptions.shared.webLoginAutenticationProtocol) == true && urlString.contains("login") == true {
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
                let server: String = server.replacingOccurrences(of: "/server:", with: "")
                let username: String = user.replacingOccurrences(of: "user:", with: "").replacingOccurrences(of: "+", with: " ")
                let password: String = password.replacingOccurrences(of: "password:", with: "")
                let controller = UIApplication.shared.firstWindow?.rootViewController as? NCMainTabBarController

                NCAccount().createAccount(urlBase: server, user: username, password: password, controller: controller) { account, error in

                    if error == .success {
                        let window = UIApplication.shared.firstWindow
                        if let controller = window?.rootViewController as? NCMainTabBarController {
                            controller.account = account
                            controller.dismiss(animated: true, completion: nil)
                        } else {
                            if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                                controller.account = account
                                controller.modalPresentationStyle = .fullScreen
                                controller.view.alpha = 0

                                window?.rootViewController = controller
                                window?.makeKeyAndVisible()

                                if let scene = window?.windowScene {
                                    SceneManager.shared.register(scene: scene, withRootViewController: controller)
                                }

                                UIView.animate(withDuration: 0.5) {
                                    controller.view.alpha = 1
                                }
                            }
                        }
                    } else {
                        let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: error.errorDescription, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                        self.present(alertController, animated: true)
                    }
                }
            }
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
        NCActivityIndicator.shared.startActivity(style: .medium, blurEffect: false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NCActivityIndicator.shared.stop()
    }
}

protocol NCLoginProviderDelegate: AnyObject {
    func onBack()
}
