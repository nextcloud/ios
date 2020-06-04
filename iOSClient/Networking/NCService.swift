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
    @objc static let shared: NCService = {
        let instance = NCService()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK: -
    
    @objc public func startRequestServicesServer() {
   
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        self.requestUserProfile()
        self.requestServerStatus()
    }

    //MARK: -
    
    private func requestUserProfile() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        NCCommunication.shared.getUserProfile() { (account, userProfile, errorCode, errorDescription) in
               
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                
                DispatchQueue.global().async {
                    
                    // Update User (+ userProfile.id) & active account & account network
                    guard let tableAccount = NCManageDatabase.sharedInstance.setAccountUserProfile(userProfile!) else {
                        DispatchQueue.main.async {
                            NCContentPresenter.shared.messageNotification("Account", description: "Internal error : account not found on DB",  delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                        }
                        return
                    }
                
                    let user = tableAccount.user
                    let url = tableAccount.url
                
                    self.appDelegate.settingActiveAccount(tableAccount.account, activeUrl: tableAccount.url, activeUser: tableAccount.user, activeUserID: tableAccount.userID, activePassword: CCUtility.getPassword(tableAccount.account))
                
                    // Synchronize
                    let directories = NCManageDatabase.sharedInstance.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", tableAccount.account), sorted: "serverUrl", ascending: true)
                    if (directories != nil) {
                        for directory: tableDirectory in directories! {
                            CCSynchronize.shared()?.readFolder(directory.serverUrl, selector: selectorReadFolderWithDownload, account: tableAccount.account)
                        }
                    }
                
                    let files = NCManageDatabase.sharedInstance.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", tableAccount.account), sorted: "fileName", ascending: true)
                    if (files != nil) {
                        for file: tableLocalFile in files! {
                            guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", file.ocId)) else {
                                continue
                            }
                            CCSynchronize.shared()?.readFile(metadata.ocId, fileName: metadata.fileName, serverUrl: metadata.serverUrl, selector: selectorReadFileWithDownload, account: tableAccount.account)
                        }
                    }

                        
                    let avatarUrl = "\(self.appDelegate.activeUrl!)/index.php/avatar/\(self.appDelegate.activeUser!)/\(k_avatar_size)".addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                    let fileNamePath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(user, activeUrl: url) + "-" + self.appDelegate.activeUser + ".png"
                        
                    NCCommunication.shared.downloadContent(serverUrl: avatarUrl) { (account, data, errorCode, errorMessage) in
                        if errorCode == 0 {
                            DispatchQueue.global().async {
                                if let image = UIImage(data: data!) {
                                    try? FileManager.default.removeItem(atPath: fileNamePath)
                                    if let data = image.pngData() {
                                        try? data.write(to: URL(fileURLWithPath: fileNamePath))
                                    }
                                }
                            }
                        }
                    }
                      
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: k_notificationCenter_changeUserProfile), object: nil)
                    }
                
                    // Get Capabilities
                    self.requestServerCapabilities()
                }
                
            } else {
                
                if errorCode == kOCErrorServerUnauthorized || errorCode == kOCErrorServerForbidden {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: account)
                }
                
                print("[LOG] It has been changed user during networking process, error.")
            }
        }
    }
    
    private func requestServerStatus() {
        
        NCCommunication.shared.getServerStatus(serverUrl: appDelegate.activeUrl) { (serverProductName, serverVersion, versionMajor, versionMinor, versionMicro, extendedSupport, errorCode, errorMessage) in
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
        
        NCCommunication.shared.getCapabilities() { (account, data, errorCode, errorDescription) in
            
            if errorCode == 0 && data != nil {
                
                DispatchQueue.global().async {
                    
                    NCManageDatabase.sharedInstance.addCapabilitiesJSon(data!, account: account)
                
                    // Setup communication
                    self.appDelegate.settingSetupCommunicationCapabilities(account)
                
                    // Theming
                    self.appDelegate.settingThemingColorBrand()
                
                    // File Sharing
                    let isFilesSharingEnabled = NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false)
                    if (isFilesSharingEnabled && self.appDelegate.activeMain != nil) {
                    
                        OCNetworking.sharedManager()?.readShare(withAccount: account, completion: { (account, items, message, errorCode) in
                            if errorCode == 0 && account == self.appDelegate.activeAccount {
                                
                                DispatchQueue.global().async {
                                    let itemsOCSharedDto = items as! [OCSharedDto]
                                    NCManageDatabase.sharedInstance.deleteTableShare(account: account!)
                                    self.appDelegate.shares = NCManageDatabase.sharedInstance.addShare(account: account!, activeUrl: self.appDelegate.activeUrl, items: itemsOCSharedDto)
                                }
                            } else {
                                NCContentPresenter.shared.messageNotification("_share_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            }
                        })
                    }
                
                    // NCTextObtainEditorDetails
                    let serverVersionMajor = NCManageDatabase.sharedInstance.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
                    if serverVersionMajor >= k_nextcloud_version_18_0 {
                        NCCommunication.shared.NCTextObtainEditorDetails() { (account, editors, creators, errorCode, errorMessage) in
                            if errorCode == 0 && account == self.appDelegate.activeAccount {
                                DispatchQueue.main.async {
                                    NCManageDatabase.sharedInstance.addDirectEditing(account: account, editors: editors, creators: creators)
                                }
                            }
                        }
                    }
                    
                    let isExternalSitesServerEnabled = NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesExternalSitesExists, exists: true)
                    if (isExternalSitesServerEnabled) {
                        NCCommunication.shared.getExternalSite() { (account, externalSites, errorCode, errorDescription) in
                            if errorCode == 0 && account == self.appDelegate.activeAccount {
                                DispatchQueue.main.async {
                                    NCManageDatabase.sharedInstance.deleteExternalSites(account: account)
                                    for externalSite in externalSites {
                                        NCManageDatabase.sharedInstance.addExternalSites(externalSite, account: account)
                                    }
                                }
                            }
                        }
                    } else {
                        NCManageDatabase.sharedInstance.deleteExternalSites(account: account)
                    }
                
                    // Handwerkcloud
                    let isHandwerkcloudEnabled = NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesHWCEnabled, exists: false)
                    if (isHandwerkcloudEnabled) {
                        self.requestHC()
                    }
                }
                
            } else if errorCode != 0 {
                
                self.appDelegate.settingThemingColorBrand()
                
                if errorCode == kOCErrorServerUnauthorized || errorCode == kOCErrorServerForbidden {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: account)
                }
                
            } else {
                print("[LOG] It has been changed user during networking process, error.")
                // Change Theming color
                self.appDelegate.settingThemingColorBrand()
            }
        }
    }
    
    @objc public func middlewarePing() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
    }
    
    //MARK: - Thirt Part
    
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
