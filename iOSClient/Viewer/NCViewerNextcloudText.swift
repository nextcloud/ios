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
import WebKit

class NCViewerNextcloudText: WKWebView, WKNavigationDelegate, WKScriptMessageHandler {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var editor: String!
    var metadata: tableMetadata!
    var view: UIView!
    var viewController: UIViewController!
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
    }
    
    @objc func viewerAt(_ link: String, metadata: tableMetadata, editor: String, view: UIView, viewController: UIViewController) {
                
        self.metadata = metadata
        self.editor = editor
        self.view = view
        self.viewController = viewController

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        var request = URLRequest(url: URL(string: link)!)
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        let language = NSLocale.preferredLanguages[0] as String
        request.addValue(language, forHTTPHeaderField: "Accept-Language")
                
        if editor == k_editor_onlyoffice {
            customUserAgent = NCUtility.shared.getCustomUserAgentOnlyOffice()
        } else {
            customUserAgent = CCUtility.getUserAgent()
        }
        
        load(request)
        
        self.view.addSubview(self)
    }
    
    @objc func keyboardDidShow(notification: Notification) {
        guard let info = notification.userInfo else { return }
        guard let frameInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardFrame = frameInfo.cgRectValue
        frame.size.height = view.frame.height - keyboardFrame.size.height
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        frame = view.frame
    }
    
    //MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        if (message.name == "DirectEditingMobileInterface") {
            
            if message.body as? String == "close" {
                                
                appDelegate.activeDetail.viewUnload()
                appDelegate.activeMain.readFileReloadFolder()
            }
            
            if message.body as? String == "share" {
                NCMainCommon.shared.openShare(ViewController: viewController, metadata: metadata, indexPage: 2)
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
        NCUtility.shared.stopActivityIndicator()
    }
}
