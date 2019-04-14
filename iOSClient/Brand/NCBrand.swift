//
//  NCBrandColor.swift
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 24/04/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

class NCBrandColor: NSObject {

    @objc static let sharedInstance: NCBrandColor = {
        let instance = NCBrandColor()
        return instance
    }()

    // Color
    @objc public let customer:              UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    @objc public var customerText:          UIColor = .white
    
    @objc public var brand:                 UIColor                                                                                 // don't touch me
    @objc public var brandElement:          UIColor                                                                                 // don't touch me
    @objc public var brandText:             UIColor                                                                                 // don't touch me

    @objc public var connectionNo:          UIColor = UIColor(red: 204.0/255.0, green: 204.0/255.0, blue: 204.0/255.0, alpha: 1.0)
    @objc public var encrypted:             UIColor = .red
    @objc public var backgroundView:        UIColor = .white
    @objc public var textView:              UIColor = .black
    @objc public var seperator:             UIColor = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
    @objc public var tabBar:                UIColor = .white
    @objc public let nextcloud:             UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)
    @objc public let nextcloudSoft:         UIColor = UIColor(red: 90.0/255.0, green: 160.0/255.0, blue: 210.0/255.0, alpha: 1.0)
    @objc public let icon:                  UIColor = UIColor(red: 104.0/255.0, green: 104.0/255.0, blue: 104.0/255.0, alpha: 1.0)
    @objc public let optionItem:            UIColor = UIColor(red: 178.0/255.0, green: 178.0/255.0, blue: 178.0/255.0, alpha: 1.0)
    @objc public let graySoft:              UIColor = UIColor(red: 162.0/255.0, green: 162.0/255.0, blue: 162.0/255.0, alpha: 0.5)
    @objc public let yellowFavorite:        UIColor = UIColor(red: 248.0/255.0, green: 205.0/255.0, blue: 70.0/255.0, alpha: 1.0)

    override init() {
        self.brand = self.customer
        self.brandElement = self.customer
        self.brandText = self.customerText
    }
    
    // Color modify
    @objc public func getColorSelectBackgrond() -> UIColor {
        return self.brand.withAlphaComponent(0.1)
    }
}

@objc class NCBrandOptions: NSObject {
    
    @objc static let sharedInstance: NCBrandOptions = {
        let instance = NCBrandOptions()
        return instance
    }()
    
    @objc public let brand:                             String = "Nextcloud"
    @objc public var brandInitials:                     String = "nc"
    @objc public let mailMe:                            String = "ios@nextcloud.com"
    @objc public let textCopyrightNextcloudiOS:         String = "Nextcloud for iOS %@ © 2019"
    @objc public let textCopyrightNextcloudServer:      String = "Nextcloud Server %@"
    @objc public let loginBaseUrl:                      String = "https://cloud.nextcloud.com"
    @objc public let pushNotificationServerProxy:       String = "https://push-notifications.nextcloud.com"
    @objc public let linkLoginHost:                     String = "https://nextcloud.com/install"
    @objc public let linkloginPreferredProviders:       String = "https://nextcloud.com/signup";
    @objc public let middlewarePingUrl:                 String = ""
    @objc public let webLoginAutenticationProtocol:     String = "nc://"                                            // example "abc://"
    // Personalized
    @objc public let webCloseViewProtocolPersonalized:  String = ""                                                 // example "abc://change/plan"      Don't touch me !!
    @objc public let folderBrandAutoUpload:             String = ""                                                 // example "_auto_upload_folder_"   Don't touch me !!

    // Auto Upload default folder
    @objc public var folderDefaultAutoUpload:           String = "Photos"
    
    // Capabilities Group
    @objc public let capabilitiesGroups:                String = "group.it.twsweb.Crypto-Cloud"
    
    // Database key 64 char ASCII (for encryption AES-256+SHA2)
    @objc public var databaseEncryptionKey:             String = "1234567890123456789012345678901234567890123456789012345678901234"
    
    // User Agent
    @objc public var userAgent:                         String = "Nextcloud-iOS"                                    // Don't touch me !!
    
    // Options
    @objc public let use_login_web_personalized:        Bool = false                                                // Don't touch me !!
    @objc public let use_default_auto_upload:           Bool = false
    @objc public let use_themingColor:                  Bool = true
    @objc public let use_themingBackground:             Bool = true
    @objc public let use_themingLogo:                   Bool = false     
    @objc public let use_middlewarePing:                Bool = false
    @objc public let use_storeLocalAutoUploadAll:       Bool = false
    @objc public let use_database_encryption:           Bool = false

    @objc public let disable_intro:                     Bool = false
    @objc public let disable_request_login_url:         Bool = false
    @objc public let disable_multiaccount:              Bool = false
    @objc public let disable_manage_account:            Bool = false
    @objc public let disable_more_external_site:        Bool = false
    @objc public let disable_openin_file:               Bool = false                                                // Don't touch me !!

    override init() {
        
        if folderBrandAutoUpload != "" {
            
            folderDefaultAutoUpload = folderBrandAutoUpload
        }
        
        brandInitials = brandInitials.lowercased()
    }
}

