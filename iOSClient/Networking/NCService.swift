//
//  NCService.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/03/18.
//  Copyright © 2018 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class NCService: NSObject, OCNetworkingDelegate, CCLoginDelegate, CCLoginDelegateWeb {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @objc static let sharedInstance: NCService = {
        let instance = NCService()
        return instance
    }()
    
     @objc func middlewarePing() {
       
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return;
        }
        
        guard let metadataNet = CCMetadataNet.init(account: appDelegate.activeAccount) else {
            return
        }
        
        metadataNet.action = actionMiddlewarePing
        metadataNet.serverUrl = NCBrandOptions.sharedInstance.middlewarePingUrl
        
        //appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    func getCapabilitiesOfServerSuccessFailure(_ metadataNet: CCMetadataNet!, capabilities: OCCapabilities?, message: String?, errorCode: Int) {
        
        // Check Active Account
        if (metadataNet.account != appDelegate.activeAccount) {
            return;
        }
        
        if (errorCode == 0) {
            
            // Update capabilities db
            NCManageDatabase.sharedInstance.addCapabilities(capabilities!)
            
            // ------ THEMING -----------------------------------------------------------------------
            
            // Download Theming Background & Change Theming color
            DispatchQueue.global().async {
                
                if (NCBrandOptions.sharedInstance.use_themingBackground) {
                }
            }
            
            // ------ SEARCH ------------------------------------------------------------------------
            
            if (NCManageDatabase.sharedInstance.getServerVersion() != capabilities!.versionMajor && appDelegate.activeMain != nil) {
                appDelegate.activeMain.cancelSearchBar()
            }
            
            // ------ GET OTHER SERVICE -------------------------------------------------------------
            
        } else {
            
            // Unauthorized
            if (errorCode == kOCErrorServerUnauthorized) {
                appDelegate.openLoginView(self, loginType: loginModifyPasswordUser)
            }
            
            let error = "Get Capabilities failure error \(errorCode) \(message!)"
            print("[LOG] \(error)")
            
            NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionCapabilities, selector: "Get Capabilities of Server", note: error, type: k_activityTypeFailure, verbose: true, activeUrl: appDelegate.activeUrl)
            
            // Change Theming color
            appDelegate.settingThemingColorBrand()
        }
    }
    
    @objc func requestServerCapabilities() {
        
        if (appDelegate.activeAccount == nil || appDelegate.activeAccount.count == 0 || appDelegate.maintenanceMode == true) {
            return;
        }
    
        guard let metadataNet = CCMetadataNet.init(account: appDelegate.activeAccount) else {
            return
        }
    
        metadataNet.action = actionGetCapabilities;
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    @objc func getUserProfileSuccessFailure(_ metadataNet: CCMetadataNet!, userProfile: OCUserProfile?, message: String?, errorCode: Int) {
        
        // Check Active Account
        if (metadataNet.account != appDelegate.activeAccount) {
            return;
        }
        
        if (errorCode == 0) {
            
            // Update User (+ userProfile.id) & active account & account network
            guard let tableAccount = NCManageDatabase.sharedInstance.setAccountUserProfile(userProfile!) else {
                appDelegate.messageNotification("Accopunt", description: "Internal error : account not found on DB", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: Int(k_CCErrorInternalError))
                return
            }
            
            CCNetworking.shared().settingAccount()
            appDelegate.settingActiveAccount(tableAccount.account, activeUrl: tableAccount.url, activeUser: tableAccount.user, activeUserID: tableAccount.userID, activePassword: tableAccount.password)
            
            // Call func thath required the userdID
            appDelegate.activePhotos.readPhotoVideo()
            appDelegate.activeFavorites.readListingFavorites()
            
            DispatchQueue.global(qos: .default).async {
                
                let address = "\(self.appDelegate.activeUrl!)/index.php/avatar/\(self.appDelegate.activeUser!)/128"
                guard let imageData = try? Data(contentsOf: URL(string: address)!) else {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "changeUserProfile"), object: nil)
                    return
                }
                
                guard let avatar = UIImage(data: imageData) else {
                    let fileName = "\(self.appDelegate.directoryUser!)/avatar.png"
                    try? FileManager.default.removeItem(atPath: fileName)
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "changeUserProfile"), object: nil)
                    return
                }
                
                if let data = UIImagePNGRepresentation(avatar) {
                    let fileName = "\(self.appDelegate.directoryUser!)/avatar.png"
                    try? data.write(to: URL(fileURLWithPath: fileName))
                }
                
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "changeUserProfile"), object: nil)
            }
            
        } else {
            
            let error = "Get user profile failure error \(errorCode) \(message!)"
            print("[LOG] \(error)")
            
            NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionCapabilities, selector: "Get user profile Server", note: error, type: k_activityTypeFailure, verbose: true, activeUrl: appDelegate.activeUrl)
        }
    }
    
    @objc func getExternalSitesServerSuccessFailure(_ metadataNet: CCMetadataNet!, listOfExternalSites: [Any]?, message: String?, errorCode: Int) {
        
        // Check Active Account
        if (metadataNet.account != appDelegate.activeAccount) {
            return;
        }
        
        if (errorCode == 0) {
            
            NCManageDatabase.sharedInstance.deleteExternalSites()
            for externalSites in listOfExternalSites! {
                NCManageDatabase.sharedInstance.addExternalSites(externalSites as! OCExternalSites)
            }
            
        } else {
         
            let error = "Get external site failure error \(errorCode) \(message!)"
            print("[LOG] \(error)")
            
            NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionCapabilities, selector: "Get external site Server", note: error, type: k_activityTypeFailure, verbose: true, activeUrl: appDelegate.activeUrl)
        }
    }
    
    @objc func getActivityServerSuccessFailure(_ metadataNet: CCMetadataNet!, listOfActivity: [Any]?, message: String?, errorCode: Int) {
        
        // Check Active Account
        if (metadataNet.account != appDelegate.activeAccount) {
            return;
        }
        
        if (errorCode == 0) {
            
            NCManageDatabase.sharedInstance.addActivityServer(listOfActivity as! [OCActivity])
            if (appDelegate.activeActivity != nil) {
                appDelegate.activeActivity.reloadDatasource()
            }
            
        } else {
            
            let error = "Get Activity Server failure error \(errorCode) \(message!)"
            print("[LOG] \(error)")
            
            NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionCapabilities, selector: "Get Activity Server", note: error, type: k_activityTypeFailure, verbose: true, activeUrl: appDelegate.activeUrl)
        }
    }
    
    //MARK: -
    //MARK: Delegate : Login
    
    func loginSuccess(_ loginType: Int) {
        
        // go to home sweet home
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "initializeMain"), object: nil)
    }

    func loginClose() {
        appDelegate.activeLogin = nil;
    }
    
    func loginWebClose() {
        appDelegate.activeLoginWeb = nil;
    }
    
}
