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
        
        brand = "IONOS HiDrive Next"
        loginBaseUrl = "https://easy-qa-1.nextcloud-ionos.com"

        disable_intro = true
        disable_request_login_url = true
        disable_crash_service = true

#if BETA
        capabilitiesGroup = "group.de.strato.ionos.easystorage.beta"
#elseif APPSTORE
        capabilitiesGroup = "group.com.ionos.hidrivenext"
#else
        capabilitiesGroup = "group.com.viseven.ionos.easystorage"
#endif
    }
}

class NCBrandColorIONOS: NCBrandColor {
    
	override var menuIconColor: UIColor {
		UIColor(named: "FileMenu/Icon") ?? iconImageColor
	}
	
	override var menuFolderIconColor: UIColor {
		UIColor(named: "FileMenu/FolderIcon") ?? iconImageColor
	}
    
    override var appBackgroundColor: UIColor {
        UIColor(named: "AppBackground/Main") ?? super.appBackgroundColor
    }
    
    override var formBackgroundColor: UIColor {
        UIColor(named: "AppBackground/Form") ?? super.formBackgroundColor
    }
    
    override var formRowBackgroundColor: UIColor {
        UIColor(named: "AppBackground/FormRow") ?? super.formRowBackgroundColor
    }
    
    override var formSeparatorColor: UIColor {
        UIColor(named: "formSeparator") ?? super.formSeparatorColor
    }
    
    override var switchColor: UIColor {
        return UIColor { traits in
            let light = self.brandElement
            let dark = UIColor(red: 17.0 / 255.0, green: 199.0 / 255.0, blue: 230.0 / 255.0, alpha: 1.0)
            return traits.userInterfaceStyle == .dark ? dark : light
        }
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
