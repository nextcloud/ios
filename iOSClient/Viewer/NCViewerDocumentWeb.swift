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

class NCViewerDocumentWeb: NSObject {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var safeAreaBottom: Int = 0
    var mimeType: String?
    
    @objc static let sharedInstance: NCViewerDocumentWeb = {
        let instance = NCViewerDocumentWeb()
        return instance
    }()
    
    @objc func viewDocumentWebAt(_ metadata: tableMetadata, detail: CCDetail) {
        
        if !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) { return }
        
        if #available(iOS 11.0, *) {
            safeAreaBottom = Int((UIApplication.shared.keyWindow?.safeAreaInsets.bottom)!)
        }
        
        let fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
        let fileNameExtension = (metadata.fileNameView as NSString).pathExtension.uppercased()

        CCUtility.copyFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView), toPath: fileNamePath)
        
        let url = URL.init(fileURLWithPath: fileNamePath)

        let preferences = WKPreferences()
        let configuration = WKWebViewConfiguration()

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
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: Int(detail.view.bounds.size.width), height: Int(detail.view.bounds.size.height) - Int(k_detail_Toolbar_Height) - safeAreaBottom - 1), configuration: configuration)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.backgroundColor = .white
        
        webView.isOpaque = false
        
        if fileNameExtension == "CSS" || fileNameExtension == "PY" || fileNameExtension == "XML" || fileNameExtension == "JS" {
            
            do {
                let dataFile = try String(contentsOf: url, encoding: String.Encoding(rawValue: String.Encoding.ascii.rawValue))
                
                if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.phone {
                    webView.loadHTMLString("<div style='font-size:40;font-family:Sans-Serif;'><pre>" + dataFile, baseURL: nil)
                } else {
                    webView.loadHTMLString("<div style='font-size:20;font-family:Sans-Serif;'><pre>" + dataFile, baseURL: nil)
                }
                
            } catch {
                print("error")
            }
            
        } else if CCUtility.isDocumentModifiableExtension(fileNameExtension) {
            
            let session = URLSession(configuration: URLSessionConfiguration.default)
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            
            let task = session.dataTask(with: request) { (data, response, error) in
                
                guard let data = data else {
                    return
                }
                guard let response = response else {
                    return
                }
                
                DispatchQueue.main.async {
                    
                    guard let encodingName = NCUchardet.sharedNUCharDet()?.encodingStringDetect(with: data) else {
                        return
                    }
                    self.mimeType = response.mimeType
                    webView.load(data, mimeType: response.mimeType!, characterEncodingName: encodingName, baseURL: url)
                }
            }
            
            task.resume()
            
        } else {
            
            webView.load(URLRequest(url: url))
        }
        
        detail.view.addSubview(webView)
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
