//
//  NCLoginWeb.swift
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
import WebKit
import NextcloudKit
import FloatingPanel

class NCLoginWeb: UIViewController {

    var webView: WKWebView?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var titleView: String = ""

    var urlBase = ""
    var user: String?
    
    var configServerUrl: String?
    var configUsername: String?
    var configPassword: String?
    var configAppPassword: String?

    var loginFlowV2Available = false
    var loginFlowV2Token = ""
    var loginFlowV2Endpoint = ""
    var loginFlowV2Login = ""

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let accountCount = NCManageDatabase.shared.getAccounts()?.count ?? 0

        // load AppConfig
        if (NCBrandOptions.shared.disable_multiaccount == false) || (NCBrandOptions.shared.disable_multiaccount == true && accountCount == 0) {
            if let configurationManaged = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed"), NCBrandOptions.shared.use_AppConfig {
                
                if let serverUrl = configurationManaged[NCGlobal.shared.configuration_serverUrl] as? String {
                    self.configServerUrl = serverUrl
                }
                if let username = configurationManaged[NCGlobal.shared.configuration_username] as? String, !username.isEmpty, username.lowercased() != "username" {
                    self.configUsername = username
                }
                if let password = configurationManaged[NCGlobal.shared.configuration_password] as? String, !password.isEmpty, password.lowercased() != "password" {
                    self.configPassword = password
                }
                if let apppassword = configurationManaged[NCGlobal.shared.configuration_apppassword] as? String, !apppassword.isEmpty, apppassword.lowercased() != "apppassword" {
                    self.configAppPassword = apppassword
                }
            }
        }

        if (NCBrandOptions.shared.use_login_web_personalized || NCBrandOptions.shared.use_AppConfig) && accountCount > 0 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(self.closeView(sender:)))
        }

        if accountCount > 0 {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "users")!.image(color: .label, size: 35), style: .plain, target: self, action: #selector(self.changeUser(sender:)))
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView!.navigationDelegate = self
        view.addSubview(webView!)

        webView!.translatesAutoresizingMaskIntoConstraints = false
        webView!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        webView!.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        webView!.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        webView!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

        // AppConfig
        if let serverUrl = configServerUrl {
            if let username = self.configUsername, let password = configAppPassword {
                createAccount(server: serverUrl, username: username, password: password)
                return
            } else if let username = self.configUsername, let password = configPassword {
                getAppPassword(serverUrl: serverUrl, username: username, password: password)
                return
            } else {
                urlBase = serverUrl
            }
        }
        
        // ADD end point for Web Flow
        if urlBase != NCBrandOptions.shared.linkloginPreferredProviders {
            if loginFlowV2Available {
                urlBase = loginFlowV2Login
            } else {
                urlBase += "/index.php/login/flow"
                if let user = self.user {
                    urlBase += "?user=\(user)"
                }
            }
        }

        if let url = URL(string: urlBase) {
            loadWebPage(webView: webView!, url: url)
        } else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_login_url_error_")
            NCContentPresenter.shared.showError(error: error, priority: .max)
        }

        // TITLE
        if let host = URL(string: urlBase)?.host {
            titleView = host
            if let account = NCManageDatabase.shared.getActiveAccount(), CCUtility.getPassword(account.account).isEmpty {
                titleView = NSLocalizedString("_user_", comment: "") + " " + account.userId + " " + NSLocalizedString("_in_", comment: "") + " " + host
            }
        }
        self.title = titleView
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Stop timer error network
        appDelegate.timerErrorNetworking?.invalidate()

        if let account = NCManageDatabase.shared.getActiveAccount(), CCUtility.getPassword(account.account).isEmpty {

            let message = "\n" + NSLocalizedString("_password_not_present_", comment: "")
            let alertController = UIAlertController(title: titleView, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
            present(alertController, animated: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NCActivityIndicator.shared.stop()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Start timer error network
        appDelegate.startTimerErrorNetworking()
    }

    func loadWebPage(webView: WKWebView, url: URL) {

        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)

        if let deviceName = "\(UIDevice.current.name) (\(NCBrandOptions.shared.brand) iOS)".cString(using: .utf8),
            let deviceUserAgent = String(cString: deviceName, encoding: .ascii) {
            webView.customUserAgent = deviceUserAgent
        } else {
            webView.customUserAgent = CCUtility.getUserAgent()
        }

        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        webView.load(request)
    }
    
    func getAppPassword(serverUrl: String, username: String, password: String) {
        
        NextcloudKit.shared.getAppPassword(serverUrl: serverUrl, username: username, password: password) { token, data, error in
            if error == .success, let password = token {
                self.createAccount(server: serverUrl, username: username, password: password)
            } else {
                NCContentPresenter.shared.showError(error: error)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }

    @objc func closeView(sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @objc func changeUser(sender: UIBarButtonItem) {
        toggleMenu()
    }
}

extension NCLoginWeb: WKNavigationDelegate {

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

            if server != "" && user != "" && password != "" {

                let server: String = server.replacingOccurrences(of: "/server:", with: "")
                let username: String = user.replacingOccurrences(of: "user:", with: "").replacingOccurrences(of: "+", with: " ")
                let password: String = password.replacingOccurrences(of: "password:", with: "")

                createAccount(server: server, username: username, password: password)
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {

        var errorMessage = error.localizedDescription

        for (key, value) in (error as NSError).userInfo {
            let message = "\(key) \(value)\n"
            errorMessage += message
        }

        let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: errorMessage, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))

        self.present(alertController, animated: true)
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

        if loginFlowV2Available {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NextcloudKit.shared.getLoginFlowV2Poll(token: self.loginFlowV2Token, endpoint: self.loginFlowV2Endpoint) { server, loginName, appPassword, data, error in
                    if error == .success && server != nil && loginName != nil && appPassword != nil {
                        self.createAccount(server: server!, username: loginName!, password: appPassword!)
                    }
                }
            }
        }
    }

    // MARK: -

    func createAccount(server: String, username: String, password: String) {

        var urlBase = server

        // Normalized
        if urlBase.last == "/" {
            urlBase = String(urlBase.dropLast())
        }

        // Create account
        let account: String = "\(username) \(urlBase)"

        // NO account found, clear all
        if NCManageDatabase.shared.getAccounts() == nil {
            NCUtility.shared.removeAllSettings()
        }
        
        // Add new account
        NCManageDatabase.shared.deleteAccount(account)
        NCManageDatabase.shared.addAccount(account, urlBase: urlBase, user: username, password: password)

        guard let tableAccount = NCManageDatabase.shared.setAccountActive(account) else {
            self.dismiss(animated: true, completion: nil)
            return
        }

        appDelegate.settingAccount(account, urlBase: urlBase, user: username, userId: tableAccount.userId, password: password)

        if CCUtility.getIntro() {
            self.dismiss(animated: true)
        } else {
            CCUtility.setIntro(true)
            if self.presentingViewController == nil {
                if let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() {
                    viewController.modalPresentationStyle = .fullScreen
                    viewController.view.alpha = 0
                    appDelegate.window?.rootViewController = viewController
                    appDelegate.window?.makeKeyAndVisible()
                    UIView.animate(withDuration: 0.5) {
                        viewController.view.alpha = 1
                    }
                }
            } else {
                self.dismiss(animated: true)
            }
        }
    }
}
