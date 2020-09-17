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
   
        if (appDelegate.account == nil || appDelegate.account.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        self.requestUserProfile()
        self.requestServerStatus()
    }

    //MARK: -
    
    private func requestUserProfile() {
        
        if (appDelegate.account == nil || appDelegate.account.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        NCCommunication.shared.getUserProfile() { (account, userProfile, errorCode, errorDescription) in
               
            if errorCode == 0 && account == self.appDelegate.account {
                                    
                // Update User (+ userProfile.id) & active account & account network
                guard let tableAccount = NCManageDatabase.sharedInstance.setAccountUserProfile(userProfile!) else {
                    NCContentPresenter.shared.messageNotification("Account", description: "Internal error : account not found on DB",  delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                        
                    return
                }
                
                let user = tableAccount.user
                let url = tableAccount.urlBase
                let stringUser = CCUtility.getStringUser(user, urlBase: url)!
                
                self.appDelegate.settingAccount(tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, userID: tableAccount.userID, password: CCUtility.getPassword(tableAccount.account))
                       
                // Synchronize favorite ---
                var selector = selectorReadFile
                if CCUtility.getFavoriteOffline() {
                    selector = selectorDownloadFile
                }
                NCNetworking.shared.listingFavoritescompletion(selector: selector) { (_, _, _, _) in }
                
                // Synchronize Offline Directory ---
                if let directories = NCManageDatabase.sharedInstance.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", tableAccount.account), sorted: "serverUrl", ascending: true) {
                    for directory: tableDirectory in directories {
                        guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(directory.ocId) else {
                            continue
                        }
                        NCOperationQueue.shared.synchronizationMetadata(metadata, selector: selectorDownloadFile)
                    }
                }
                
                // Synchronize Offline Files ---
                let files = NCManageDatabase.sharedInstance.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", tableAccount.account), sorted: "fileName", ascending: true)
                for file: tableLocalFile in files {
                    guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(file.ocId) else {
                        continue
                    }
                    NCOperationQueue.shared.synchronizationMetadata(metadata, selector: selectorDownloadFile)
                }
                                        
                let avatarUrl = "\(self.appDelegate.urlBase!)/index.php/avatar/\(self.appDelegate.user!)/\(k_avatar_size)".addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                let fileNamePath = CCUtility.getDirectoryUserData() + "/" + stringUser + "-" + self.appDelegate.user + ".png"
                        
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
                      
                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_changeUserProfile)
                                    
                self.requestServerCapabilities()
                
            } else {
                
                if errorCode == 401 || errorCode == 403 {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: account)
                }
            }
        }
    }
    
    private func requestServerStatus() {
        
        NCCommunication.shared.getServerStatus(serverUrl: appDelegate.urlBase) { (serverProductName, serverVersion, versionMajor, versionMinor, versionMicro, extendedSupport, errorCode, errorMessage) in
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
        
        if (appDelegate.account == nil || appDelegate.account.count == 0 || appDelegate.maintenanceMode == true) {
            return
        }
        
        NCCommunication.shared.getCapabilities() { (account, data, errorCode, errorDescription) in
            
            if errorCode == 0 && data != nil {
                
                NCManageDatabase.sharedInstance.addCapabilitiesJSon(data!, account: account)
            
                // Setup communication
                self.appDelegate.settingSetupCommunication(account)
            
                // Theming
                self.appDelegate.settingThemingColorBrand()
            
                // File Sharing
                let isFilesSharingEnabled = NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false)
                if (isFilesSharingEnabled && self.appDelegate.activeMain != nil) {
                    NCCommunication.shared.readShares { (account, shares, errorCode, ErrorDescription) in
                        if errorCode == 0 {
                            NCManageDatabase.sharedInstance.deleteTableShare(account: account)
                            if shares != nil {
                                NCManageDatabase.sharedInstance.addShare(urlBase: self.appDelegate.urlBase, account: account, shares: shares!)
                            }
                            self.appDelegate.shares = NCManageDatabase.sharedInstance.getTableShares(account: account)
                        } else {
                            NCContentPresenter.shared.messageNotification("_share_", description: ErrorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                }
            
                // NCTextObtainEditorDetails
                let serverVersionMajor = NCManageDatabase.sharedInstance.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
                if serverVersionMajor >= k_nextcloud_version_18_0 {
                    NCCommunication.shared.NCTextObtainEditorDetails() { (account, editors, creators, errorCode, errorMessage) in
                        if errorCode == 0 && account == self.appDelegate.account {
                            NCManageDatabase.sharedInstance.addDirectEditing(account: account, editors: editors, creators: creators)
                        }
                    }
                }
                
                let isExternalSitesServerEnabled = NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesExternalSitesExists, exists: true)
                if (isExternalSitesServerEnabled) {
                    NCCommunication.shared.getExternalSite() { (account, externalSites, errorCode, errorDescription) in
                        if errorCode == 0 && account == self.appDelegate.account {
                            NCManageDatabase.sharedInstance.deleteExternalSites(account: account)
                            for externalSite in externalSites {
                                NCManageDatabase.sharedInstance.addExternalSites(externalSite, account: account)
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
                
            } else if errorCode != 0 {
                
                self.appDelegate.settingThemingColorBrand()
                
                if errorCode == 401 || errorCode == 403 {
                    NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: account)
                }
                
            } else {
                self.appDelegate.settingThemingColorBrand()
            }
        }
    }
   
    //MARK: - Thirt Part
    
    private func requestHC() {

    }
}
