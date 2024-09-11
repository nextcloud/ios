//
//  NCBrand-IONOS.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 26.06.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation
import UIKit

@objc class NCBrandOptionsIONOS: NCBrandOptions {
    
    override init() {
        super.init()
        
        brand = "IONOS"
        loginBaseUrl = "https://nextcloud-aio.iocaste45.de"

        disable_intro = true
        disable_request_login_url = true

        capabilitiesGroup = "group.com.viseven.ionos.easystorage"
    }
}

class NCBrandColorIONOS: NCBrandColor {
    
	override var menuIconColor: UIColor {
		UIColor(named: "FileMenu/Icon") ?? iconImageColor
	}
	
	override var menuFolderIconColor: UIColor {
		UIColor(named: "FileMenu/FolderIcon") ?? iconImageColor
	}
	
    override init() {
        super.init()
    }
    
    override func settingThemingColor(account: String) {
        super.settingThemingColor(account: account)
        // it's the stub to ignore the server's theme color until
        // the portal will have banned setting theme color by a user
        // and set the IONOS theme color for all users
        self.brandElement = UIColor(red: 20.0 / 255.0, green: 116.0 / 255.0, blue: 196.0 / 255.0, alpha: 1.0) // BLUE IONOS : #1474C4
    }
}
