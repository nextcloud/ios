//
//  NCViewerNextcloudText.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/12/19.
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

class NCViewerNextcloudText: WKWebView, WKNavigationDelegate, WKScriptMessageHandler {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var detail: CCDetail!
    @objc var metadata: tableMetadata!
    var documentInteractionController: UIDocumentInteractionController!
   
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)

        let contentController = configuration.userContentController
        contentController.add(self, name: "DirectEditingMobileInterface")
        
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationDelegate = self
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc func viewNextcloudTextAt(_ link: String, detail: CCDetail, metadata: tableMetadata) {
        
        self.detail = detail
        self.metadata = metadata
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        if (UIDevice.current.userInterfaceIdiom == .phone) {
            detail.navigationController?.setNavigationBarHidden(true, animated: false)
        }
        
        var request = URLRequest(url: URL(string: link)!)
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        let language = NSLocale.preferredLanguages[0] as String
        request.addValue(language, forHTTPHeaderField: "Accept-Language")
        
        let userAgent : String = CCUtility.getUserAgent()
        customUserAgent = userAgent
        load(request)        
    }
    
    @objc func keyboardDidShow(notification: Notification) {
        guard let info = notification.userInfo else { return }
        guard let frameInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardFrame = frameInfo.cgRectValue
        //print("keyboardFrame: \(keyboardFrame)")
        frame.size.height = detail.view.bounds.height - keyboardFrame.size.height
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        frame = detail.view.bounds
    }
    
    //MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        if (message.name == "DirectEditingMobileInterface") {
            
            if message.body as? String == "close" {
                
                removeFromSuperview()
                
                detail.navigationController?.popViewController(animated: true)
                detail.navigationController?.navigationBar.topItem?.title = ""
            }
            
            if message.body as? String == "share" {
                NCMainCommon.sharedInstance.openShare(ViewController: detail, metadata: metadata, indexPage: 2)
            }
            
            if message.body as? String == "loading" {
                print("loading")
            }
            
            if message.body as? String == "loaded" {
                print("loaded")
            }
            
            if message.body as? String == "paste" {
                self.paste(self)
            }
        }
    }
        
    
    //MARK: -

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
