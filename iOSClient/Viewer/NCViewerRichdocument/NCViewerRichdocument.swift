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
import WebKit
import NCCommunication

class NCViewerRichdocument: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, NCSelectDelegate {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var webView = WKWebView()
    var bottomConstraint : NSLayoutConstraint?
    var documentInteractionController: UIDocumentInteractionController!
    
    var link: String = ""
    var metadata: tableMetadata = tableMetadata()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
             
        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_deleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_renameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_moveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viewUnload), name: NSNotification.Name(rawValue: k_notificationCenter_menuDetailClose), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.grabFocus), name: NSNotification.Name(rawValue: k_notificationCenter_richdocumentGrabFocus), object: nil)
        
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let contentController = config.userContentController
        contentController.add(self, name: "RichDocumentsMobileInterface")
        
        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView.navigationDelegate = self
        view.addSubview(webView)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        webView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        webView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        bottomConstraint = webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
        bottomConstraint?.isActive = true
        
        var request = URLRequest(url: URL(string: link)!)
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        let language = NSLocale.preferredLanguages[0] as String
        request.addValue(language, forHTTPHeaderField: "Accept-Language")
                
        webView.customUserAgent = CCUtility.getUserAgent()
        
        webView.load(request)
    }
   
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let buttonMore = UIBarButtonItem.init(image: CCGraphics.changeThemingColorImage(UIImage(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView), style: .plain, target: self, action: #selector(self.openMenuMore))
        navigationItem.rightBarButtonItem = buttonMore
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.title = metadata.fileNameView

        appDelegate.activeViewController = self
    }
    
    @objc func viewUnload() {
        
        navigationController?.popViewController(animated: true)
    }
    
    
    //MARK: - NotificationCenter
   
    @objc func moveFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata, let metadataNew = userInfo["metadataNew"] as? tableMetadata {
                if metadata.ocId == self.metadata.ocId {
                    self.metadata = metadataNew
                }
            }
        }
    }
    
    @objc func deleteFile(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.ocId == self.metadata.ocId {
                    viewUnload()
                }
            }
        }
    }
    
    @objc func renameFile(_ notification: NSNotification) {
        if let userInfo = notification.userInfo as NSDictionary? {
            if let metadata = userInfo["metadata"] as? tableMetadata {
                if metadata.ocId == self.metadata.ocId {
                    self.metadata = metadata
                    navigationItem.title = metadata.fileNameView
                }
            }
        }
    }

    @objc func keyboardDidShow(notification: Notification) {
        guard let info = notification.userInfo else { return }
        guard let frameInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardFrame = frameInfo.cgRectValue
        let height = keyboardFrame.size.height
        bottomConstraint?.constant = -height
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        bottomConstraint?.constant = 0
    }
    
    //MARK: - Action
    
    @objc func openMenuMore() {
        NCViewer.shared.toggleMoreMenu(viewController: self, metadata: metadata)
    }
   
    
    //MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        if (message.name == "RichDocumentsMobileInterface") {
            
            if message.body as? String == "close" {
                
                //appDelegate.activeDetail.viewUnload()                                
                appDelegate.activeFiles.reloadDataSourceNetwork()
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
                
                navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                self.present(navigationController, animated: true, completion: nil)
            }
            
            if message.body as? String == "share" {
                NCNetworkingNotificationCenter.shared.openShare(ViewController: self, metadata: metadata, indexPage: 2)
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
                            NCUtility.shared.startActivityIndicator(view: self.view)
                        }
                        
                        NCCommunication.shared.download(serverUrlFileName: urlString, fileNameLocalPath: fileNameLocalPath, requestHandler: { (_) in
                            
                        }, progressHandler: { (_) in
                            
                        }, completionHandler: { (account, etag, date, lenght, error, errorCode, errorDescription) in
                            
                            if errorCode == 0 && account == self.metadata.account {
                                if type == "print" {
                                    NCUtility.shared.stopActivityIndicator()
                                    let pic = UIPrintInteractionController.shared
                                    let printInfo = UIPrintInfo.printInfo()
                                    printInfo.outputType = UIPrintInfo.OutputType.general
                                    printInfo.orientation = UIPrintInfo.Orientation.portrait
                                    printInfo.jobName = "Document"
                                    pic.printInfo = printInfo
                                    pic.printingItem = URL(fileURLWithPath: fileNameLocalPath)
                                    pic.present(from: CGRect.zero, in: self.view, animated: true, completionHandler: { (pci, completed, error) in
                                        // end.
                                    })
                                } else {
                                    self.documentInteractionController = UIDocumentInteractionController()
                                    self.documentInteractionController.url = URL(fileURLWithPath: fileNameLocalPath)
                                    self.documentInteractionController.presentOptionsMenu(from: self.appDelegate.window.rootViewController!.view.bounds, in: self.appDelegate.window.rootViewController!.view, animated: true)
                                }
                            } else {
                                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
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
                } else if param["MessageName"] as? String == "hyperlink" {
                    if let values = param["Values"] as? Dictionary<AnyHashable,Any> {
                        guard let urlString = values["Url"] as? String else {
                            return
                        }
                        if let url = URL(string: urlString) {
                            UIApplication.shared.open(url)
                        }
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
        webView.evaluateJavaScript(functionJS) { (result, error) in }
    }
    
    //MARK: -
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], buttonType: String, overwrite: Bool) {
        
        if serverUrl != nil && metadata != nil {
            
            let path = CCUtility.returnFileNamePath(fromFileName: metadata!.fileName, serverUrl: serverUrl!, urlBase: appDelegate.urlBase, account: metadata!.account)!
            
            NCCommunication.shared.createAssetRichdocuments(path: path) { (account, url, errorCode, errorDescription) in
                if errorCode == 0 && account == self.appDelegate.account {
                    let functionJS = "OCA.RichDocuments.documentsMain.postAsset('\(metadata!.fileNameView)', '\(url!)')"
                    self.webView.evaluateJavaScript(functionJS, completionHandler: { (result, error) in })
                } else if errorCode != 0 {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                } else {
                    print("[LOG] It has been changed user during networking process, error.")
                }
            }
        }
    }
    
    func select(_ metadata: tableMetadata!, serverUrl: String!) {
        
        let path = CCUtility.returnFileNamePath(fromFileName: metadata!.fileName, serverUrl: serverUrl!, urlBase: appDelegate.urlBase, account: metadata!.account)!
        
        NCCommunication.shared.createAssetRichdocuments(path: path) { (account, url, errorCode, errorDescription) in
            if errorCode == 0 && account == self.appDelegate.account {
                let functionJS = "OCA.RichDocuments.documentsMain.postAsset('\(metadata.fileNameView)', '\(url!)')"
                self.webView.evaluateJavaScript(functionJS, completionHandler: { (result, error) in })
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
            } else {
                print("[LOG] It has been changed user during networking process, error.")
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
