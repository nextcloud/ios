//
//  NCBrowserWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 22/08/2019.
//  Copyright © 2019 TWS. All rights reserved.
//

import Foundation

@objc protocol NCBrowserWebDelegate: class {
    @objc optional func browserWebDismiss()
}

class NCBrowserWeb: UIViewController {
    
    var webView: WKWebView?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc var urlBase = ""
    @objc var isHiddenButtonExit = false
    @objc weak var delegate: NCBrowserWebDelegate?
    
    @IBOutlet weak var buttonExit: UIButton!
    
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
        
        // button exit
        if isHiddenButtonExit {
            buttonExit.isHidden = true
        } else {
            self.view.bringSubviewToFront(buttonExit)
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
    
    @IBAction func touchUpInsideButtonExit(_ sender: UIButton) {
        self.dismiss(animated: true) {
            self.delegate?.browserWebDismiss?()
        }
    }
}

extension NCBrowserWeb: WKNavigationDelegate {
    
   
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil);
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation");
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinishProvisionalNavigation");
    }
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirectForProvisionalNavigation");
    }
}
