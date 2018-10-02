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

    override func viewDidLoad() {
        super.viewDidLoad()

        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        ocNetworking?.listingTrashs({ ([Any]?) in

        }, failure: { (message, errorCode) in
           
        })
    }
    
    
}
