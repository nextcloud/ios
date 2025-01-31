//
//  NCBrand-IONOS.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 26.06.2024.
//  Copyright © 2024 STRATO GmbH
//

import Foundation
import UIKit

@objc class NCBrandOptionsIONOS: NCBrandOptions {
    
    override init() {
        super.init()
        
        brand = "IONOS HiDrive Next"
        textCopyrightNextcloudiOS = "HiDrive Next iOS %@ © 2024"
        loginBaseUrl = "https://easy-qa-1.nextcloud-ionos.com"
        privacy = "https://wl.hidrive.com/easy/ios/privacy.html"
        sourceCode = "https://wl.hidrive.com/easy/0181"

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

extension NCBrandOptions {
    var acknowloedgements: String {
        "https://wl.hidrive.com/easy/0171"
    }
}

class NCBrandColorIONOS: NCBrandColor {
    
    static let ionosBrand = UIColor(red: 20.0 / 255.0, green: 116.0 / 255.0, blue: 196.0 / 255.0, alpha: 1.0) // BLUE IONOS : #1474C4
	
    override init() {
        super.init()
    }
    
    override func getElement(account: String?) -> UIColor {
        return NCBrandColorIONOS.ionosBrand
    }
}

extension NCBrandColor {
    var brandElement: UIColor {
        return NCBrandColorIONOS.ionosBrand
    }
    
#if !EXTENSION || EXTENSION_SHARE
    var menuIconColor: UIColor {
        UIColor(resource: .FileMenu.icon)
    }
    
    var menuFolderIconColor: UIColor {
        UIColor(resource: .FileMenu.folderIcon)
    }
    
    var appBackgroundColor: UIColor {
        UIColor(resource: .AppBackground.main)
    }
    
    var formBackgroundColor: UIColor {
        UIColor(resource: .AppBackground.form)
    }
    
    var formRowBackgroundColor: UIColor {
        UIColor(resource: .AppBackground.formRow)
    }
    
    var formSeparatorColor: UIColor {
        UIColor(resource: .formSeparator)
    }
#endif
    
    var switchColor: UIColor {
        return UIColor { traits in
            let light = self.brandElement
            let dark = UIColor(red: 17.0 / 255.0, green: 199.0 / 255.0, blue: 230.0 / 255.0, alpha: 1.0)
            return traits.userInterfaceStyle == .dark ? dark : light
        }
    }
}
