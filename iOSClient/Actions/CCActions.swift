//
//  CCActions.swift
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 06/02/17.
//  Copyright (c) 2017 TWS. All rights reserved.
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

@objc protocol CCActionsDelegate  {
    
    func deleteFileOrFolderSuccess(_ metadataNet : CCMetadataNet)
    func deleteFileOrFolderFailure(_ metadataNet : CCMetadataNet, message : NSString, errorCode : NSInteger)
}

class CCActions: NSObject {
    
    //MARK: Shared Instance
    
    static let sharedInstance : CCActions = {
        let instance = CCActions()
        return instance
    }()
    
    //MARK: Local Variable
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadataNet : CCMetadataNet = CCMetadataNet.init()
    
    var delegate : CCActionsDelegate!
    
    //MARK: Init
    
    override init() {
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Delete File or Folder
    // --------------------------------------------------------------------------------------------

    func deleteFileOrFolder(_ metadata : CCMetadata, delegate : AnyObject) {
        
        let serverUrl : String = CCCoreData.getServerUrl(fromDirectoryID: metadata.directoryID, activeAccount: appDelegate.activeAccount)!
        let metadataNet : CCMetadataNet = CCMetadataNet.init()
        
        if metadata.cryptated == true {
            
            metadataNet.action = actionDeleteFileDirectory
            metadataNet.delegate = delegate
            metadataNet.fileID = metadata.fileID
            metadataNet.fileNamePrint = metadata.fileNamePrint
            metadataNet.metadata = metadata
            metadataNet.serverUrl = serverUrl
            
            // data crypto
            metadataNet.fileName = metadata.fileNameData
            metadataNet.selector = selectorDeleteCrypto
            
            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            
            // plist
            metadataNet.fileName = metadata.fileName;
            metadataNet.selector = selectorDeletePlist

            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            
        } else {
            
            metadataNet.action = actionDeleteFileDirectory
            metadataNet.delegate = delegate
            metadataNet.fileID = metadata.fileID
            metadataNet.fileName = metadata.fileName
            metadataNet.fileNamePrint = metadata.fileNamePrint
            metadataNet.metadata = metadata
            metadataNet.selector = selectorDelete
            metadataNet.serverUrl = serverUrl

            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
        }
    }
    
    func deleteFileOrFolderSuccess(_ metadataNet : CCMetadataNet) {
        
        self.delegate = metadataNet.delegate as! CCActionsDelegate
        
        CCCoreData.deleteFile(metadataNet.metadata, serverUrl: metadataNet.serverUrl, directoryUser: appDelegate.directoryUser, typeCloud: appDelegate.typeCloud, activeAccount: appDelegate.activeAccount)
        
        delegate?.deleteFileOrFolderSuccess(metadataNet)
    }
    
    func deleteFileOrFolderFailure(_ metadataNet : CCMetadataNet, message : NSString, errorCode : NSInteger) {
        
        self.delegate = metadataNet.delegate as! CCActionsDelegate
        
        if errorCode == 404 {
            CCCoreData.deleteFile(metadataNet.metadata, serverUrl: metadataNet.serverUrl, directoryUser: appDelegate.directoryUser, typeCloud: appDelegate.typeCloud, activeAccount: appDelegate.activeAccount)
        }

        if message.length > 0 {
            appDelegate.messageNotification("_delete_", description: message as String, visible: true, delay:TimeInterval(dismissAfterSecond), type:TWMessageBarMessageType.error)
        }
        
        delegate?.deleteFileOrFolderFailure(metadataNet, message: message, errorCode: errorCode)
    }
}
