//
//  CCLoginWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import UIKit

@objc protocol CCLoginDelegate: class {
    func loginSuccess(_: NSInteger)
}

public class CCLoginWeb: UIViewController {

    weak var delegate: CCLoginDelegate?
    
    var viewController : UIViewController?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var loginType : NSInteger = 0
    
    func presentModalWithDefaultTheme(_ vc: UIViewController) {
        
        self.viewController = vc
        
        let webVC = SwiftModalWebVC(urlString: k_loginBaseUrl, theme: .custom, color: Constant.GlobalConstants.k_Color_NavigationBar, colorText: Constant.GlobalConstants.k_Color_NavigationBar_Text)
        webVC.delegateWeb = self
        vc.present(webVC, animated: false, completion: nil)
    }
}

extension CCLoginWeb: SwiftModalWebVCDelegate {
    
    public func didStartLoading() {
        print("Started loading.")
    }
    
    public func didReceiveServerRedirectForProvisionalNavigation(url: URL) {
                
        let urlString: String = url.absoluteString
        
        if (urlString.contains(k_webLoginAutenticationProtocol) == true) {
            
            let keyValue = url.path.components(separatedBy: "&")
            if (keyValue.count == 3) {
                
                if (keyValue[0].contains("server:") && keyValue[1].contains("user:") && keyValue[2].contains("password:")) {
                
                    var serverUrl : String = keyValue[0].replacingOccurrences(of: "/server:", with: "")
                    
                    if (serverUrl.characters.last == "/") {
                        serverUrl = String(serverUrl.characters.dropLast())
                    }
                
                    let username : String = keyValue[1].replacingOccurrences(of: "user:", with: "")
                    let password : String = keyValue[2].replacingOccurrences(of: "password:", with: "")
                
                    let account : String = "\(username) \(serverUrl)"
                
                    CCCoreData.deleteAccount(account)
                    CCCoreData.addAccount(account, url: serverUrl, user: username, password: password)
                
                    let tableAccount : TableAccount = CCCoreData.setActiveAccount(account)
                
                    if (tableAccount.account == account) {
                    
                        appDelegate.settingActiveAccount(account, activeUrl: serverUrl, activeUser: username, activePassword: password)
                        self.delegate?.loginSuccess(loginType)
                
                        self.viewController?.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }

    public func didFinishLoading(success: Bool, url: URL) {
        print("Finished loading. Success: \(success).")
    }
}


