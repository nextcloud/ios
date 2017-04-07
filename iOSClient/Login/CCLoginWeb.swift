//
//  CCLoginWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import UIKit

public protocol CCLoginDelegate: class {
    func loginSuccess(loginType: Int)
}

class CCLoginWeb: UIViewController {

    var viewController : UIViewController?
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    public weak var delegate: CCLoginDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func presentModalWithDefaultTheme(_ vc: UIViewController) {
        
        self.viewController = vc
        
        let webVC = SwiftModalWebVC(urlString: k_loginBaseUrl, theme: .loginWeb)
        webVC.delegateWeb = self
        vc.present(webVC, animated: true, completion: nil)
    }
}

extension CCLoginWeb: SwiftModalWebVCDelegate {
    
    func didStartLoading() {
        print("Started loading.")
    }
    
    func didReceiveServerRedirectForProvisionalNavigation(url: URL) {
        
        let urlString: String = url.absoluteString
        
        if (urlString.contains(k_webLoginAutenticationProtocol) == true) {
            
            let keyValue = url.path.components(separatedBy: "&")
            if (keyValue.count == 3) {
                
                let serverUrl : String = String(keyValue[0].replacingOccurrences(of: "/server:", with: "").characters.dropLast())
                let username : String = keyValue[1].replacingOccurrences(of: "user:", with: "")
                let password : String = keyValue[2].replacingOccurrences(of: "password:", with: "")
                
                let account : String = "\(username) \(serverUrl)"
                
                CCCoreData.addAccount(account, url: serverUrl, user: username, password: password)
                appDelegate.settingActiveAccount(account, activeUrl: serverUrl, activeUser: username, activePassword: password)
                
                self.delegate?.loginSuccess(loginType: 0)
                
                self.viewController?.dismiss(animated: true, completion: nil)
            }
        }
    }

    func didFinishLoading(success: Bool, url: URL) {
        print("Finished loading. Success: \(success).")
    }
}


