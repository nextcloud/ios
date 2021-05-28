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
    //@objc public var mailMe:                            String = "ios@nextcloud.com"                              // Deprecated
    @objc public var textCopyrightNextcloudiOS:         String = "Nextcloud Liquid for iOS %@ © 2021"
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
    
    @objc public var disable_background_color:          Bool = false
    @objc public var disable_background_image:          Bool = true

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
        static var buttonRestore = UIImage()
    }

    // Color
    @objc public let customer:              UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)    // BLU NC : #0082c9
    @objc public var customerText:          UIColor = .white
    
    @objc public var brand:                 UIColor                                                                                 // don't touch me
    @objc public var brandElement:          UIColor                                                                                 // don't touch me
    @objc public var brandText:             UIColor                                                                                 // don't touch me
    
    @objc public let nextcloud:             UIColor = UIColor(red: 0.0/255.0, green: 130.0/255.0, blue: 201.0/255.0, alpha: 1.0)
    @objc public let gray:                  UIColor = UIColor(red: 104.0/255.0, green: 104.0/255.0, blue: 104.0/255.0, alpha: 1.0)
    @objc public let lightGray:             UIColor = UIColor(red: 229.0/255.0, green: 229.0/229.0, blue: 104.0/255.0, alpha: 1.0)
    @objc public let yellowFavorite:        UIColor = UIColor(red: 248.0/255.0, green: 205.0/255.0, blue: 70.0/255.0, alpha: 1.0)

    @objc public var systemBackground: UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemBackground
            } else {
                return .white
            }
        }
    }
    @objc public var secondarySystemBackground: UIColor {
        get {
            if #available(iOS 13, *) {
                return .secondarySystemBackground
            } else {
                return UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
            }
        }
    }
    @objc public var tertiarySystemBackground: UIColor {
        get {
            if #available(iOS 13, *) {
                return .tertiarySystemBackground
            } else {
                return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            }
        }
    }
    @objc public var systemGroupedBackground: UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemGroupedBackground
            } else {
                return UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
            }
        }
    }
    @objc public var secondarySystemGroupedBackground: UIColor {
        get {
            if #available(iOS 13, *) {
                return .secondarySystemGroupedBackground
            } else {
                return .white
            }
        }
    }
    @objc public var label: UIColor {
        get {
            if #available(iOS 13, *) {
                return .label
            } else {
                return .black
            }
        }
    }
    @objc public var separator: UIColor {
        get {
            if #available(iOS 13, *) {
                return .separator
            } else {
                return UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1.0)
            }
        }
    }
    @objc public var opaqueSeparator: UIColor {
        get {
            if #available(iOS 13, *) {
                return .opaqueSeparator
            } else {
                return UIColor(red: 0.78, green: 0.78, blue: 0.78, alpha: 1.0)
            }
        }
    }
    @objc public var systemGray: UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemGray
            } else {
                return UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)
            }
        }
    }
    @objc public var systemGray2: UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemGray2
            } else {
                return UIColor(red: 0.68, green: 0.68, blue: 0.7, alpha: 1.0)
            }
        }
    }
    @objc public var systemGray3: UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemGray3
            } else {
                return UIColor(red: 0.78, green: 0.78, blue: 0.8, alpha: 1.0)
            }
        }
    }
    @objc public var systemGray4: UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemGray4
            } else {
                return UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1.0)
            }
        }
    }
    @objc public var systemGray5: UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemGray5
            } else {
                return UIColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1.0)
            }
        }
    }
    @objc public var systemGray6: UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemGray6
            } else {
                return UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
            }
        }
    }
    @objc public var systemFill: UIColor {
        get {
            if #available(iOS 13, *) {
                return .systemFill
            } else {
                return UIColor(red: 120/255, green: 120/255, blue: 120/255, alpha: 1.0)
            }
        }
    }
    
    override init() {
        self.brand = self.customer
        self.brandElement = self.customer
        self.brandText = self.customerText        
    }
    
    public func createImagesThemingColor() {
        
        let gray: UIColor = UIColor(red: 162.0/255.0, green: 162.0/255.0, blue: 162.0/255.0, alpha: 0.5)

        cacheImages.file = UIImage.init(named: "file")!
        
        cacheImages.shared = UIImage(named: "share")!.image(color: gray, size: 50)
        cacheImages.canShare = UIImage(named: "share")!.image(color: gray, size: 50)
        cacheImages.shareByLink = UIImage(named: "sharebylink")!.image(color: gray, size: 50)
        
        cacheImages.favorite = NCUtility.shared.loadImage(named: "star.fill", color: yellowFavorite)
        cacheImages.comment = UIImage(named: "comment")!.image(color: gray, size: 50)
        cacheImages.livePhoto = NCUtility.shared.loadImage(named: "livephoto", color: label)
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
        
        cacheImages.checkedYes = NCUtility.shared.loadImage(named: "checkmark.circle.fill", color: .systemBlue)
        cacheImages.checkedNo = NCUtility.shared.loadImage(named: "circle", color: gray)
        
        cacheImages.buttonMore = UIImage(named: "more")!.image(color: gray, size: 50)
        cacheImages.buttonStop = UIImage(named: "stop")!.image(color: gray, size: 50)
        cacheImages.buttonRestore = UIImage(named: "restore")!.image(color: gray, size: 50)
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
