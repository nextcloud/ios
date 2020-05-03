//
//  NCViewerDocumentWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/09/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

class NCViewerDocumentWeb: WKWebView {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var safeAreaBottom: Int = 0
    var mimeType: String?
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationDelegate = self
        backgroundColor = .white
        isOpaque = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc func viewDocumentWebAt(_ metadata: tableMetadata, view: UIView) {
        
        if !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) { return }
        
        if #available(iOS 11.0, *) {
            safeAreaBottom = Int((UIApplication.shared.keyWindow?.safeAreaInsets.bottom)!)
        }
        
        let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
        let fileNameExtension = (metadata.fileNameView as NSString).pathExtension.uppercased()

        CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: fileNamePath)
        
        let url = URL.init(fileURLWithPath: fileNamePath)

        let preferences = WKPreferences()
        preferences.javaScriptEnabled = false

        // Detect file xls, xlss for enable javascript
        if fileNameExtension == "XLS" || fileNameExtension == "XLSX" {
            if let fileHandle = FileHandle(forReadingAtPath: fileNamePath) {
                let data = fileHandle.readData(ofLength: 4)
                if data.starts(with: [0x50, 0x4b, 0x03, 0x04]) { // "PK\003\004"
                    preferences.javaScriptEnabled = true
                }
                fileHandle.closeFile()
            }
        }
        configuration.preferences = preferences
                
        if fileNameExtension == "CSS" || fileNameExtension == "PY" || fileNameExtension == "XML" || fileNameExtension == "JS" {
            
            do {
                let dataFile = try String(contentsOf: url, encoding: String.Encoding(rawValue: String.Encoding.ascii.rawValue))
                
                if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.phone {
                    loadHTMLString("<div style='font-size:40;font-family:Sans-Serif;'><pre>" + dataFile, baseURL: nil)
                } else {
                    loadHTMLString("<div style='font-size:20;font-family:Sans-Serif;'><pre>" + dataFile, baseURL: nil)
                }
                
            } catch {
                print("error")
            }
            
        } else {
            
            load(URLRequest(url: url))
        }
        
        view.addSubview(self)
    }
}

extension NCViewerDocumentWeb: WKNavigationDelegate {
    
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
        if self.mimeType != nil && self.mimeType == "text/plain" && CCUtility.getDarkMode() {
            let js = "document.getElementsByTagName('body')[0].style.webkitTextFillColor= 'white';DOMReady();"
            webView.evaluateJavaScript(js) { (_, _) in }
        }
    }
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirectForProvisionalNavigation");
    }
}
