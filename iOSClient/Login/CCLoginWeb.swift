//
//  CCLoginWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import UIKit

@objc protocol CCLoginDelegateWeb: class {
    func loginSuccess(_: NSInteger)
    func loginDisappear()
}

public class CCLoginWeb: UIViewController {

    /*
    @objc enum enumLoginTypeWeb : NSInteger {
        case loginAdd = 0
        case loginAddForced = 1
        case loginModifyPasswordUser = 2
    }
    */
    
    @objc weak var delegate: CCLoginDelegateWeb?
    @objc var loginType = loginAdd
    @objc var urlBase = NCBrandOptions.sharedInstance.loginBaseUrl
    
    var viewController : UIViewController?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var doneButtonVisible: Bool = false
    
    @objc func presentModalWithDefaultTheme(_ vc: UIViewController) {
        
        self.viewController = vc
        
        if (loginType == loginAdd || loginType == loginModifyPasswordUser) {
            doneButtonVisible = true
        }
        
        let webVC = SwiftModalWebVC(urlString: urlBase, theme: .custom, color: NCBrandColor.sharedInstance.brand, colorText: NCBrandColor.sharedInstance.brandText, doneButtonVisible: doneButtonVisible, hideToolbar: true)
        webVC.delegateWeb = self

        vc.present(webVC, animated: false, completion: nil)
    }
}

extension CCLoginWeb: SwiftModalWebVCDelegate {
    
    public func didStartLoading() {
        print("Started loading.")
    }
    
    public func didReceiveServerRedirectForProvisionalNavigation(url: URL) {
                
        let urlString: String = url.absoluteString.lowercased()
        
        if (urlString.contains(NCBrandOptions.sharedInstance.webLoginAutenticationProtocol) == true && urlString.contains("login") == true && (loginType == loginAdd || loginType == loginAddForced)) {
            
            let keyValue = url.path.components(separatedBy: "&")
            if (keyValue.count == 3) {
                
                if (keyValue[0].contains("server:") && keyValue[1].contains("user:") && keyValue[2].contains("password:")) {
                
                    var serverUrl : String = keyValue[0].replacingOccurrences(of: "/server:", with: "")
                    
                    // Login Flow
                    if NCBrandOptions.sharedInstance.use_login_web_flow == true {
                        
                        if (self.urlBase.hasPrefix("http://")) {
                            serverUrl = "http://" + serverUrl;
                        } else if (self.urlBase.hasPrefix("https://")) {
                            serverUrl = "https://" + serverUrl;
                        }
                    }
                    
                    if (serverUrl.last == "/") {
                        serverUrl = String(serverUrl.dropLast())
                    }
                
                    let username : String = keyValue[1].replacingOccurrences(of: "user:", with: "")
                    let password : String = keyValue[2].replacingOccurrences(of: "password:", with: "")
                
                    let account : String = "\(username) \(serverUrl)"
                
                    NCManageDatabase.sharedInstance.deleteAccount(account)
                    NCManageDatabase.sharedInstance.addAccount(account, url: serverUrl, user: username, password: password, loginFlow: true)
                    
                    guard let tableAccount = NCManageDatabase.sharedInstance.setAccountActive(account) else {
                        return
                    }
                
                    if (tableAccount.account == account) {
                    
                        appDelegate.settingActiveAccount(account, activeUrl: serverUrl, activeUser: username, activeUserID: tableAccount.userID, activePassword: password)
                        self.delegate?.loginSuccess(NSInteger(loginType.rawValue))
                
                        self.viewController?.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }

    public func didFinishLoading(success: Bool, url: URL) {
        print("Finished loading. Success: \(success).")
    }
    
    public func loginDisappear() {
        self.delegate?.loginDisappear()
    }
}


