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
    @objc static let shared: NCBrandConfiguration = {
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
    @objc static let shared: NCBrandOptions = {
        let instance = NCBrandOptions()
        return instance
    }()
    
    @objc public var brand:                             String = "Nextcloud"
    @objc public var mailMe:                            String = "ios@nextcloud.com"
    @objc public var textCopyrightNextcloudiOS:         String = "Nextcloud Coherence for iOS %@ © 2021"
    @objc public var textCopyrightNextcloudServer:      String = "Nextcloud Server %@"
    @objc public var loginBaseUrl:                      String = "https://cloud.nextcloud.com"
    @objc public var pushNotificationServerProxy:       String = "https://push-notifications.nextcloud.com"
    @objc public var linkLoginHost:                     String = "https://nextcloud.com/install"
    @objc public var linkloginPreferredProviders:       String = "https://nextcloud.com/signup-ios";
    @objc public var webLoginAutenticationProtocol:     String = "nc://"                                            // example "abc://"
    @objc public var privacy:                           String = "https://nextcloud.com/privacy"
    @objc public var sourceCode:                        String = "https://github.com/nextcloud/ios"

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
    @objc public var disable_crash_service:             Bool = false
    @objc public var disable_request_account:           Bool = false

    override init() {
        
        if folderBrandAutoUpload != "" {
            folderDefaultAutoUpload = folderBrandAutoUpload
        }
    }
}

//MARK: - Color

class NCBrandColor: NSObject {
    @objc static let shared: NCBrandColor = {
        let instance = NCBrandColor()
        instance.createImagesThemingColor()
        return instance
    }()
    
    struct cacheImages {
        static var file = UIImage()

        static var shared = UIImage()
        static var canShare = UIImage()
        static var shareByLink = UIImage()
        
        static var favorite = UIImage()
        static var comment = UIImage()
        static var livePhoto = UIImage()
        static var offlineFlag = UIImage()
        static var local = UIImage()

        static var folderEncrypted = UIImage()
        static var folderSharedWithMe = UIImage()
        static var folderPublic = UIImage()
        static var folderGroup = UIImage()
        static var folderExternal = UIImage()
        static var folderAutomaticUpload = UIImage()
        static var folder = UIImage()
        
        static var checkedYes = UIImage()
        static var checkedNo = UIImage()
        
        static var buttonMore = UIImage()
        static var buttonStop = UIImage()
    }

    // Color
    @objc public let customer:              UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    @objc public var customerText:          UIColor = .white
    
    @objc public var brand:                 UIColor                                                                                 // don't touch me
    @objc public var brandElement:          UIColor                                                                                 // don't touch me
    @objc public var brandText:             UIColor                                                                                 // don't touch me

    @objc public var connectionNo:          UIColor = UIColor(red: 204.0/255.0, green: 204.0/255.0, blue: 204.0/255.0, alpha: 1.0)
    @objc public var encrypted:             UIColor = .red
    
    @objc public var systemBackground:        UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemBackground
            } else {
                return .white
            }
        }
    }
    
    @objc public var backgroundViewForm:    UIColor = .white
    @objc public var backgroundSettings:    UIColor = UIColor(red: 242.0/255.0, green: 242.0/255.0, blue: 247.0/255.0, alpha: 1.0)  // Gray (6) Light
    @objc public var cellSettings:          UIColor = .white
    @objc public var textView:              UIColor = .black
    @objc public var separator:             UIColor = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
    @objc public var tabBar:                UIColor = .white
    @objc public var navigationBar:         UIColor = .white
    @objc public let nextcloud:             UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)
    @objc public let nextcloudSoft:         UIColor = UIColor(red: 90.0/255.0, green: 160.0/255.0, blue: 210.0/255.0, alpha: 1.0)
    @objc public let icon:                  UIColor = UIColor(red: 104.0/255.0, green: 104.0/255.0, blue: 104.0/255.0, alpha: 1.0)
    @objc public let optionItem:            UIColor = UIColor(red: 178.0/255.0, green: 178.0/255.0, blue: 178.0/255.0, alpha: 1.0)
    @objc public let graySoft:              UIColor = UIColor(red: 162.0/255.0, green: 162.0/255.0, blue: 162.0/255.0, alpha: 0.5)
    @objc public let yellowFavorite:        UIColor = UIColor(red: 248.0/255.0, green: 205.0/255.0, blue: 70.0/255.0, alpha: 1.0)
    @objc public let textInfo:              UIColor = UIColor(red: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 1.0)
    @objc public var select:                UIColor = .lightGray
    @objc public var avatarBorder:          UIColor = .white

    override init() {
        self.brand = self.customer
        self.brandElement = self.customer
        self.brandText = self.customerText        
    }
    
    private func createImagesThemingColor() {
        
        cacheImages.file = UIImage.init(named: "file")!
        
        cacheImages.shared = UIImage(named: "share")!.image(color: graySoft, size: 50)
        cacheImages.canShare = UIImage(named: "share")!.image(color: graySoft, size: 50)
        cacheImages.shareByLink = UIImage(named: "sharebylink")!.image(color: graySoft, size: 50)
        
        cacheImages.favorite = NCUtility.shared.loadImage(named: "star.fill", color: yellowFavorite)
        cacheImages.comment = UIImage(named: "comment")!.image(color: graySoft, size: 50)
        cacheImages.livePhoto = NCUtility.shared.loadImage(named: "livephoto", color: textView)
        cacheImages.offlineFlag = UIImage.init(named: "offlineFlag")!
        cacheImages.local = UIImage.init(named: "local")!
            
        let folderWidth: CGFloat = UIScreen.main.bounds.width / 3
        cacheImages.folderEncrypted = UIImage(named: "folderEncrypted")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderSharedWithMe = UIImage(named: "folder_shared_with_me")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderPublic = UIImage(named: "folder_public")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderGroup = UIImage(named: "folder_group")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderExternal = UIImage(named: "folder_external")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderAutomaticUpload = UIImage(named: "folderAutomaticUpload")!.image(color: brandElement, size: folderWidth)
        cacheImages.folder =  UIImage(named: "folder")!.image(color: brandElement, size: folderWidth)
        
        cacheImages.checkedYes = NCUtility.shared.loadImage(named: "checkmark.circle.fill", color: .darkGray)
        cacheImages.checkedNo = NCUtility.shared.loadImage(named: "circle", color: graySoft)
        
        cacheImages.buttonMore = UIImage(named: "more")!.image(color: graySoft, size: 50)
        cacheImages.buttonStop = UIImage(named: "stop")!.image(color: graySoft, size: 50)
    }
    
    @objc public func setDarkMode(_ dark: Bool) {

        if dark {
            
            tabBar = UIColor(red: 28.0/255.0, green: 28.0/255.0, blue: 30.0/255.0, alpha: 1.0)                          // Gray (6) Dark
            navigationBar = .black
            
            backgroundViewForm = UIColor(red: 28.0/255.0, green: 28.0/255.0, blue: 30.0/255.0, alpha: 1.0)              // Gray (6) Dark
            textView = .white

            cellSettings = UIColor(red: 28.0/255.0, green: 28.0/255.0, blue: 30.0/255.0, alpha: 1.0)                    // Gray (6) Dark
            backgroundSettings = .black
            
            separator = UIColor(red: 60.0/255.0, green: 60.0/255.0, blue: 60.0/255.0, alpha: 1.0)
            select = UIColor.white.withAlphaComponent(0.2)
            avatarBorder = .black
            
        } else {
            
            tabBar = .white
            navigationBar = .white
            
            backgroundViewForm = .white
            textView = .black

            backgroundSettings = UIColor(red: 242.0/255.0, green: 242.0/255.0, blue: 247.0/255.0, alpha: 1.0)           // Gray (6) Light
            cellSettings = .white
            
            separator = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
            select = self.brandElement.withAlphaComponent(0.1)
            avatarBorder = .white
        }
    }
    
#if !EXTENSION
    public func settingThemingColor(account: String) {
        
        let darker: CGFloat = 30    // %
        let lighter: CGFloat = 30   // %

        if NCBrandOptions.shared.use_themingColor {
            
            let themingColor = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesThemingColor)
            
            let themingColorElement = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesThemingColorElement)
            
            let themingColorText = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesThemingColorText)
            
            settingBrandColor(themingColor, themingColorElement: themingColorElement, themingColorText: themingColorText)
                        
            if NCBrandColor.shared.brandElement.isTooLight() {
                if let color = NCBrandColor.shared.brandElement.darker(by: darker) {
                    NCBrandColor.shared.brandElement = color
                }
            } else if NCBrandColor.shared.brandElement.isTooDark() {
                if let color = NCBrandColor.shared.brandElement.lighter(by: lighter) {
                    NCBrandColor.shared.brandElement = color
                }
            }           
            
        } else {
            
            if NCBrandColor.shared.customer.isTooLight() {
                if let color = NCBrandColor.shared.customer.darker(by: darker) {
                    NCBrandColor.shared.brandElement = color
                }
            } else if NCBrandColor.shared.customer.isTooDark() {
                if let color = NCBrandColor.shared.customer.lighter(by: lighter) {
                    NCBrandColor.shared.brandElement = color
                }
            } else {
                NCBrandColor.shared.brandElement = NCBrandColor.shared.customer
            }
            
            NCBrandColor.shared.brand = NCBrandColor.shared.customer
            NCBrandColor.shared.brandText = NCBrandColor.shared.customerText
        }
                
        DispatchQueue.main.async {
            self.createImagesThemingColor()
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeTheming)
        }
    }
#endif
    
    @objc func settingBrandColor(_ themingColor: String?, themingColorElement: String?, themingColorText: String?) {
                
        // COLOR
        if themingColor?.first == "#" {
            if let color = UIColor(hex: themingColor!) {
                NCBrandColor.shared.brand = color
            } else {
                NCBrandColor.shared.brand = NCBrandColor.shared.customer
            }
        } else {
            NCBrandColor.shared.brand = NCBrandColor.shared.customer
        }
        
        // COLOR TEXT
        if themingColorText?.first == "#" {
            if let color = UIColor(hex: themingColorText!) {
                NCBrandColor.shared.brandText = color
            } else {
                NCBrandColor.shared.brandText = NCBrandColor.shared.customerText
            }
        } else {
            NCBrandColor.shared.brandText = NCBrandColor.shared.customerText
        }
        
        // COLOR ELEMENT
        if themingColorElement?.first == "#" {
            if let color = UIColor(hex: themingColorElement!) {
                NCBrandColor.shared.brandElement = color
            } else {
                NCBrandColor.shared.brandElement = NCBrandColor.shared.brand
            }
        } else {
            NCBrandColor.shared.brandElement = NCBrandColor.shared.brand
        }
    }
}
