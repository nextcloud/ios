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
    @objc var urlBase = ""
    
    var viewController : UIViewController?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var doneButtonVisible: Bool = false
    
    @objc func presentModalWithDefaultTheme(_ vc: UIViewController) {
        
        var urlString = urlBase
        self.viewController = vc
        
        if (loginType == loginAdd || loginType == loginModifyPasswordUser) {
            doneButtonVisible = true
        }
        
        if (NCBrandOptions.sharedInstance.use_login_web_personalized == false) {
            urlString =  urlBase+flowEndpoint
        }
        
        let webVC = SwiftModalWebVC(urlString: urlString, theme: .custom, color: NCBrandColor.sharedInstance.customer, colorText: NCBrandColor.sharedInstance.customerText, doneButtonVisible: doneButtonVisible, hideToolbar: true)
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
        
        if (urlString.hasPrefix(NCBrandOptions.sharedInstance.webLoginAutenticationProtocol) == true && urlString.contains("login") == true) {
            
            let keyValue = url.path.components(separatedBy: "&")
            if (keyValue.count == 3) {
                
                if (keyValue[0].contains("server:") && keyValue[1].contains("user:") && keyValue[2].contains("password:")) {
                
                    var serverUrl : String = keyValue[0].replacingOccurrences(of: "/server:", with: "")
                    
                    // Login Flow NC 12
                    if (NCBrandOptions.sharedInstance.use_login_web_personalized == false && serverUrl.hasPrefix("http://") == false && serverUrl.hasPrefix("https://") == false) {
                        serverUrl = urlBase
                    }
                    
                    if (serverUrl.last == "/") {
                        serverUrl = String(serverUrl.dropLast())
                    }
            
                    let username : String = keyValue[1].replacingOccurrences(of: "user:", with: "")
                    let password : String = keyValue[2].replacingOccurrences(of: "password:", with: "")
                
                    let account : String = "\(username) \(serverUrl)"
                
                    // Login Flow
                    if (loginType == loginModifyPasswordUser && NCBrandOptions.sharedInstance.use_login_web_personalized == false) {
                        
                        // Verify if change the active account
                        guard let activeAccount = NCManageDatabase.sharedInstance.getAccountActive() else {
                            self.viewController?.dismiss(animated: true, completion: nil)
                            return
                        }
                        if (activeAccount.account != account) {
                            self.viewController?.dismiss(animated: true, completion: nil)
                            return
                        }
                        
                        // Change Password
                        guard let tableAccount = NCManageDatabase.sharedInstance.setAccountPassword(account, password: password) else {
                            self.viewController?.dismiss(animated: true, completion: nil)
                            return
                        }
                        
                        appDelegate.settingActiveAccount(account, activeUrl: serverUrl, activeUser: username, activeUserID: tableAccount.userID, activePassword: password)
                        self.delegate?.loginSuccess(NSInteger(loginType.rawValue))
                        
                        self.viewController?.dismiss(animated: true, completion: nil)
                    }
                    
                    if (loginType == loginAdd || loginType == loginAddForced) {
                        
                        // Add new account
                        NCManageDatabase.sharedInstance.deleteAccount(account)
                        NCManageDatabase.sharedInstance.addAccount(account, url: serverUrl, user: username, password: password, loginFlow: true)
                        
                        guard let tableAccount = NCManageDatabase.sharedInstance.setAccountActive(account) else {
                            self.viewController?.dismiss(animated: true, completion: nil)
                            return
                        }
                        
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


