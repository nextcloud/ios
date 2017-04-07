//
//  CCLoginWeb.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import UIKit

/*
 - (void)goToWebVC:(CCMenuItem *)sender
 {
 if (self.splitViewController.isCollapsed) {
 
 SwiftWebVC *webVC = [[SwiftWebVC alloc] initWithUrlString:sender.argument];
 [self.navigationController pushViewController:webVC animated:YES];
 
 } else {
 
 SwiftModalWebVC *webVC = [[SwiftModalWebVC alloc] initWithUrlString:sender.argument];
 [self presentViewController:webVC animated:YES completion:nil];
 }
 }
*/

class CCLoginWeb: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func presentModalWithDefaultTheme(_ vc: UIViewController) {
        let webVC = SwiftModalWebVC(urlString: k_loginBaseUrl)
        vc.present(webVC, animated: true, completion: nil)
    }
}


