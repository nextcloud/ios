//
//  NCViewerRichdocument.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/09/18.
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

class NCViewerRichdocument: WKWebView, WKNavigationDelegate, WKScriptMessageHandler, NCSelectDelegate {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var detail: CCDetail!
    @objc var metadata: tableMetadata!
    var documentInteractionController: UIDocumentInteractionController!
   
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)

        let contentController = configuration.userContentController
        contentController.add(self, name: "RichDocumentsMobileInterface")
        
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationDelegate = self
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc func viewRichDocumentAt(_ link: String, detail: CCDetail, metadata: tableMetadata) {
        
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
        
        if (message.name == "RichDocumentsMobileInterface") {
            
            if message.body as? String == "close" {
                
                removeFromSuperview()
                
                detail.navigationController?.popViewController(animated: true)
                detail.navigationController?.navigationBar.topItem?.title = ""
            }
            
            if message.body as? String == "insertGraphic" {
                
                let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
                let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
                let viewController = navigationController.topViewController as! NCSelect
                
                viewController.delegate = self
                viewController.hideButtonCreateFolder = true
                viewController.selectFile = true
                viewController.includeDirectoryE2EEncryption = false
                viewController.includeImages = true
                viewController.type = ""
                viewController.layoutViewSelect = k_layout_view_richdocument
                
                navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                self.detail.present(navigationController, animated: true, completion: nil)
            }
            
            if message.body as? String == "share" {
                NCMainCommon.sharedInstance.openShare(ViewController: detail, metadata: metadata, indexPage: 2)
            }
            
            if let param = message.body as? Dictionary<AnyHashable,Any> {
                if param["MessageName"] as? String == "downloadAs" {
                    if let values = param["Values"] as? Dictionary<AnyHashable,Any> {
                        guard let type = values["Type"] as? String else {
                            return
                        }
                        guard let urlString = values["URL"] as? String else {
                            return
                        }
                        guard let url = URL(string: urlString) else {
                            return
                        }
                        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                            return
                        }
                        
                        let filename = (components.path as NSString).lastPathComponent
                        let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + filename
                    
                        if type == "print" {
                            NCUtility.sharedInstance.startActivityIndicator(view: self, bottom: 0)
                        }
                        
                        _ = OCNetworking.sharedManager()?.download(withAccount: metadata.account, url: urlString, fileNameLocalPath: fileNameLocalPath, encode:false, completion: { (account, message, errorCode) in

                            if errorCode == 0 && account == self.metadata.account {
                                if type == "print" {
                                    NCUtility.sharedInstance.stopActivityIndicator()
                                    let pic = UIPrintInteractionController.shared
                                    let printInfo = UIPrintInfo.printInfo()
                                    printInfo.outputType = UIPrintInfo.OutputType.general
                                    printInfo.orientation = UIPrintInfo.Orientation.portrait
                                    printInfo.jobName = "Document"
                                    pic.printInfo = printInfo
                                    pic.printingItem = URL(fileURLWithPath: fileNameLocalPath)
                                    pic.present(from: CGRect.zero, in: self, animated: true, completionHandler: { (pci, completed, error) in
                                        // end.
                                    })
                                } else {
                                    self.documentInteractionController = UIDocumentInteractionController()
                                    self.documentInteractionController.url = URL(fileURLWithPath: fileNameLocalPath)
                                    self.documentInteractionController.presentOptionsMenu(from: self.appDelegate.window.rootViewController!.view.bounds, in: self.appDelegate.window.rootViewController!.view, animated: true)
                                }
                            } else {
                                NCContentPresenter.shared.messageNotification("_error_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            }
                        })
                    }
                } else if param["MessageName"] as? String == "fileRename" {
                    if let values = param["Values"] as? Dictionary<AnyHashable,Any> {
                        guard let newName = values["NewName"] as? String else {
                            return
                        }
                        metadata.fileName = newName
                        metadata.fileNameView = newName
                    }
                }
            }
            
            if message.body as? String == "documentLoaded" {
                print("documentLoaded")
            }
            
            if message.body as? String == "paste" {
                self.paste(self)
            }
        }
    }
    
    //MARK: -

    @objc func grabFocus() {
    
        let functionJS = "OCA.RichDocuments.documentsMain.postGrabFocus()"
        evaluateJavaScript(functionJS) { (result, error) in }
    }
    
    //MARK: -
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String) {
        
        if serverUrl != nil && metadata != nil {
            
            OCNetworking.sharedManager().createAssetRichdocuments(withAccount: metadata?.account, fileName: metadata?.fileName, serverUrl: serverUrl, completion: { (account, url, message, errorCode) in
                if errorCode == 0 && account == self.appDelegate.activeAccount {
                    let functionJS = "OCA.RichDocuments.documentsMain.postAsset('\(metadata!.fileNameView)', '\(url!)')"
                    self.evaluateJavaScript(functionJS, completionHandler: { (result, error) in })
                } else if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                } else {
                    print("[LOG] It has been changed user during networking process, error.")
                }
            })
        }
    }
    
    func select(_ metadata: tableMetadata!, serverUrl: String!) {
        
        OCNetworking.sharedManager().createAssetRichdocuments(withAccount: metadata?.account, fileName: metadata?.fileName, serverUrl: serverUrl, completion: { (account, url, message, errorCode) in
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                let functionJS = "OCA.RichDocuments.documentsMain.postAsset('\(metadata.fileNameView)', '\(url!)')"
                self.evaluateJavaScript(functionJS, completionHandler: { (result, error) in })
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
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
        NCUtility.sharedInstance.stopActivityIndicator()
    }
}
