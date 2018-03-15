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

    //MARK: -
    //MARK: middlewarePing
    
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
    
    //MARK: -
    //MARK: requestServerCapabilities
    
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
            print("[LOG] \(message!)")
            
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
