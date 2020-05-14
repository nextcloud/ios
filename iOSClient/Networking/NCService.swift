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
import NCCommunication

class NCService: NSObject {
    @objc static let sharedInstance: NCService = {
        let instance = NCService()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK: -
    //MARK: Start Services API NC
    
    @objc public func startRequestServicesServer() {
   
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        self.requestUserProfile()
        self.requestServerStatus()
    }

    //MARK: -
    //MARK: Internal request Service API NC
    
    private func requestUserProfile() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        NCCommunication.sharedInstance.getUserProfile(serverUrl: appDelegate.activeUrl, customUserAgent: nil, addCustomHeaders: nil, account: appDelegate.activeAccount) { (account, userProfile, errorCode, errorDescription) in
                 
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                
                // Update User (+ userProfile.id) & active account & account network
                guard let tableAccount = NCManageDatabase.sharedInstance.setAccountUserProfile(userProfile!) else {
                    NCContentPresenter.shared.messageNotification("Accopunt", description: "Internal error : account not found on DB",  delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                    return
                }
                
                let user = tableAccount.user
                let url = tableAccount.url
                
                self.appDelegate.settingActiveAccount(tableAccount.account, activeUrl: tableAccount.url, activeUser: tableAccount.user, activeUserID: tableAccount.userID, activePassword: CCUtility.getPassword(tableAccount.account))
                
                // Call func thath required the userdID
                self.appDelegate.activeFavorites.listingFavorites()
                self.appDelegate.activeMedia.reloadDataSource(loadNetworkDatasource: true) { }
                NCFunctionMain.sharedInstance.synchronizeOffline()
                
                DispatchQueue.global().async {
                    
                    let avatarUrl = "\(self.appDelegate.activeUrl!)/index.php/avatar/\(self.appDelegate.activeUser!)/\(k_avatar_size)".addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                    let fileNamePath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(user, activeUrl: url) + "-" + self.appDelegate.activeUser + ".png"
                    
                    NCCommunication.sharedInstance.downloadContent(serverUrl: avatarUrl, customUserAgent: nil, addCustomHeaders: nil, account: self.appDelegate.activeAccount) { (account, data, errorCode, errorMessage) in
                        if errorCode == 0 {
                            if let image = UIImage(data: data!) {
                                try? FileManager.default.removeItem(atPath: fileNamePath)
                                if let data = image.pngData() {
                                    try? data.write(to: URL(fileURLWithPath: fileNamePath))
                                }
                            }
                        }
                    }
                    /*
                    OCNetworking.sharedManager()?.downloadContents(ofUrl: avatarUrl, completion: { (data, message, errorCode) in
                        if errorCode == 0 {
                            if let image = UIImage(data: data!) {
                                try? FileManager.default.removeItem(atPath: fileNamePath)
                                if let data = image.pngData() {
                                    try? data.write(to: URL(fileURLWithPath: fileNamePath))
                                }
                            }
                        }
                    })
                    */
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: k_notificationCenter_changeUserProfile), object: nil)
                    }
                }
                
                // Get Capabilities
                self.requestServerCapabilities()
                
            } else {
                
                if errorCode == kOCErrorServerUnauthorized || errorCode == kOCErrorServerForbidden {
                    OCNetworking.sharedManager()?.checkRemoteUser(account, function: "get user profile", errorCode: errorCode)
                }
                
                print("[LOG] It has been changed user during networking process, error.")
            }
        }
    }
    
    private func requestServerStatus() {
        
        NCCommunication.sharedInstance.getServerStatus(serverUrl: appDelegate.activeUrl, customUserAgent: nil, addCustomHeaders: nil) { (serverProductName, serverVersion, versionMajor, versionMinor, versionMicro, extendedSupport, errorCode, errorMessage) in
            if errorCode == 0 {
                if extendedSupport == false {
                    if serverProductName == "owncloud" {
                        NCContentPresenter.shared.messageNotification("_warning_", description: "_warning_owncloud_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_dismissAfterSecondLong))
                    } else if versionMajor <= k_nextcloud_unsupported {
                        NCContentPresenter.shared.messageNotification("_warning_", description: "_warning_unsupported_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.info, errorCode: Int(k_dismissAfterSecondLong))
                    }
                }
            }
        }
    }
    
    private func requestServerCapabilities() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        NCCommunication.sharedInstance.getCapabilities(serverUrl: appDelegate.activeUrl, customUserAgent: nil, addCustomHeaders: nil, account: appDelegate.activeAccount) { (account, data, errorCode, errorDescription) in
            
            if errorCode == 0 && data != nil {
                NCManageDatabase.sharedInstance.addCapabilitiesJSon(data!, account: account)
                
                // Update webDavRoot
                if let webDavRoot = NCManageDatabase.sharedInstance.getCapabilitiesWebDavRoot(account: account) {
                     self.appDelegate.settingWebDavRoot(webDavRoot)
                }
            }
        }
        
        OCNetworking.sharedManager().getCapabilitiesWithAccount(appDelegate.activeAccount, completion: { (account, capabilities, message, errorCode) in
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                
                // Update capabilities db
                NCManageDatabase.sharedInstance.addCapabilities(capabilities!, account: account!)
                                
                // ------ THEMING -----------------------------------------------------------------------
                self.appDelegate.settingThemingColorBrand()
                
                // ------ GET OTHER SERVICE -------------------------------------------------------------
                                
                // Get External Sites
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
                
                // Get Share Server
                if (capabilities!.isFilesSharingAPIEnabled && self.appDelegate.activeMain != nil) {
                    
                    OCNetworking.sharedManager()?.readShare(withAccount: account, completion: { (account, items, message, errorCode) in
                        if errorCode == 0 && account == self.appDelegate.activeAccount {
                            let itemsOCSharedDto = items as! [OCSharedDto]
                            NCManageDatabase.sharedInstance.deleteTableShare(account: account!)
                            self.appDelegate.shares = NCManageDatabase.sharedInstance.addShare(account: account!, activeUrl: self.appDelegate.activeUrl, items: itemsOCSharedDto)
                            self.appDelegate.activeMain?.tableView?.reloadData()
                            self.appDelegate.activeFavorites?.tableView?.reloadData()
                        } else {
                            NCContentPresenter.shared.messageNotification("_share_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    })
                }
                
                // Get Handwerkcloud
                if (capabilities!.isHandwerkcloudEnabled) {
                    self.requestHC()
                }
                
                // NCTextObtainEditorDetails
                if capabilities!.versionMajor >= k_nextcloud_version_18_0 {
                    NCCommunication.sharedInstance.NCTextObtainEditorDetails(serverUrl: self.appDelegate.activeUrl, customUserAgent: nil, addCustomHeaders: nil, account: self.appDelegate.activeAccount) { (account, editors, creators, errorCode, errorMessage) in
                        if errorCode == 0 && account == self.appDelegate.activeAccount {
                            NCManageDatabase.sharedInstance.addDirectEditing(account: account, editors: editors, creators: creators)
                        }
                    }
                }
              
            } else if errorCode != 0 {
                
                self.appDelegate.settingThemingColorBrand()
                
                if errorCode == kOCErrorServerUnauthorized || errorCode == kOCErrorServerForbidden {
                    OCNetworking.sharedManager()?.checkRemoteUser(account, function: "get capabilities", errorCode: errorCode)
                }
                
            } else {
                print("[LOG] It has been changed user during networking process, error.")
                // Change Theming color
                self.appDelegate.settingThemingColorBrand()
            }
        })
    }
    
    @objc public func middlewarePing() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
    }
    
    //MARK: -
    //MARK: Thirt Part
    
    private func requestHC() {
        
        let professions = CCUtility.getHCBusinessType()
        if professions != nil && professions!.count > 0 {
            OCNetworking.sharedManager()?.putHCUserProfile(withAccount: appDelegate.activeAccount, serverUrl: appDelegate.activeUrl, address: nil, businesssize: nil, businesstype: professions, city: nil, company: nil, country: nil, displayname: nil, email: nil, phone: nil, role_: nil, twitter: nil, website: nil, zip: nil, completion: { (account, message, errorCode) in
                if errorCode == 0 && account == self.appDelegate.activeAccount {
                    CCUtility.setHCBusinessType(nil)
                    OCNetworking.sharedManager()?.getHCUserProfile(withAccount: self.appDelegate.activeAccount, serverUrl: self.appDelegate.activeUrl, completion: { (account, userProfile, message, errorCode) in
                        if errorCode == 0 && account == self.appDelegate.activeAccount {
                            _ = NCManageDatabase.sharedInstance.setAccountUserProfileHC(businessSize: userProfile!.businessSize, businessType: userProfile!.businessType, city: userProfile!.city, company: userProfile!.company, country: userProfile!.country, role: userProfile!.role, zip: userProfile!.zip)
                        }
                    })
                }
            })
        } else {
            OCNetworking.sharedManager()?.getHCUserProfile(withAccount: appDelegate.activeAccount, serverUrl: appDelegate.activeUrl, completion: { (account, userProfile, message, errorCode) in
                if errorCode == 0 && account == self.appDelegate.activeAccount {
                    _ = NCManageDatabase.sharedInstance.setAccountUserProfileHC(businessSize: userProfile!.businessSize, businessType: userProfile!.businessType, city: userProfile!.city, company: userProfile!.company, country: userProfile!.country, role: userProfile!.role, zip: userProfile!.zip)
                }
            })
        }
        
        OCNetworking.sharedManager()?.getHCFeatures(withAccount: appDelegate.activeAccount, serverUrl: appDelegate.activeUrl, completion: { (account, features, message, errorCode) in
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                _ = NCManageDatabase.sharedInstance.setAccountHCFeatures(features!)
            }
        })
        
    }
}
