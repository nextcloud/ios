//
//  PrivacyPolicyViewController.swift
//  Nextcloud
//
//  Created by A200073704 on 25/04/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import WebKit

class PrivacyPolicyViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    var myWebView = WKWebView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("_privacy_policy_", comment: "")
        
        myWebView = WKWebView(frame: CGRect(x:0, y:0, width: UIScreen.main.bounds.width, height:UIScreen.main.bounds.height))
        myWebView.uiDelegate = self
        myWebView.navigationDelegate = self
        myWebView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(myWebView)
        
        //1. Load web site into my web view
        let myURL = URL(string: "https://static.magentacloud.de/privacy/datenschutzhinweise_app.htm")
        let myURLRequest:URLRequest = URLRequest(url: myURL!)
        NCActivityIndicator.shared.start()
        myWebView.load(myURLRequest)
        self.navigationController?.navigationBar.tintColor = NCBrandColor.shared.brand
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        myWebView = WKWebView(frame: CGRect(x:0, y:0, width: UIScreen.main.bounds.width, height:UIScreen.main.bounds.height))
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NCActivityIndicator.shared.stop()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated  {
            if let url = navigationAction.request.url,
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
}
