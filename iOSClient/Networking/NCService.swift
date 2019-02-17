//
//  NCService.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/03/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
import SVGKit

class NCService: NSObject {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @objc static let sharedInstance: NCService = {
        let instance = NCService()
        return instance
    }()
    
    //MARK: -
    //MARK: Start Services API NC
    
    @objc public func startRequestServicesServer() {
   
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        self.requestUserProfile()
        self.requestServerCapabilities()
        self.requestServerStatus()
    }

    //MARK: -
    //MARK: Internal request Service API NC
    
    private func requestServerCapabilities() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        OCNetworking.sharedManager().getCapabilitiesWithAccount(appDelegate.activeAccount, completion: { (account, capabilities, message, errorCode) in
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                
                // Update capabilities db
                NCManageDatabase.sharedInstance.addCapabilities(capabilities!, account: account!)
                
                // ------ THEMING -----------------------------------------------------------------------
                
                if (NCBrandOptions.sharedInstance.use_themingBackground && capabilities!.themingBackground != "") {
                    
                    // Download Logo
                    let fileNameThemingLogo = CCUtility.getStringUser(self.appDelegate.activeUser, activeUrl: self.appDelegate.activeUrl) + "-themingLogo.png"
                    _ = NCUtility.sharedInstance.convertSVGtoPNGWriteToUserData(svgUrlString: capabilities!.themingLogo, fileName: fileNameThemingLogo, width: 40, rewrite: true)
                    
                    // Download Theming Background
                    DispatchQueue.global().async {
                        
                        let backgroundURL = capabilities!.themingBackground!.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                        let fileNamePath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(self.appDelegate.activeUser, activeUrl: self.appDelegate.activeUrl) + "-themingBackground.png"
                        
                        guard let imageData = try? Data(contentsOf: URL(string: backgroundURL)!) else {
                            DispatchQueue.main.async {
                                self.appDelegate.settingThemingColorBrand()
                            }
                            return
                        }
                        
                        DispatchQueue.main.async {
                            
                            guard let image = UIImage(data: imageData) else {
                                try? FileManager.default.removeItem(atPath: fileNamePath)
                                self.appDelegate.settingThemingColorBrand()
                                return
                            }
                            
                            if let data = image.pngData() {
                                try? data.write(to: URL(fileURLWithPath: fileNamePath))
                            }
                            
                            self.appDelegate.settingThemingColorBrand()
                        }
                    }
                    
                } else {
                    
                    self.appDelegate.settingThemingColorBrand()
                }
                
                // ------ SEARCH ------------------------------------------------------------------------
                
                if (NCManageDatabase.sharedInstance.getServerVersion(account: account!) != capabilities!.versionMajor && self.appDelegate.activeMain != nil) {
                    self.appDelegate.activeMain.cancelSearchBar()
                }
                
                // ------ GET OTHER SERVICE -------------------------------------------------------------
                
                // Read Notification
                if (capabilities!.isNotificationServerEnabled) {
                    
                    OCNetworking.sharedManager().getNotificationWithAccount(account!, completion: { (account, listOfNotifications, message, errorCode) in
                        
                        if errorCode == 0 && account == self.appDelegate.activeAccount {
                            
                            DispatchQueue.global(qos: .default).async {
                                
                                let sortedListOfNotifications = (listOfNotifications! as NSArray).sortedArray(using: [
                                    NSSortDescriptor(key: "date", ascending: false)
                                    ])
                                
                                var old = ""
                                var new = ""
                                
                                for notification in listOfNotifications! {
                                    let id = (notification as! OCNotifications).idNotification
                                    if let icon = (notification as! OCNotifications).icon {
                                        _ = NCUtility.sharedInstance.convertSVGtoPNGWriteToUserData(svgUrlString: icon, fileName: nil, width: 25, rewrite: false)
                                    }
                                    new = new + String(describing: id)
                                }
                                for notification in self.appDelegate.listOfNotifications! {
                                    let id = (notification as! OCNotifications).idNotification
                                    old = old + String(describing: id)
                                }
                                
                                DispatchQueue.main.async {
                                    
                                    if (new != old) {
                                        self.appDelegate.listOfNotifications = NSMutableArray.init(array: sortedListOfNotifications)
                                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "notificationReloadData"), object: nil)
                                    }
                                    
                                    // Update Main NavigationBar
                                    if (self.appDelegate.activeMain.isSelectedMode == false && self.appDelegate.activeMain != nil) {
                                        self.appDelegate.activeMain.setUINavigationBarDefault()
                                    }
                                }
                            }
                            
                        } else {
                            
                            // Update Main NavigationBar
                            if (self.appDelegate.activeMain.isSelectedMode == false && self.appDelegate.activeMain != nil) {
                                self.appDelegate.activeMain.setUINavigationBarDefault()
                            }
                        }
                    })
                    
                } else {
                    
                    // Remove all Notification
                    self.appDelegate.listOfNotifications.removeAllObjects()
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "notificationReloadData"), object: nil)
                    // Update Main NavigationBar
                    if (self.appDelegate.activeMain != nil && self.appDelegate.activeMain.isSelectedMode == false) {
                        self.appDelegate.activeMain.setUINavigationBarDefault()
                    }
                }
                
                // Read External Sites
                if (capabilities!.isExternalSitesServerEnabled) {
                    
                    OCNetworking.sharedManager().getExternalSites(withAccount: account!, completion: { (account, listOfExternalSites, message, errorCode) in
                        
                        if errorCode == 0 && account == self.appDelegate.activeAccount {
                            
                            NCManageDatabase.sharedInstance.deleteExternalSites(account: account!)
                            for externalSites in listOfExternalSites! {
                                NCManageDatabase.sharedInstance.addExternalSites(externalSites as! OCExternalSites, account: account!)
                            }
                            
                        } 
                    })
                   
                } else {
                    
                    NCManageDatabase.sharedInstance.deleteExternalSites(account: account!)
                }
                
                // Read Share
                if (capabilities!.isFilesSharingAPIEnabled && self.appDelegate.activeMain != nil) {
                    
                    self.appDelegate.activeMain.readShare(withAccount: account, openWindow: false, metadata: nil)
                }
                
                if (capabilities!.isActivityV2Enabled) {
                    
                    OCNetworking.sharedManager().getActivityWithAccount(account!, since: 0, limit: 100, link: "", completion: { (account, listOfActivity, message, errorCode) in
                        if errorCode == 0 && account == self.appDelegate.activeAccount {
                            NCManageDatabase.sharedInstance.addActivity(listOfActivity as! [OCActivity], account: account!)
                        } 
                    })
                }
                
            } else if errorCode != 0 {
                
                self.appDelegate.settingThemingColorBrand()
                
            } else {
                print("[LOG] It has been changed user during networking process, error.")
                // Change Theming color
                self.appDelegate.settingThemingColorBrand()
            }
        })
    }
    
    private func requestUserProfile() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        OCNetworking.sharedManager().getUserProfile(withAccount: appDelegate.activeAccount, completion: { (account, userProfile, message, errorCode) in
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                
                // Update User (+ userProfile.id) & active account & account network
                guard let tableAccount = NCManageDatabase.sharedInstance.setAccountUserProfile(userProfile!) else {
                    self.appDelegate.messageNotification("Accopunt", description: "Internal error : account not found on DB", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
                    return
                }
                
                let user = tableAccount.user
                let url = tableAccount.url
                
                self.appDelegate.settingActiveAccount(tableAccount.account, activeUrl: tableAccount.url, activeUser: tableAccount.user, activeUserID: tableAccount.userID, activePassword: tableAccount.password)
                
                // Call func thath required the userdID
                self.appDelegate.activeFavorites.listingFavorites()
                self.appDelegate.activeMedia.collectionViewReloadDataSource()
                self.appDelegate.activeMedia.loadNetworkDatasource()
                NCFunctionMain.sharedInstance.synchronizeOffline()
                
                DispatchQueue.global(qos: .default).async {
                    
                    let address = "\(self.appDelegate.activeUrl!)/index.php/avatar/\(self.appDelegate.activeUser!)/128".addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                    let fileNamePath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(user, activeUrl: url) + "-" + self.appDelegate.activeUser + ".png"
                    
                    guard let imageData = try? Data(contentsOf: URL(string: address)!) else {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "changeUserProfile"), object: nil)
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        
                        guard let image = UIImage(data: imageData) else {
                            try? FileManager.default.removeItem(atPath: fileNamePath)
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "changeUserProfile"), object: nil)
                            return
                        }
                        
                        if let data = image.pngData() {
                            try? data.write(to: URL(fileURLWithPath: fileNamePath))
                        }
                        
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "changeUserProfile"), object: nil)
                    }
                }
                
            } else if errorCode != 0 {
                
                print("Get user profile failure error")
               
            } else {
                
                print("[LOG] It has been changed user during networking process, error.")
            }
        })
    }
    
    @objc public func middlewarePing() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
    }
    
    private func requestServerStatus() {

        OCNetworking.sharedManager().serverStatusUrl(appDelegate.activeUrl, delegate: self, completion: { (serverProductName, versionMajor, versionMicro, versionMinor, message, errorCode) in
            if errorCode == 0 {
                if serverProductName == "owncloud" {
                    self.appDelegate.messageNotification("_warning_", description: "_warning_owncloud_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: Int(k_CCErrorInternalError))
                } else if versionMajor <= k_nextcloud_unsupported {
                    self.appDelegate.messageNotification("_warning_", description: "_warning_unsupported_", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.info, errorCode: Int(k_CCErrorInternalError))
                }
            }
            
        })
    }
}
