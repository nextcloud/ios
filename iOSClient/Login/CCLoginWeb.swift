//
//  CCLoginWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/04/17.
//  Copyright © 2017 TWS. All rights reserved.
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

import UIKit

@objc protocol CCLoginDelegateWeb: class {
    func loginSuccess(_: NSInteger)
    @objc optional func webDismiss()
}

public class CCLoginWeb: UIViewController {
   
    @objc weak var delegate: CCLoginDelegateWeb?
    @objc var loginType: NSInteger = Int(k_login_Add)
    @objc var urlBase = ""
    
    var viewController: UIViewController?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var doneButtonVisible: Bool = false
    
    @objc func presentModalWithDefaultTheme(_ vc: UIViewController) {
        
        var urlString = urlBase
        self.viewController = vc
        
        if (loginType == k_login_Add || loginType == k_login_Modify_Password) {
            doneButtonVisible = true
        }
        
        // ADD k_flowEndpoint for Web Flow
        if (NCBrandOptions.sharedInstance.use_login_web_personalized == false && urlBase != NCBrandOptions.sharedInstance.loginPreferredProviders) {
            urlString =  urlBase+k_flowEndpoint
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
            
                    let username : String = keyValue[1].replacingOccurrences(of: "user:", with: "").replacingOccurrences(of: "+", with: " ")
                    let password : String = keyValue[2].replacingOccurrences(of: "password:", with: "")
                
                    let account : String = "\(username) \(serverUrl)"
                
                    // Login Flow
                    if (loginType == k_login_Modify_Password && NCBrandOptions.sharedInstance.use_login_web_personalized == false) {
                        
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
                        
                        self.delegate?.loginSuccess(NSInteger(loginType))
                        self.delegate?.webDismiss?()

                        self.viewController?.dismiss(animated: true, completion: nil)
                    }
                    
                    if (loginType == k_login_Add || loginType == k_login_Add_Forced) {
                        
                        // LOGOUT
                        appDelegate.unsubscribingNextcloudServerPushNotification()
                        
                        // Add new account
                        NCManageDatabase.sharedInstance.deleteAccount(account)
                        NCManageDatabase.sharedInstance.addAccount(account, url: serverUrl, user: username, password: password, loginFlow: true)
                        
                        guard let tableAccount = NCManageDatabase.sharedInstance.setAccountActive(account) else {
                            self.viewController?.dismiss(animated: true, completion: nil)
                            return
                        }
                        
                        appDelegate.settingActiveAccount(account, activeUrl: serverUrl, activeUser: username, activeUserID: tableAccount.userID, activePassword: password)
                        
                        self.delegate?.loginSuccess(NSInteger(loginType))
                        self.delegate?.webDismiss?()

                        self.viewController?.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }

    public func didFinishLoading(success: Bool, url: URL) {
        print("Finished loading. Success: \(success).")
    }
    
    public func webDismiss() {
        self.delegate?.webDismiss?()
    }
    
    public func decidePolicyForNavigationAction(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}


