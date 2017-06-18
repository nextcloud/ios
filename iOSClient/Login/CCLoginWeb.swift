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

    enum enumLoginType : NSInteger {
        case loginAdd = 0
        case loginAddForced = 1
        case loginModifyPasswordUser = 2
    }
    
    weak var delegate: CCLoginDelegate?
    
    var viewController : UIViewController?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var loginType = loginAdd
    var doneButtonVisible: Bool = false
    
    func presentModalWithDefaultTheme(_ vc: UIViewController) {
        
        self.viewController = vc
        
        if (loginType == loginAdd || loginType == loginModifyPasswordUser) {
            doneButtonVisible = true
        }
        
        let webVC = SwiftModalWebVC(urlString: NCBrandOptions.sharedInstance.loginBaseUrl, theme: .custom, color: NCBrandColor.sharedInstance.brand, colorText: NCBrandColor.sharedInstance.navigationBarText, doneButtonVisible: doneButtonVisible, hideToolbar: true)
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
                    
                    if (serverUrl.characters.last == "/") {
                        serverUrl = String(serverUrl.characters.dropLast())
                    }
                
                    let username : String = keyValue[1].replacingOccurrences(of: "user:", with: "")
                    let password : String = keyValue[2].replacingOccurrences(of: "password:", with: "")
                
                    let account : String = "\(username) \(serverUrl)"
                
                    NCManageDatabase.sharedInstance.deleteAccount(account)
                    NCManageDatabase.sharedInstance.addAccount(account, url: serverUrl, user: username, password: password)
                                    
                    let tableAccount : tableAccount = NCManageDatabase.sharedInstance.setAccountActive(account)
                
                    if (tableAccount.account == account) {
                    
                        appDelegate.settingActiveAccount(account, activeUrl: serverUrl, activeUser: username, activePassword: password)
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
}


