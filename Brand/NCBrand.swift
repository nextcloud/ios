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

    var brand: String = "Nextcloud"
    var textCopyrightNextcloudiOS: String = "Nextcloud Hydrogen for iOS %@ © 2024"
    var textCopyrightNextcloudServer: String = "Nextcloud Server %@"
    var loginBaseUrl: String = "https://cloud.nextcloud.com"
    @objc var pushNotificationServerProxy: String = "https://push-notifications.nextcloud.com"
    var linkLoginHost: String = "https://nextcloud.com/install"
    var linkloginPreferredProviders: String = "https://nextcloud.com/signup-ios"
    var webLoginAutenticationProtocol: String = "nc://"                                                // example "abc://"
    var privacy: String = "https://nextcloud.com/privacy"
    var sourceCode: String = "https://github.com/nextcloud/ios"
    var mobileconfig: String = "/remote.php/dav/provisioning/apple-provisioning.mobileconfig"
    var appStoreUrl: String = "https://apps.apple.com/in/app/nextcloud/id1125420102"

    // Auto Upload default folder
    var folderDefaultAutoUpload: String = "Photos"

    // Capabilities Group
    var capabilitiesGroups: String = "group.it.twsweb.Crypto-Cloud"
    var capabilitiesGroupApps: String = "group.com.nextcloud.apps"

    // BRAND ONLY
    @objc public var use_AppConfig: Bool = false                                                // Don't touch me !!

    // Options
    @objc public var use_themingColor: Bool = true

    var disable_intro: Bool = false
    var disable_request_login_url: Bool = false
    var disable_multiaccount: Bool = false
    var disable_more_external_site: Bool = false
    var disable_openin_file: Bool = false                                          // Don't touch me !!
    var disable_crash_service: Bool = false
    var disable_log: Bool = false
    var disable_mobileconfig: Bool = false
    var disable_show_more_nextcloud_apps_in_settings: Bool = false
    var doNotAskPasscodeAtStartup: Bool = false

    // Internal option behaviour
    var cleanUpDay: Int = 0                                                        // Set default "Delete, in the cache, all files older than" possible days value are: 0, 1, 7, 30, 90, 180, 365

    // Max download/upload concurrent
    let maxConcurrentOperationDownload: Int = 5
    let maxConcurrentOperationUpload: Int = 5

    // Number of failed attempts after reset app
    let resetAppPasscodeAttempts: Int = 10
    let passcodeSecondsFail: Int = 60

    // Info Paging
    enum NCInfoPagingTab: Int, CaseIterable {
        case activity, sharing
    }

    override init() {
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
    static let shared: NCBrandColor = {
        let instance = NCBrandColor()
        return instance
    }()

    // Color
    let customer: UIColor = UIColor(red: 0.0 / 255.0, green: 130.0 / 255.0, blue: 201.0 / 255.0, alpha: 1.0)         // BLU NC : #0082c9
    var customerText: UIColor = .white

    var brand: UIColor                                                                                         // don't touch me
    var brandElement: UIColor                                                                                  // don't touch me
    var brandText: UIColor                                                                                     // don't touch me

    let nextcloud: UIColor = UIColor(red: 0.0 / 255.0, green: 130.0 / 255.0, blue: 201.0 / 255.0, alpha: 1.0)
    let yellowFavorite: UIColor = UIColor(red: 248.0 / 255.0, green: 205.0 / 255.0, blue: 70.0 / 255.0, alpha: 1.0)

    var userColors: [CGColor] = []
    var themingColor: String = ""
    var themingColorElement: String = ""
    var themingColorText: String = ""

    let iconImageColor: UIColor = .label
    let iconImageColor2: UIColor = .secondaryLabel
    let iconImageMultiColors: [UIColor] = [.secondaryLabel, .label]

    let textColor: UIColor = .label
    let textColor2: UIColor = .secondaryLabel

    var systemMint: UIColor {
        get {
            return UIColor(red: 0.0 / 255.0, green: 199.0 / 255.0, blue: 190.0 / 255.0, alpha: 1.0)
        }
    }

    var documentIconColor: UIColor {
        get {
            return UIColor(hex: "#49abe9")!
        }
    }

    var spreadsheetIconColor: UIColor {
        get {
            return UIColor(hex: "#9abd4e")!
        }
    }

    var presentationIconColor: UIColor {
        get {
            return UIColor(hex: "#f0965f")!
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
