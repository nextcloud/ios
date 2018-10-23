//
//  NCViewerRichdocument.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/09/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class NCViewerRichdocument: NSObject, WKNavigationDelegate, WKScriptMessageHandler, CCMoveDelegate {
    
    @objc static let sharedInstance: NCViewerRichdocument = {
        let instance = NCViewerRichdocument()
        return instance
    }()
    
    var detail: CCDetail!
    var webView: WKWebView!
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @objc func viewRichDocumentAt(_ link: String, detail: CCDetail) {
        
        self.detail = detail
        
        let contentController = WKUserContentController()
        contentController.add(self, name: "RichDocumentsMobileInterface")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        
        webView = WKWebView(frame: detail.view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        webView.scrollView.showsHorizontalScrollIndicator = true
//        webView.scrollView.showsVerticalScrollIndicator = true
        webView.navigationDelegate = self
        
        var request = URLRequest(url: URL(string: link)!)
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        let language = NSLocale.preferredLanguages[0] as String
        request.addValue(language, forHTTPHeaderField: "Accept-Language")
        
        let userAgent : String = CCUtility.getUserAgent()
        webView.customUserAgent = userAgent
        webView.load(request)
        
        detail.view.addSubview(webView)
    }
    
    //MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        if (message.name == "RichDocumentsMobileInterface") {
            
            if message.body as! String == "close" {

                self.webView.removeFromSuperview()
                
                self.detail.navigationController?.popToRootViewController(animated: true)
                self.detail.navigationController?.navigationBar.topItem?.title = ""
            }
            
            if message.body as! String == "insertGraphic" {
                
                let storyboard = UIStoryboard(name: "CCMove", bundle: nil)
                let movieNavigationController = storyboard.instantiateViewController(withIdentifier: "CCMove") as! UINavigationController
                let moveViewController = movieNavigationController.topViewController as! CCMove
                
                moveViewController.delegate = self
                moveViewController.hideMoveutton = true
                moveViewController.hideCreateFolder = true
                moveViewController.tintColor = NCBrandColor.sharedInstance.brandText
                moveViewController.barTintColor = NCBrandColor.sharedInstance.brand
                moveViewController.tintColorTitle = NCBrandColor.sharedInstance.brandText
                moveViewController.networkingOperationQueue = appDelegate.netQueue
                moveViewController.includeImages = true
                moveViewController.includeDirectoryE2EEncryption = false
                moveViewController.selectFile = true
                
                movieNavigationController.modalPresentationStyle = UIModalPresentationStyle.formSheet
                self.detail.present(movieNavigationController, animated: true, completion: nil)
            }
            
            if message.body as! String == "share" {
                appDelegate.activeMain.openWindowShare(self.detail.metadataDetail)
            }
        }
    }
    
    //MARK: -
    
    func select(_ metadata: tableMetadata!, serverUrl: String!) {
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        ocNetworking?.createAssetRichdocuments(withFileName: metadata.fileName, serverUrl: serverUrl, success: { (url) in

            let functionJS = "OCA.RichDocuments.documentsMain.postAsset('\(metadata.fileNameView)', '\(url!)')"
            self.webView.evaluateJavaScript(functionJS, completionHandler: { (result, error) in })
            
        }, failure: { (message, errorCode) in
            self.appDelegate.messageNotification("_error_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
        })
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
        print("didFinish");
    }
    
}
