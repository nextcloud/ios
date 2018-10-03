//
//  NCTrash.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//

import Foundation

class NCTrash: UICollectionViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var path = ""

    //NSString *userID = [_userID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
    //NSString *serverPath = [NSString stringWithFormat:@"%@%@/%@trashbin/%@/trash", serverUrl, k_dav, path, userID];
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if path == "" {
            let userID = (appDelegate.activeUserID as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed)
            path = appDelegate.activeUrl + k_dav + "/trashbin/" + userID! + "/trash"
        }
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        ocNetworking?.listingTrash(path, account: appDelegate.activeAccount, success: { (item) in
            
        }, failure: { (message, errorCode) in
            
        })
    }
    
    
}
