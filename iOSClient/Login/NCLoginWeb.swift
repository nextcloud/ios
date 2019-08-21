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

@objc protocol NCLoginDelegateWeb: class {
    func loginSuccess(_: NSInteger)
    @objc optional func webDismiss()
}

class NCLoginWeb: UIViewController {
    
    var webView: WKWebView?
    @objc var urlBase = ""
    @objc var loginType: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView = WKWebView(frame: CGRect.zero)
        webView!.navigationDelegate = self
        view.addSubview(webView!)
        webView!.translatesAutoresizingMaskIntoConstraints = false
        webView!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        webView!.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        webView!.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        webView!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        
        // ADD k_flowEndpoint for Web Flow
        if NCBrandOptions.sharedInstance.use_login_web_personalized == false && urlBase != NCBrandOptions.sharedInstance.linkloginPreferredProviders {
            urlBase =  urlBase + k_flowEndpoint
        }
        
        loadWebPage(webView: webView!, url: URL(string: urlBase)!)
    }
    
    func loadWebPage(webView: WKWebView, url: URL)  {
        
        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)
        
        request.setValue(CCUtility.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")
        
        webView.load(request)
    }
}

extension NCLoginWeb: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil);
        }
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation");
    }
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirectForProvisionalNavigation");
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NCUtility.sharedInstance.stopActivityIndicator()
    }
}
