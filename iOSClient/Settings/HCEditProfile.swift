//
//  HCEditProfile.swift
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 17/04/19.
//  Copyright (c) 2019 Marino Faggiana. All rights reserved.
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

import Foundation

class HCEditProfile: XLFormViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
        
    func initializeForm() {
        
        let form : XLFormDescriptor = XLFormDescriptor() as XLFormDescriptor
        form.rowNavigationOptions = XLFormRowNavigationOptions.stopDisableRow
        
        var section : XLFormSectionDescriptor
        var row : XLFormRowDescriptor

        let tableAccount = NCManageDatabase.sharedInstance.getAccountActive()
        
        section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        row = XLFormRowDescriptor(tag: "userfullname", rowType: XLFormRowDescriptorTypeText, title: NSLocalizedString("_user_full_name_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "user"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        row.value = tableAccount?.displayName
        section.addFormRow(row)

        row = XLFormRowDescriptor(tag: "useraddress", rowType: XLFormRowDescriptorTypeText, title: NSLocalizedString("_user_address_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "address"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        row.value = tableAccount?.address
        section.addFormRow(row)
        
        row = XLFormRowDescriptor(tag: "usercity", rowType: XLFormRowDescriptorTypeText, title: NSLocalizedString("_user_city_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "city"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        row.value = tableAccount?.city
        section.addFormRow(row)
        
        row = XLFormRowDescriptor(tag: "userzip", rowType: XLFormRowDescriptorTypeZipCode, title: NSLocalizedString("_user_zip_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "cityzip"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        row.value = tableAccount?.zip
        section.addFormRow(row)
        
        row = XLFormRowDescriptor(tag: "usercountry", rowType: XLFormRowDescriptorTypeSelectorPickerView, title: NSLocalizedString("_user_country_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["detailTextLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "country"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        var locales = [String]()
        for localeCode in NSLocale.isoCountryCodes {
            let countryName = (Locale.current as NSLocale).displayName(forKey: .countryCode, value: localeCode) ?? ""
            if localeCode == tableAccount?.country {
                row.value = countryName
            }
            locales.append(countryName)
        }
        row.selectorOptions = locales.sorted()
        section.addFormRow(row)
        
        row = XLFormRowDescriptor(tag: "userphone", rowType: XLFormRowDescriptorTypePhone, title: NSLocalizedString("_user_phone_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "phone"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        row.value = tableAccount?.phone
        section.addFormRow(row)
        
        row = XLFormRowDescriptor(tag: "useremail", rowType: XLFormRowDescriptorTypeEmail, title: NSLocalizedString("_user_email_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "email"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        row.value = tableAccount?.email
        section.addFormRow(row)
        
        row = XLFormRowDescriptor(tag: "userweb", rowType: XLFormRowDescriptorTypeEmail, title: NSLocalizedString("_user_web_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "web"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        row.value = tableAccount?.webpage
        section.addFormRow(row)
        
        row = XLFormRowDescriptor(tag: "usertwitter", rowType: XLFormRowDescriptorTypeTwitter, title: NSLocalizedString("_user_twitter_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["textField.textAlignment"] = NSTextAlignment.right.rawValue
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "twitter"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        row.value = tableAccount?.twitter
        section.addFormRow(row)
        
        row = XLFormRowDescriptor(tag: "userbusinesstype", rowType: XLFormRowDescriptorTypeMultipleSelector, title: NSLocalizedString("_user_businesstype_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["detailTextLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "businesstype"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        row.selectorOptions = ["ARCHITECT","BRICKLAYER","CARPENTER","ELECTRICIAN","INSTALLER","PAINTER","PLUMBER","ROOFER","STOVEBUILDER","STUCCOER","WINDOWBUILDER","OTHER"]
        row.value = tableAccount?.businessType.components(separatedBy: ",")
        section.addFormRow(row)
        
        row = XLFormRowDescriptor(tag: "userbusinesssize", rowType: XLFormRowDescriptorTypeSelectorPickerView, title: NSLocalizedString("_user_businesssize_", comment: ""))
        row.cellConfig["textLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["detailTextLabel.font"] = UIFont.systemFont(ofSize: 15.0)
        row.cellConfig["imageView.image"] = CCGraphics.changeThemingColorImage(UIImage.init(named: "users"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
        row.selectorOptions = ["1-4","5-9","10-19","20-49","50-99","100-249","250-499","500-999","1000+"];
        switch tableAccount?.businessSize {
        case 1: row.value = "1-4"
        case 5: row.value = "5-9"
        case 10: row.value = "10-19"
        case 20: row.value = "20-49"
        case 50: row.value = "50-99"
        case 100: row.value = "100-249"
        case 250: row.value = "250-499"
        case 500: row.value = "500-999"
        case 1000: row.value = "1000+"
        default: break
        }
        section.addFormRow(row)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(_ formRow: XLFormRowDescriptor!, oldValue: Any!, newValue: Any!) {
        
        super.formRowDescriptorValueHasChanged(formRow, oldValue: oldValue, newValue: newValue)
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.navigationItem.title = NSLocalizedString("_user_editprofile_", comment: "")

        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.sharedInstance.brandText]
        
        self.tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
    
        initializeForm()
    }
    
}
