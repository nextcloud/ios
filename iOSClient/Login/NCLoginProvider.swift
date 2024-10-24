//
//  NCLoginProvider.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/08/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
@preconcurrency import WebKit
import NextcloudKit
import FloatingPanel

class NCLoginProvider: UIViewController {
    var webView: WKWebView?
    let utility = NCUtility()
    var titleView: String = ""
    var urlBase = ""

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(self.closeView(sender:)))

        webView = WKWebView(frame: CGRect.zero, configuration: WKWebViewConfiguration())
        webView!.navigationDelegate = self
        view.addSubview(webView!)

        webView!.translatesAutoresizingMaskIntoConstraints = false
        webView!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        webView!.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        webView!.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        webView!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

        if let url = URL(string: urlBase) {
            loadWebPage(webView: webView!, url: url)
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

    @objc func closeView(sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
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
                createAccount(server: server, username: username, password: password)
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

    // MARK: -

    func createAccount(server: String, username: String, password: String) {
        var urlBase = server
        if urlBase.last == "/" { urlBase = String(urlBase.dropLast()) }
        let account: String = "\(username) \(urlBase)"
        let user = username

        NextcloudKit.shared.getUserProfile(account: account) { account, userProfile, _, error in
            if error == .success, let userProfile {
                NextcloudKit.shared.appendSession(account: account,
                                                  urlBase: urlBase,
                                                  user: user,
                                                  userId: user,
                                                  password: password,
                                                  userAgent: userAgent,
                                                  nextcloudVersion: NCCapabilities.shared.getCapabilities(account: account).capabilityServerVersionMajor,
                                                  groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
                NCSession.shared.appendSession(account: account, urlBase: urlBase, user: user, userId: userProfile.userId)
                NCManageDatabase.shared.addAccount(account, urlBase: urlBase, user: user, userId: userProfile.userId, password: password)
                NCAccount().changeAccount(account, userProfile: userProfile, controller: nil) { }

                let window = UIApplication.shared.firstWindow
                if let controller = window?.rootViewController as? NCMainTabBarController {
                    controller.account = account
                    self.dismiss(animated: true)
                } else {
                    if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? NCMainTabBarController {
                        controller.account = account
                        controller.modalPresentationStyle = .fullScreen
                        controller.view.alpha = 0
                        window?.rootViewController = controller
                        window?.makeKeyAndVisible()
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
