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

import Foundation

class NCLoginWeb: UIViewController {
    
    var activityIndicator: UIActivityIndicatorView!
    var webView: WKWebView?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @objc var urlBase = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (NCBrandOptions.sharedInstance.use_login_web_personalized) {
            if let accountCount = NCManageDatabase.sharedInstance.getAccounts()?.count {
                if(accountCount > 0) {
                    self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .stop, target: self, action: #selector(self.closeView(sender:)))
                }
            }
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
        
        // ADD k_flowEndpoint for Web Flow
        if urlBase != NCBrandOptions.sharedInstance.linkloginPreferredProviders {
            urlBase =  urlBase + k_flowEndpoint
        }
        
        activityIndicator = UIActivityIndicatorView(style: .gray)
        activityIndicator.center = self.view.center
        activityIndicator.startAnimating()
        self.view.addSubview(activityIndicator)
        
        loadWebPage(webView: webView!, url: URL(string: urlBase)!)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Stop timer error network
        appDelegate.timerErrorNetworking.invalidate()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Start timer error network
        appDelegate.startTimerErrorNetworking()
    }
    
    func loadWebPage(webView: WKWebView, url: URL)  {
        
        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)
        
        request.setValue(CCUtility.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")
        
        webView.load(request)
    }
    
    @objc func closeView(sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension NCLoginWeb: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        
        guard let url = webView.url else { return }
        
        let urlString: String = url.absoluteString.lowercased()
        
        if (urlString.hasPrefix(NCBrandOptions.sharedInstance.webLoginAutenticationProtocol) == true && urlString.contains("login") == true) {
            
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
                
                var serverUrl: String = server.replacingOccurrences(of: "/server:", with: "")
                
                // Login Flow NC 12
                if (NCBrandOptions.sharedInstance.use_login_web_personalized == false && serverUrl.hasPrefix("http://") == false && serverUrl.hasPrefix("https://") == false) {
                    serverUrl = urlBase
                }
                
                if (serverUrl.last == "/") {
                    serverUrl = String(serverUrl.dropLast())
                }
                
                let username: String = user.replacingOccurrences(of: "user:", with: "").replacingOccurrences(of: "+", with: " ")
                let token: String = password.replacingOccurrences(of: "password:", with: "")
                
                let account : String = "\(username) \(serverUrl)"
                
                // NO account found, clear
                if NCManageDatabase.sharedInstance.getAccounts() == nil { NCUtility.sharedInstance.removeAllSettings() }
                
                // Add new account
                NCManageDatabase.sharedInstance.deleteAccount(account)
                NCManageDatabase.sharedInstance.addAccount(account, url: serverUrl, user: username, password: token)
                
                guard let tableAccount = NCManageDatabase.sharedInstance.setAccountActive(account) else {
                    self.dismiss(animated: true, completion: nil)
                    return
                }
                
                appDelegate.settingActiveAccount(account, activeUrl: serverUrl, activeUser: username, activeUserID: tableAccount.userID, activePassword: token)
                
                if (CCUtility.getIntro()) {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "initializeMain"), object: nil, userInfo: nil)
                    self.dismiss(animated: true)
                    
                } else {
                    CCUtility.setIntro(true)
                    if (self.presentingViewController == nil) {
                        let splitController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
                        splitController?.modalPresentationStyle = .fullScreen
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "initializeMain"), object: nil, userInfo: nil)
                        self.navigationController?.present(splitController!, animated: true)
                    } else {
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "initializeMain"), object: nil, userInfo: nil)
                        self.dismiss(animated: true)
                    }
                }
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil);
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        decisionHandler(.allow)

        /* TEST NOT GOOD DON'T WORKS
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if String(describing: url).hasPrefix(NCBrandOptions.sharedInstance.webLoginAutenticationProtocol) {
            decisionHandler(.allow)
            return
        } else if navigationAction.request.httpMethod != "GET" || navigationAction.request.value(forHTTPHeaderField: "OCS-APIRequest") != nil {
            decisionHandler(.allow)
            return
        }
        
        decisionHandler(.cancel)
        
        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)
        
        request.setValue(CCUtility.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")
        
        webView.load(request)
        */
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation");
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        print("didFinishProvisionalNavigation");
    }
}
