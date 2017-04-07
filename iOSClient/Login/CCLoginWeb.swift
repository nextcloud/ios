//
//  CCLoginWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import UIKit

@objc protocol CCLoginWebDelegate: class {
    func loginSuccess(_: NSInteger)
}

public class CCLoginWeb: UIViewController {

    weak var delegate: CCLoginWebDelegate?
    
    var viewController : UIViewController?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    public enum enumLoginType : Int {
        case loginAdd = 0, loginAddForced = 1, loginModifyPasswordUser = 2
    }
    
    func presentModalWithDefaultTheme(_ vc: UIViewController) {
        
        self.viewController = vc
        
        let webVC = SwiftModalWebVC(urlString: k_loginBaseUrl, theme: .loginWeb)
        webVC.delegateWeb = self
        vc.present(webVC, animated: true, completion: nil)
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
                
                let serverUrl : String = String(keyValue[0].replacingOccurrences(of: "/server:", with: "").characters.dropLast())
                let username : String = keyValue[1].replacingOccurrences(of: "user:", with: "")
                let password : String = keyValue[2].replacingOccurrences(of: "password:", with: "")
                
                let account : String = "\(username) \(serverUrl)"
                
                CCCoreData.deleteAccount(account)
                CCCoreData.addAccount(account, url: serverUrl, user: username, password: password)
                
                let tableAccount : TableAccount = CCCoreData.setActiveAccount(account)
                
                if (tableAccount.account == account) {
                    
                    appDelegate.settingActiveAccount(account, activeUrl: serverUrl, activeUser: username, activePassword: password)
                    self.delegate?.loginSuccess(0)
                
                    self.viewController?.dismiss(animated: true, completion: nil)
                }
            }
        }
    }

    public func didFinishLoading(success: Bool, url: URL) {
        print("Finished loading. Success: \(success).")
    }
}


