//
//  NCEntoToEndInterface.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/04/17.
//  Copyright © 2017 TWS. All rights reserved.
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

class NCEntoToEndInterface : NSObject {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    override init() {
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Mark/Delete Encrypted Folder
    // --------------------------------------------------------------------------------------------
    
    @objc func markEndToEndFolderEncryptedSuccess(_ metadataNet: CCMetadataNet) {
        
    }
    
    @objc func markEndToEndFolderEncryptedFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger)
    {
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized) {
            appDelegate.openLoginView(appDelegate.activeMain, loginType: loginModifyPasswordUser)
        }
        
        if (errorCode != kOCErrorServerUnauthorized) {
            
            appDelegate.messageNotification("_error_", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    @objc func markEndToEndFolderEncrypted(_ metadata: tableMetadata) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)

        metadataNet.action = actionMarkEndToEndFolderEncrypted;
        metadataNet.fileID = metadata.fileID;
        
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)        
    }
    
    @objc func deleteEndToEndFolderEncryptedSuccess(_ metadataNet: CCMetadataNet) {
        
    }
    
    @objc func deleteEndToEndFolderEncryptedFailure(_ metadataNet: CCMetadataNet, message: NSString, errorCode: NSInteger)
    {
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized) {
            appDelegate.openLoginView(appDelegate.activeMain, loginType: loginModifyPasswordUser)
        }
        
        if (errorCode != kOCErrorServerUnauthorized) {
            
            appDelegate.messageNotification("_error_", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    @objc func deleteEndToEndFolderEncrypted(_ metadata: tableMetadata) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionDeleteEndToEndFolderEncrypted;
        metadataNet.fileID = metadata.fileID;
        
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
}
