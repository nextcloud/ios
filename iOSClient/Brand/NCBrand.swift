//
//  NCBrandColor.swift
//  Nextcloud
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

//MARK: - Configuration

@objc class NCBrandConfiguration: NSObject {
    @objc static let sharedInstance: NCBrandConfiguration = {
        let instance = NCBrandConfiguration()
        return instance
    }()
    
    @objc public let configuration_bundleId:            String = "it.twsweb.Nextcloud"
    @objc public let configuration_serverUrl:           String = "serverUrl"
    @objc public let configuration_username:            String = "username"
    @objc public let configuration_password:            String = "password"
}

//MARK: - Options

@objc class NCBrandOptions: NSObject {
    @objc static let sharedInstance: NCBrandOptions = {
        let instance = NCBrandOptions()
        return instance
    }()
    
    @objc public var brand:                             String = "Nextcloud"
    @objc public var mailMe:                            String = "ios@nextcloud.com"
    @objc public var textCopyrightNextcloudiOS:         String = "Nextcloud Coherence for iOS %@ © 2020"
    @objc public var textCopyrightNextcloudServer:      String = "Nextcloud Server %@"
    @objc public var loginBaseUrl:                      String = "https://cloud.nextcloud.com"
    @objc public var pushNotificationServerProxy:       String = "https://push-notifications.nextcloud.com"
    @objc public var linkLoginHost:                     String = "https://nextcloud.com/install"
    @objc public var linkloginPreferredProviders:       String = "https://nextcloud.com/signup";
    @objc public var webLoginAutenticationProtocol:     String = "nc://"                                            // example "abc://"
    // Personalized
    @objc public var webCloseViewProtocolPersonalized:  String = ""                                                 // example "abc://change/plan"      Don't touch me !!
    @objc public var folderBrandAutoUpload:             String = ""                                                 // example "_auto_upload_folder_"   Don't touch me !!
    
    // Auto Upload default folder
    @objc public var folderDefaultAutoUpload:           String = "Photos"
    
    // Capabilities Group
    @objc public var capabilitiesGroups:                String = "group.it.twsweb.Crypto-Cloud"
    
    // User Agent
    @objc public var userAgent:                         String = "Nextcloud-iOS"                                    // Don't touch me !!
    
    // Options
    @objc public var use_login_web_personalized:        Bool = false                                                // Don't touch me !!
    @objc public var use_default_auto_upload:           Bool = false
    @objc public var use_themingColor:                  Bool = true
    //@objc public var use_themingBackground:             Bool = true                                               // Deprecated
    @objc public var use_themingLogo:                   Bool = false
    @objc public var use_storeLocalAutoUploadAll:       Bool = false
    @objc public var use_configuration:                 Bool = false                                                // Don't touch me !!
    @objc public var use_loginflowv2:                   Bool = false                                                // Don't touch me !!

    @objc public var disable_intro:                     Bool = false
    @objc public var disable_request_login_url:         Bool = false
    @objc public var disable_multiaccount:              Bool = false
    @objc public var disable_manage_account:            Bool = false
    @objc public var disable_more_external_site:        Bool = false
    @objc public var disable_openin_file:               Bool = false                                                // Don't touch me !!
    @objc public var disable_crash_service:             Bool = true
    
    override init() {
        
        if folderBrandAutoUpload != "" {
            folderDefaultAutoUpload = folderBrandAutoUpload
        }
    }
}

//MARK: - Color

class NCBrandColor: NSObject {
    @objc static let sharedInstance: NCBrandColor = {
        let instance = NCBrandColor()
        instance.setDarkMode()
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
    @objc public var backgroundCell:        UIColor = .white
    @objc public var backgroundForm:        UIColor = UIColor(red: 244.0/255.0, green: 244.0/255.0, blue: 244.0/255.0, alpha: 1.0)
    @objc public var textView:              UIColor = .black
    @objc public var separator:             UIColor = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
    @objc public var tabBar:                UIColor = .white
    @objc public let nextcloud:             UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)
    @objc public let nextcloudSoft:         UIColor = UIColor(red: 90.0/255.0, green: 160.0/255.0, blue: 210.0/255.0, alpha: 1.0)
    @objc public let icon:                  UIColor = UIColor(red: 104.0/255.0, green: 104.0/255.0, blue: 104.0/255.0, alpha: 1.0)
    @objc public let optionItem:            UIColor = UIColor(red: 178.0/255.0, green: 178.0/255.0, blue: 178.0/255.0, alpha: 1.0)
    @objc public let graySoft:              UIColor = UIColor(red: 162.0/255.0, green: 162.0/255.0, blue: 162.0/255.0, alpha: 0.5)
    @objc public let yellowFavorite:        UIColor = UIColor(red: 248.0/255.0, green: 205.0/255.0, blue: 70.0/255.0, alpha: 1.0)
    @objc public let textInfo:              UIColor = UIColor(red: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 1.0)
    @objc public var select:                UIColor = .white

    override init() {
        self.brand = self.customer
        self.brandElement = self.customer
        self.brandText = self.customerText        
    }
    
    @objc public func setDarkMode() {
        let darkMode = CCUtility.getDarkMode()
        if darkMode {
            tabBar = UIColor(red: 25.0/255.0, green: 25.0/255.0, blue: 25.0/255.0, alpha: 1.0)
            backgroundView = .black
            backgroundCell = UIColor(red: 25.0/255.0, green: 25.0/255.0, blue: 25.0/255.0, alpha: 1.0)
            backgroundForm = .black
            textView = .white
            separator = UIColor(red: 60.0/255.0, green: 60.0/255.0, blue: 60.0/255.0, alpha: 1.0)
            select = UIColor.white.withAlphaComponent(0.2)
        } else {
            tabBar = .white
            backgroundView = .white
            backgroundCell = .white
            backgroundForm = UIColor(red: 247.0/255.0, green: 247.0/255.0, blue: 247.0/255.0, alpha: 1.0)
            textView = .black
            separator = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
            select = self.brandElement.withAlphaComponent(0.1)
        }
    }
    
#if !EXTENSION
    @objc public func settingThemingColor() {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let darker: CGFloat = 30    // %
        let lighter: CGFloat = 30   // %

        if NCBrandOptions.sharedInstance.use_themingColor {
            
            let themingColor = NCManageDatabase.sharedInstance.getCapabilitiesServerString(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesThemingColor)
            
            let themingColorElement = NCManageDatabase.sharedInstance.getCapabilitiesServerString(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesThemingColorElement)
            
            let themingColorText = NCManageDatabase.sharedInstance.getCapabilitiesServerString(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesThemingColorText)
            
            CCGraphics.settingThemingColor(themingColor, themingColorElement: themingColorElement, themingColorText: themingColorText)
                        
            if NCBrandColor.sharedInstance.brandElement.isTooLight() {
                if let color = NCBrandColor.sharedInstance.brandElement.darker(by: darker) {
                    NCBrandColor.sharedInstance.brandElement = color
                }
            } else if NCBrandColor.sharedInstance.brandElement.isTooDark() {
                if let color = NCBrandColor.sharedInstance.brandElement.lighter(by: lighter) {
                    NCBrandColor.sharedInstance.brandElement = color
                }
            }           
            
        } else {
            
            if NCBrandColor.sharedInstance.customer.isTooLight() {
                if let color = NCBrandColor.sharedInstance.customer.darker(by: darker) {
                    NCBrandColor.sharedInstance.brandElement = color
                }
            } else if NCBrandColor.sharedInstance.customer.isTooDark() {
                if let color = NCBrandColor.sharedInstance.customer.lighter(by: lighter) {
                    NCBrandColor.sharedInstance.brandElement = color
                }
            } else {
                NCBrandColor.sharedInstance.brandElement = NCBrandColor.sharedInstance.customer
            }
            
            NCBrandColor.sharedInstance.brand = NCBrandColor.sharedInstance.customer
            NCBrandColor.sharedInstance.brandText = NCBrandColor.sharedInstance.customerText
        }
        
        setDarkMode()
        
        DispatchQueue.main.async {
            NCCollectionCommon.shared.createImagesThemingColor()
            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_changeTheming)
        }
    }
#endif
}
