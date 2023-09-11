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

let userAgent: String = {
    let appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    // Original Nextcloud useragent "Mozilla/5.0 (iOS) Nextcloud-iOS/\(appVersion)"
    return "Mozilla/5.0 (iOS) Nextcloud-iOS/\(appVersion)"
}()

@objc class NCBrandOptions: NSObject {
    @objc static let shared: NCBrandOptions = {
        let instance = NCBrandOptions()
        return instance
    }()

    @objc public var brand: String = "Nextcloud"
    @objc public var textCopyrightNextcloudiOS: String = "Nextcloud Liquid for iOS %@ © 2023"
    @objc public var textCopyrightNextcloudServer: String = "Nextcloud Server %@"
    @objc public var loginBaseUrl: String = "https://cloud.nextcloud.com"
    @objc public var pushNotificationServerProxy: String = "https://push-notifications.nextcloud.com"
    @objc public var linkLoginHost: String = "https://nextcloud.com/install"
    @objc public var linkloginPreferredProviders: String = "https://nextcloud.com/signup-ios"
    @objc public var webLoginAutenticationProtocol: String = "nc://"                                                // example "abc://"
    @objc public var privacy: String = "https://nextcloud.com/privacy"
    @objc public var sourceCode: String = "https://github.com/nextcloud/ios"
    @objc public var mobileconfig: String = "/remote.php/dav/provisioning/apple-provisioning.mobileconfig"

    // Personalized
    @objc public var webCloseViewProtocolPersonalized: String = ""                                                  // example "abc://change/plan"      Don't touch me !!
    @objc public var folderBrandAutoUpload: String = ""                                                             // example "_auto_upload_folder_"   Don't touch me !!

    // Auto Upload default folder
    @objc public var folderDefaultAutoUpload: String = "Photos"

    // Capabilities Group
    @objc public var capabilitiesGroups: String = "group.it.twsweb.Crypto-Cloud"
    @objc public var capabilitiesGroupApps: String = "group.com.nextcloud.apps"

    // BRAND ONLY
    @objc public var use_login_web_personalized: Bool = false                                   // Don't touch me !!
    @objc public var use_AppConfig: Bool = false                                                // Don't touch me !!
    @objc public var use_GroupApps: Bool = true                                                 // Don't touch me !!

    // Options
    @objc public var use_default_auto_upload: Bool = false
    @objc public var use_themingColor: Bool = true
    @objc public var use_themingLogo: Bool = false
    @objc public var use_storeLocalAutoUploadAll: Bool = false
    @objc public var use_loginflowv2: Bool = false                                              // Don't touch me !!

    @objc public var disable_intro: Bool = false
    @objc public var disable_request_login_url: Bool = false
    @objc public var disable_multiaccount: Bool = false
    @objc public var disable_manage_account: Bool = false
    @objc public var disable_more_external_site: Bool = false
    @objc public var disable_openin_file: Bool = false                                          // Don't touch me !!
    @objc public var disable_crash_service: Bool = false
    @objc public var disable_log: Bool = false
    @objc public var disable_mobileconfig: Bool = false
    @objc public var disable_show_more_nextcloud_apps_in_settings: Bool = false

    // Internal option behaviour
    @objc public var cleanUpDay: Int = 0                                                        // Set default "Delete, in the cache, all files older than" possible days value are: 0, 1, 7, 30, 90, 180, 365

    // Info Paging
    enum NCInfoPagingTab: Int, CaseIterable {
        case activity, sharing
    }

    override init() {

        if folderBrandAutoUpload != "" {
            folderDefaultAutoUpload = folderBrandAutoUpload
        }

        // wrapper AppConfig
        if let configurationManaged = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed"), use_AppConfig {

            if let str = configurationManaged[NCGlobal.shared.configuration_brand] as? String {
                brand = str
            }
            if let str = configurationManaged[NCGlobal.shared.configuration_disable_intro] as? String {
                disable_intro = (str as NSString).boolValue
            }
            if let str = configurationManaged[NCGlobal.shared.configuration_disable_multiaccount] as? String {
                disable_multiaccount = (str as NSString).boolValue
            }
            if let str = configurationManaged[NCGlobal.shared.configuration_disable_crash_service] as? String {
                disable_crash_service = (str as NSString).boolValue
            }
            if let str = configurationManaged[NCGlobal.shared.configuration_disable_log] as? String {
                disable_log = (str as NSString).boolValue
            }
            if let str = configurationManaged[NCGlobal.shared.configuration_disable_manage_account] as? String {
                disable_manage_account = (str as NSString).boolValue
            }
            if let str = configurationManaged[NCGlobal.shared.configuration_disable_more_external_site] as? String {
                disable_more_external_site = (str as NSString).boolValue
            }
            if let str = configurationManaged[NCGlobal.shared.configuration_disable_openin_file] as? String {
                disable_openin_file = (str as NSString).boolValue
            }
        }
    }

    @objc func getUserAgent() -> String {
        return userAgent
    }
}

class NCBrandColor: NSObject {
    @objc static let shared: NCBrandColor = {
        let instance = NCBrandColor()
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
        static var buttonMoreLock = UIImage()
        static var buttonRestore = UIImage()
        static var buttonTrash = UIImage()

        static var iconContacts = UIImage()
        static var iconTalk = UIImage()
        static var iconCalendar = UIImage()
        static var iconDeck = UIImage()
        static var iconMail = UIImage()
        static var iconConfirm = UIImage()
        static var iconPages = UIImage()
    }

    // Color
    @objc public let customer: UIColor = UIColor(red: 0.0 / 255.0, green: 130.0 / 255.0, blue: 201.0 / 255.0, alpha: 1.0)         // BLU NC : #0082c9
    @objc public var customerText: UIColor = .white

    @objc public var brand: UIColor                                                                                         // don't touch me
    @objc public var brandElement: UIColor                                                                                  // don't touch me
    @objc public var brandText: UIColor                                                                                     // don't touch me

    @objc public let nextcloud: UIColor = UIColor(red: 0.0 / 255.0, green: 130.0 / 255.0, blue: 201.0 / 255.0, alpha: 1.0)
    @objc public let yellowFavorite: UIColor = UIColor(red: 248.0 / 255.0, green: 205.0 / 255.0, blue: 70.0 / 255.0, alpha: 1.0)

    public var userColors: [CGColor] = []
    public var themingColor: String = ""
    public var themingColorElement: String = ""
    public var themingColorText: String = ""

    @objc public var systemMint: UIColor {
        get {
            return UIColor(red: 0.0 / 255.0, green: 199.0 / 255.0, blue: 190.0 / 255.0, alpha: 1.0)
        }
    }

    override init() {
        brand = customer
        brandElement = customer
        brandText = customerText
    }

    func createUserColors() {
        userColors = generateColors()
    }

    func createImagesThemingColor() {

        cacheImages.file = UIImage(named: "file")!

        cacheImages.shared = UIImage(named: "share")!.image(color: .systemGray, size: 50)
        cacheImages.canShare = UIImage(named: "share")!.image(color: .systemGray, size: 50)
        cacheImages.shareByLink = UIImage(named: "sharebylink")!.image(color: .systemGray, size: 50)

        cacheImages.favorite = NCUtility.shared.loadImage(named: "star.fill", color: yellowFavorite)
        cacheImages.comment = UIImage(named: "comment")!.image(color: .systemGray, size: 50)
        cacheImages.livePhoto = NCUtility.shared.loadImage(named: "livephoto", color: .label)
        cacheImages.offlineFlag = UIImage(named: "offlineFlag")!
        cacheImages.local = UIImage(named: "local")!

        let folderWidth: CGFloat = UIScreen.main.bounds.width / 3
        cacheImages.folderEncrypted = UIImage(named: "folderEncrypted")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderSharedWithMe = UIImage(named: "folder_shared_with_me")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderPublic = UIImage(named: "folder_public")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderGroup = UIImage(named: "folder_group")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderExternal = UIImage(named: "folder_external")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderAutomaticUpload = UIImage(named: "folderAutomaticUpload")!.image(color: brandElement, size: folderWidth)
        cacheImages.folder = UIImage(named: "folder")!.image(color: brandElement, size: folderWidth)

        cacheImages.checkedYes = NCUtility.shared.loadImage(named: "checkmark.circle.fill", color: .systemBlue)
        cacheImages.checkedNo = NCUtility.shared.loadImage(named: "circle", color: .systemGray)

        cacheImages.buttonMore = UIImage(named: "more")!.image(color: .systemGray, size: 50)
        cacheImages.buttonStop = UIImage(named: "stop")!.image(color: .systemGray, size: 50)
        cacheImages.buttonMoreLock = UIImage(named: "moreLock")!.image(color: .systemGray, size: 50)
        cacheImages.buttonRestore = UIImage(named: "restore")!.image(color: .systemGray, size: 50)
        cacheImages.buttonTrash = UIImage(named: "trash")!.image(color: .systemGray, size: 50)

        cacheImages.iconContacts = UIImage(named: "icon-contacts")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconTalk = UIImage(named: "icon-talk")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconCalendar = UIImage(named: "icon-calendar")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconDeck = UIImage(named: "icon-deck")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconMail = UIImage(named: "icon-mail")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconConfirm = UIImage(named: "icon-confirm")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconPages = UIImage(named: "icon-pages")!.image(color: brandElement, size: folderWidth)
    }

    func settingThemingColor(account: String) {

        let darker: CGFloat = 30    // %
        let lighter: CGFloat = 30   // %

        if NCBrandOptions.shared.use_themingColor {

            self.themingColor = NCGlobal.shared.capabilityThemingColor
            self.themingColorElement = NCGlobal.shared.capabilityThemingColorElement
            self.themingColorText = NCGlobal.shared.capabilityThemingColorText

            // COLOR
            if themingColor.first == "#" {
                if let color = UIColor(hex: themingColor) {
                    brand = color
                } else {
                    brand = customer
                }
            } else {
                brand = customer
            }

            // COLOR TEXT
            if themingColorText.first == "#" {
                if let color = UIColor(hex: themingColorText) {
                    brandText = color
                } else {
                    brandText = customerText
                }
            } else {
                brandText = customerText
            }

            // COLOR ELEMENT
            if themingColorElement.first == "#" {
                if let color = UIColor(hex: themingColorElement) {
                    brandElement = color
                } else {
                    brandElement = brand
                }
            } else {
                brandElement = brand
            }

            if brandElement.isTooLight() {
                if let color = brandElement.darker(by: darker) {
                    brandElement = color
                }
            } else if brandElement.isTooDark() {
                if let color = brandElement.lighter(by: lighter) {
                    brandElement = color
                }
            }

        } else {

            if self.customer.isTooLight() {
                if let color = customer.darker(by: darker) {
                    brandElement = color
                }
            } else if customer.isTooDark() {
                if let color = customer.lighter(by: lighter) {
                    brandElement = color
                }
            } else {
                brandElement = customer
            }

            brand = customer
            brandText = customerText
        }

        createImagesThemingColor()
#if !EXTENSION
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeTheming)
#endif
    }

    private func stepCalc(steps: Int, color1: CGColor, color2: CGColor) -> [CGFloat] {
        var step = [CGFloat](repeating: 0, count: 3)
        step[0] = (color2.components![0] - color1.components![0]) / CGFloat(steps)
        step[1] = (color2.components![1] - color1.components![1]) / CGFloat(steps)
        step[2] = (color2.components![2] - color1.components![2]) / CGFloat(steps)
        return step
    }

    private func mixPalette(steps: Int, color1: CGColor, color2: CGColor) -> [CGColor] {
        var palette = [color1]
        let step = stepCalc(steps: steps, color1: color1, color2: color2)

        let c1Components = color1.components!
        for i in 1 ..< steps {
            let r = c1Components[0] + step[0] * CGFloat(i)
            let g = c1Components[1] + step[1] * CGFloat(i)
            let b = c1Components[2] + step[2] * CGFloat(i)

            palette.append(UIColor(red: r, green: g, blue: b, alpha: 1).cgColor)
        }
        return palette
    }

    /**
     Generate colors from the official nextcloud color.
     You can provide how many colors you want (multiplied by 3).
     if `step` = 6,
     3 colors \* 6 will result in 18 generated colors
     */
    func generateColors(steps: Int = 6) -> [CGColor] {
        let red = UIColor(red: 182 / 255, green: 70 / 255, blue: 157 / 255, alpha: 1).cgColor
        let yellow = UIColor(red: 221 / 255, green: 203 / 255, blue: 85 / 255, alpha: 1).cgColor
        let blue = UIColor(red: 0 / 255, green: 130 / 255, blue: 201 / 255, alpha: 1).cgColor

        let palette1 = mixPalette(steps: steps, color1: red, color2: yellow)
        let palette2 = mixPalette(steps: steps, color1: yellow, color2: blue)
        let palette3 = mixPalette(steps: steps, color1: blue, color2: red)
        return palette1 + palette2 + palette3
    }
}
