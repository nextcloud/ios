//
//  CCLoginWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import UIKit

class CCLoginWeb: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func presentModalWithDefaultTheme(_ vc: UIViewController) {
                
        let webVC = SwiftModalWebVC(urlString: k_loginBaseUrl, theme: .customLoginWeb, color: UIColor.red)
        webVC.delegateWeb = self
        vc.present(webVC, animated: true, completion: nil)
    }
}

extension CCLoginWeb: SwiftModalWebVCDelegate {
    
    func didStartLoading() {
        print("Started loading.")
    }
    
    func didReceiveServerRedirectForProvisionalNavigation(url: URL) {
        print(url)
    }

    func didFinishLoading(success: Bool, url: URL) {
        print("Finished loading. Success: \(success).")
    }
}


